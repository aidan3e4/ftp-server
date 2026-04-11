#!/usr/bin/env bash
set -euo pipefail

# Redeploy without changing secrets (use deploy_first.sh for initial setup)

fly deploy
