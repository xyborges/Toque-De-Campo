#!/bin/sh
set -eu
umask 077
install -d -m 700 /etc/toque-de-campo/game-ca
install -d -m 750 -o root -g toque-server /etc/toque-de-campo/game-tls
if [ ! -f /etc/toque-de-campo/game-ca/ca.key ]; then
    openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 3650 -subj '/CN=Toque de Campo Game CA/O=Toque de Campo' -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' -keyout /etc/toque-de-campo/game-ca/ca.key -out /etc/toque-de-campo/game-ca/ca.crt
fi
if [ ! -f /etc/toque-de-campo/game-tls/server.key ]; then
    openssl req -new -newkey rsa:2048 -nodes -sha256 -subj '/CN=192.168.101.24/O=Toque de Campo' -keyout /etc/toque-de-campo/game-tls/server.key -out /etc/toque-de-campo/game-ca/server.csr
    printf '%s\n' 'basicConstraints=critical,CA:FALSE' 'keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth' 'subjectAltName=IP:192.168.101.24,DNS:srv-ia' > /etc/toque-de-campo/game-ca/server.ext
    openssl x509 -req -sha256 -days 825 -in /etc/toque-de-campo/game-ca/server.csr -CA /etc/toque-de-campo/game-ca/ca.crt -CAkey /etc/toque-de-campo/game-ca/ca.key -CAcreateserial -extfile /etc/toque-de-campo/game-ca/server.ext -out /etc/toque-de-campo/game-tls/server.crt
fi
chown root:toque-server /etc/toque-de-campo/game-tls/server.key /etc/toque-de-campo/game-tls/server.crt
chmod 640 /etc/toque-de-campo/game-tls/server.key
chmod 644 /etc/toque-de-campo/game-tls/server.crt
install -m 644 /etc/toque-de-campo/game-ca/ca.crt /home/microgate/toque-build/game-ca.crt
openssl verify -CAfile /etc/toque-de-campo/game-ca/ca.crt /etc/toque-de-campo/game-tls/server.crt
printf '\nGAME_TLS_PROVISIONED\n'
