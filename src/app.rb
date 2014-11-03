require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'webrick'
require 'openssl'
require 'sqlite3'

WEBrick::Config::HTTP[:DoNotReverseLookup] = true

def get_systemdata
  { :systemname => 'Oreore CA.',
    :copyrightyear => Time.now.year,
    :copyrighturl  => 'https://twitter.com/motop3j',
    :copyrightname => '@motop3j',
    :pathinfo => request.path_info,
    :version => '0.0.1'}
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
    sql = 'select id, created, subject, notbefore, notafter from selfsignedcertificates '
    sql += 'order by id desc'
    columns, *rows = db.execute2(sql)
    logger.info(columns)
    logger.info(rows)
  end
  rows
end


def add_selfsignedcertificate(key, digest, cer)
  id = -1
  SQLite3::Database::new(get_dbpath) do |db|
    begin
      db.transaction
      sql = 'insert into selfsignedcertificates '
      sql += '(subject, notbefore, notafter, privatekey, digest, certificate, created) '
      sql += 'values (?, ?, ?, ?, ?, ?, ?)'
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

get '/all/selfsigned' do
  @system = get_systemdata()
  @system[:pagetitle] = '自己署名証明書'
  @certificate_info = get_selfsignedcertificateinfo
  haml :all_selfsigned
end

post '/all/selfsigned' do
  @system = get_systemdata()
  @system[:pagetitle] = '自己署名証明書'
  @errors = []
  cn = request['cn']
  cn = cn.empty? ? "" : cn.strip

  if cn.strip.size == 0
    @errors.push 'Common Name が空です。'
  end
  if not (/[^a-zA-Z0-9 ]/ =~ cn).nil?
    @errors.push 'Common Name は半角英数とスペースで入力してください。'
  end
  if cn.size > 64
    @errors.push 'Common Name は64文字以内で入力してください。'
  end
  
  if @errors.size > 0
    @certificate_info = get_selfsignedcertificateinfo
    return haml :all_selfsigned
  end
  
  key = get_privatekey
  digest = get_digest
  issu = sub = OpenSSL::X509::Name.new()
  #sub.add_entry('C', 'JP')
  #sub.add_entry('ST', 'Shimane')
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
  cer.to_s
  @certificate = cer.to_text
  @certificate_id = add_selfsignedcertificate(key, digest, cer)
  @certificate_info = get_selfsignedcertificateinfo

  haml :all_selfsigned
end

