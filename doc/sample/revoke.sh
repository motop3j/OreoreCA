#!/bin/bash

if [ $# -ne 1 ]; then
	echo Usage: $0 newcerts/XX.pem
	exit 1
fi

if [ ! -f "$1" ]; then
	echo no such file. $1
	exit 1
fi

config=$(dirname $0)/openssl.cnf
crlshell=$(dirname $0)/crl.sh
crt_file=$1

openssl ca -config "$config" -revoke "$crt_file"
if [ $? -ne 0 ]; then
	exit 1
fi
"$crlshell"
 
