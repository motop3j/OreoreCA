#!/bin/bash

crl_file=crl.pem
old_hash=
if [ -f "$crl_file" ]; then
	old_hash=crl/$(openssl crl -noout -hash -in "$crl_file").r0
fi

config=$(dirname $0)/openssl.cnf
openssl ca -config "$config" -gencrl -out "$crl_file"
new_hash=crl/$(openssl crl -noout -hash -in "$crl_file").r0
if [ "$old_hash" != "$new_hash" -o ! -L "$old_hash" ]; then
	[ -L "$old_hash" ] && rm "$old_hash"
	ln -s "$crl_file" "$new_hash"
fi

