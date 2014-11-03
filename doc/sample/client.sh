#!/bin/bash

if [ $# -ne 1 ]
then
	echo Usage: $0 \"/C=JP/ST=Tokyo/O=Sample, Ltd./OU=Salse/CN=Taro Suzuki\"
	exit 1
fi

subject=$1

filename=/tmp/client-certification-$(date +%Y%m%d%H%M%S)
config=$(dirname $0)/openssl.cnf

openssl genrsa -out $filename.key 
openssl req -new -key $filename.key -out $filename.csr -subj "$subject"
openssl ca -config "$config" -policy policy_anything -batch -extensions client_cert -infiles $filename.csr 

serial=$(ls -rt newcerts|tail -n 1|sed "s/\.pem$//")
key_file=private/$serial.pem
csr_file=work/$serial.csr.pem
crt_file=newcerts/$serial.pem
p12_file=work/$serial.p12
ca_file=cacert.pem

mv "$filename.key" "$key_file"
mv "$filename.csr" "$csr_file"
ln -sf "$crt_file" certs/$(openssl x509 -in $crt_file -noout -hash).0
openssl pkcs12 -export -password pass: -inkey "$key_file" -in "$crt_file" -certfile "$ca_file" -out "$p12_file"

