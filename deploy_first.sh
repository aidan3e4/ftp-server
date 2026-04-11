#!/usr/bin/env bash
set -euo pipefail

# First-time setup: set secrets from .env and deploy

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

echo "Loading secrets from $ENV_FILE..."

secrets=()
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  secrets+=("$line")
done < "$ENV_FILE"

if [ ${#secrets[@]} -eq 0 ]; then
  echo "Error: No variables found in $ENV_FILE"
  exit 1
fi

echo "Setting ${#secrets[@]} secret(s)..."
fly secrets set "${secrets[@]}"

echo "Deploying..."
fly deploy

echo ""
echo "Next: get your app IP and set the masquerade address for passive FTP:"
echo "  fly ips list"
echo "  fly secrets set MASQUERADE_ADDRESS=<ip>"
echo "  ./deploy.sh"
