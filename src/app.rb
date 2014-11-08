require 'sinatra'
require 'sinatra/base'
require 'sinatra/reloader' if development?
require 'haml'
require 'webrick'
require 'openssl'
require 'sqlite3'

WEBrick::Config::HTTP[:DoNotReverseLookup] = true
enable :sessions

def get_systemdata
  { :systemname => 'OreoreCA.',
    :copyrightyear => Time.now.year,
    :copyrighturl  => 'https://twitter.com/motop3j',
    :copyrightname => '@motop3j',
    :pathinfo => request.path_info,
    :version => '0.0.3'}
end

def get_privatekey
  OpenSSL::PKey::RSA.new(2048)
end

def get_digest
  OpenSSL::Digest::SHA256.new()
end

def get_dbpath
  File.join File.expand_path(File.dirname(__FILE__)), 'db', 'oreoreca.db'
end

def get_selfsignedcertificateinfo()
  rows = nil
  SQLite3::Database::new(get_dbpath) do |db|
    sql = <<-'EOL'
      select id, created, subject, notbefore, notafter 
      from selfsignedcertificates
      order by id desc
    EOL
    columns, *rows = db.execute2(sql)
  end
  rows
end

def get_selfsignedcertificate(id)
  rows = nil
  SQLite3::Database::new(get_dbpath) do |db|
    sql = <<-'EOL'
      select 
        id, subject, notbefore, notafter, 
        privatekey, digest, certificate, created
      from selfsignedcertificates 
      where id = ?
    EOL
    columns, *rows = db.execute2(sql, [id])
    logger.info(columns)
    logger.info(rows)
  end
  if rows.size == 0
    return nil
  end
  rows[0]
end

def add_selfsignedcertificate(key, digest, cer)
  id = -1
  SQLite3::Database::new(get_dbpath) do |db|
    begin
      db.transaction
      sql = <<-'EOL'
        insert into selfsignedcertificates
        ( subject, notbefore, notafter, 
          privatekey, digest, certificate, created)
        values (?, ?, ?, ?, ?, ?, ?)
      EOL
      values = [ 
        cer.subject.to_s,
        cer.not_before.strftime("%Y-%m-%d %X:%M:%S"),
        cer.not_after.strftime("%Y-%m-%d %X:%M:%S"),
        key.to_s, digest.to_s, cer.to_s,
        Time.now.gmtime.strftime("%Y-%m-%d %X:%M:%S") ]
      db.execute(sql, values)
      sql = 'select last_insert_rowid()'
      id = db.get_first_value(sql)
      db.commit
    rescue
      db.rollback
      logger.error $!
      logger.error "add_selfsignedcertificate failed."
    end
  end
  id
end

get '/' do
  @system = get_systemdata()
  @system[:pagetitle] = 'はじめに'

  haml :index
end

#-------------------------------------------------------------------------------
# 自己署名証明書 認証なし
#-------------------------------------------------------------------------------

get '/all/selfsigned' do
  if session.has_key?(:errors)
    @errors = session[:errors]
    session.delete(:errors)
  end
  @system = get_systemdata()
  @system[:pagetitle] = '自己署名証明書'
  @certificate_info = get_selfsignedcertificateinfo
  haml :all_selfsigned
end

get '/all/selfsigned/:id' do |id|
  if not (/[^\d]/ =~ id).nil?
    return 'Invalid certificate id.'
  end
  @created = false
  if session.has_key?(:created)
    @created = session[:created]
    session.delete(:created)
  end
  @system = get_systemdata()
  @system[:pagetitle] = '自己署名証明書'
  cer = get_selfsignedcertificate(id)
  if cer.nil?
    return 'Invalid certificate id.'
  end
  cer = OpenSSL::X509::Certificate.new(cer[6])
  @certificate_id = id
  @certificate = cer.to_text
  haml :all_selfsigned_id
end

get '/all/selfsigned/key/:id' do |id|
  if not (/[^\d]/ =~ id).nil?
    return 'Invalid certificate id.'
  end
  cer = get_selfsignedcertificate(id)
  if cer.nil?
    return 'Invalid certificate id.'
  end
  content_type 'application/octet-stream'
  attachment 'key%d.pem' % id
  cer[4]
end

get '/all/selfsigned/cer/:id' do |id|
  if not (/[^\d]/ =~ id).nil?
    return 'Invalid certificate id.'
  end
  cer = get_selfsignedcertificate(id)
  if cer.nil?
    return 'Invalid certificate id.'
  end
  content_type 'application/octet-stream'
  attachment 'cer%d.pem' % id
  cer[6]
end

post '/all/selfsigned' do
  @system = get_systemdata()
  @system[:pagetitle] = '自己署名証明書'
  errors = []
  cn = request['cn']
  cn = cn.empty? ? "" : cn.strip

  if cn.strip.size == 0
    errors.push 'Common Name が空です。'
  end
  logger.info cn
  if not (/[^a-zA-Z0-9 \.,\-@]/ =~ cn).nil?
    errors.push 'Common Name で利用可能な文字は半角英数とスペース、' \
      + '特定の記号「.,-@」です。'
  end
  if cn.size > 64
    errors.push 'Common Name は64文字以内で入力してください。'
  end
  
  if errors.size > 0
    session[:errors] = errors
    redirect back
  end
  
  key = get_privatekey
  digest = get_digest
  issu = sub = OpenSSL::X509::Name.new()
  sub.add_entry('CN', cn)

  cer = OpenSSL::X509::Certificate.new()
  now = Time.now.gmtime
  cer.not_before = Time.gm now.year, now.month, now.day
  cer.not_after = (Time.gm now.year + 10, now.month, now.day) - 1
  cer.public_key = key  # <= 署名する対象となる公開鍵
  cer.serial = 1
  cer.issuer = issu
  cer.subject = sub

  cer.sign(key, digest) # <= 署名するのに使う秘密鍵とハッシュ関数
  id = add_selfsignedcertificate(key, digest, cer)
  session[:created] = true
  redirect '/all/selfsigned/%d' % id
end

