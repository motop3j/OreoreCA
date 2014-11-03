#!/bi/bash

if [ $# -ne 2 ]; then
	echo "Usage: $(basename $0) <subject> <days>"
	echo
	echo ex. $(basename $0) \"/C=JP/ST=Tokyo/O=Sample, Corp./OU=Salse Dept./CN=salse.sample.com\" 3560
	exit 1
fi

PATH=/usr/bin:/bin

subject=$1
days=$2

tempfile_basename=/tmp/$(basename $0)-$(date +%Y%m%d%H%M%S)-$$

key_file=$tempfile_basename.key
csr_file=$tempfile_basename.csr
crt_file=$tempfile_basename.crt

openssl genrsa -out "$key_file" 2048
openssl req -new -key "$key_file" -out "$csr_file" -subj "$subject"
openssl x509 -req -signkey "$key_file" -in "$csr_file" -out "$crt_file" -days $days

exit 0


