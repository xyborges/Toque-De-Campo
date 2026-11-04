#!/bin/sh
set -eu
stage=/home/microgate/toque-deploy
private=/var/lib/toque-de-campo/accounts
# Preserve the SQLite snapshot and signing identity across repeat deployments.
if [ ! -f "$private/accounts.sqlite" ]; then
    install -o www-data -g www-data -m 600 "$stage/private/accounts.sqlite" "$private/accounts.sqlite"
fi
install -o www-data -g www-data -m 600 "$stage/private/signing.pem" "$private/signing.pem"
install -o www-data -g www-data -m 640 "$stage/private/service-token.sha256" "$private/service-token.sha256"
install -o root -g toque-server -m 640 "$stage/private/service-token" /etc/toque-de-campo/service-token
tar -xzf "$stage/private/legacy.tar.gz" -C "$private"
chown -R www-data:www-data "$private/legacy"
chmod 700 "$private/legacy"
if [ ! -f /etc/toque-de-campo/tls/ca.pem ]; then
    install -m 600 "$stage/private/tls.pem" /etc/toque-de-campo/tls/ca.pem
    install -m 644 "$stage/private/tls.crt" /etc/toque-de-campo/tls/ca.crt
fi
if [ ! -f /etc/toque-de-campo/tls/server.pem ]; then
    openssl req -new -newkey rsa:3072 -nodes -keyout /etc/toque-de-campo/tls/server.pem -out /etc/toque-de-campo/tls/server.csr -subj '/CN=192.168.101.24/O=Toque de Campo' >/dev/null 2>&1
    printf 'subjectAltName=IP:192.168.101.24,IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer:always\n' >/etc/toque-de-campo/tls/server.ext
    openssl x509 -req -in /etc/toque-de-campo/tls/server.csr -CA /etc/toque-de-campo/tls/ca.crt -CAkey /etc/toque-de-campo/tls/ca.pem -CAcreateserial -days 825 -sha256 -extfile /etc/toque-de-campo/tls/server.ext -out /etc/toque-de-campo/tls/server.crt >/dev/null 2>&1
fi
chmod 600 /etc/toque-de-campo/tls/server.pem
install -m 644 "$stage/public/api.php" /var/www/toque-de-campo/accounts/api.php
install -m 644 "$stage/nginx-toque.conf" /etc/nginx/sites-available/toque-de-campo
if [ -L /etc/nginx/sites-enabled/default ]; then unlink /etc/nginx/sites-enabled/default; fi
ln -sfn /etc/nginx/sites-available/toque-de-campo /etc/nginx/sites-enabled/toque-de-campo
install -m 644 "$stage/toque-naval.service" /etc/systemd/system/toque-naval.service
nginx -t
php -l /var/www/toque-de-campo/accounts/api.php
systemctl daemon-reload
systemctl enable nginx php8.3-fpm
systemctl reload nginx
echo ACCOUNTS_HTTPS_READY
