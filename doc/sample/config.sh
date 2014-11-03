#!/bin/bash

config=openssl.cnf

if [ $# -ne 1 ]
then
	echo Uage: $0 $config
	exit 1
fi

if [ ! -f "$1" ]
then
	echo no such file. $1
	exit 1
fi

config=$1

echo "
####################################################################
[ client_cert ]
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
" >> "$config"

sed -i "s/^dir\s*=\s*\.\/demoCA/dir\t= .\t/g" $config

