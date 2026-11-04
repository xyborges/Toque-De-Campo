#!/bin/sh
set -eu
stage=/home/microgate/toque-build
backup=/etc/toque-de-campo/security182-backup
install -d -m 700 "$backup"
if [ ! -f "$backup/nginx-toque.conf" ]; then cp /etc/nginx/sites-available/toque-de-campo "$backup/nginx-toque.conf"; fi
install -m 644 "$stage/nginx-toque.conf" /etc/nginx/sites-available/toque-de-campo
if ! nginx -t; then
    cp "$backup/nginx-toque.conf" /etc/nginx/sites-available/toque-de-campo
    exit 1
fi
if ! nft list table inet toque_game_guard >/dev/null 2>&1; then nft add table inet toque_game_guard; fi
if ! nft -c -f "$stage/game-guard.nft"; then
    cp "$backup/nginx-toque.conf" /etc/nginx/sites-available/toque-de-campo
    exit 1
fi
install -m 644 "$stage/game-guard.nft" /etc/toque-de-campo/game-guard.nft
install -m 644 "$stage/toque-network-guard.service" /etc/systemd/system/toque-network-guard.service
systemctl daemon-reload
systemctl enable --now toque-network-guard.service
systemctl reload nginx
printf '\nSECURITY182_NETWORK_AND_HTTPS_ENABLED\n'
