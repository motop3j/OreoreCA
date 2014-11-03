#!/bin/bash

if [ $# -ne 1 ]
then
	echo Usage: $0 \"/C=JP/ST=Tokyo/O=Sample,Ltd./OU=Salse/CN=Sample CA\"
	exit 1
fi

subject=$1
days=$((($(date -d "20491231" +%s) - $(date +%s)) / 60 / 60 / 24 + 1))
config=$(dirname $0)/openssl.cnf
crlshell=$(dirname $0)/crl.sh

key_file=private/cakey.pem
csr_file=work/cacsr.pem
crt_file=cacert.pem
crl_file=crl.pem

echo -n > index.txt
echo 01 > serial
echo 00 > crlnumber
for dir in certs crl newcerts private work
do
	if [ -d "$dir" ]
	then
		rm -r "$dir"
	fi
	mkdir "$dir"
done

openssl genrsa -out "$key_file"
openssl req -new -key "$key_file" -out "$csr_file" -subj "$subject"
openssl ca -config "$config" -create_serial -out "$crt_file" -days $days -selfsign -extensions v3_ca -batch -infiles "$csr_file"
lastpem=newcerts/$(ls -rt newcerts|tail -n 1)
ln -s "$lastpem" certs/$(openssl x509 -noout -hash -in "$lastpem").0
"$crlshell"
