#!/bin/sh
# One-time administrator operation. Does not activate a game release.
set -eu
test "$(id -u)" = 0 || { echo 'Administrator authentication required.' >&2; exit 1; }
test "$#" = 1 || { echo 'Expected reviewed helper SHA-256.' >&2; exit 1; }
case "$1" in *[!a-f0-9]*|'') exit 1;; esac
test "${#1}" = 64 || exit 1
source=/home/microgate/toque-deploy/toque-deploy-br.py
test -f "$source" && test ! -L "$source"
backup=/var/backups/toque-de-campo/toque-deploy-before-br.py
mkdir -p /var/backups/toque-de-campo
chmod 700 /var/backups/toque-de-campo
temporary=$(mktemp /usr/local/sbin/.toque-deploy-br.XXXXXX)
trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
install -o root -g root -m 755 "$source" "$temporary"
printf '%s  %s\n' "$1" "$temporary" | sha256sum --check --status
/usr/bin/python3 -m py_compile "$temporary"
if test ! -e "$backup"; then install -o root -g root -m 700 /usr/local/sbin/toque-deploy "$backup"; fi
mv -f -- "$temporary" /usr/local/sbin/toque-deploy
# Existing SSH/web/game rules and firewall enabled state remain as configured.
if command -v ufw >/dev/null 2>&1; then
    ufw allow 3016/udp comment 'Toque BR matchmaking'
    ufw allow 3020:3021/udp comment 'Toque BR matches'
fi
echo BR_SUPPORT_INSTALLED
