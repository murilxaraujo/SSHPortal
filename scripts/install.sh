#!/usr/bin/env bash
# install.sh — append SSHPortal keys to ~/.ssh/authorized_keys without duplicates.
# Usage: PORTAL=https://your-portal bash install.sh
#        PORTAL=https://your-portal TYPE=ed25519 bash install.sh
set -euo pipefail

PORTAL="${PORTAL:-}"
TYPE="${TYPE:-}"

if [ -z "$PORTAL" ]; then
  echo "error: set PORTAL=https://your-portal before running" >&2
  exit 1
fi

URL="$PORTAL/keys"
if [ -n "$TYPE" ]; then URL="$PORTAL/keys/$TYPE"; fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
AUTH="$HOME/.ssh/authorized_keys"
[ -f "$AUTH" ] || touch "$AUTH"
chmod 600 "$AUTH"

NEW="$(curl -fsSL "$URL")"
ADDED=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! grep -qxF "$line" "$AUTH"; then
    echo "$line" >> "$AUTH"
    ADDED=$((ADDED+1))
  fi
done <<< "$NEW"

echo "sshportal: added $ADDED key(s)"
