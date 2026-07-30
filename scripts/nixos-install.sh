#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: nixos-install.sh <system-name> [age-key-path]"
  exit 1
fi

SYSTEM="${1}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -eq 2 ]]; then
  install -m 400 "${2}" /etc/age_key
fi

sudo nixos-rebuild switch --flake "${REPO_ROOT}/systems/_shared/nixos#${SYSTEM}"
