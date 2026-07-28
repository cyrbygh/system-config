#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: nixos-install.sh <system-name>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
nixos-install --flake "${REPO_ROOT}/systems/_shared/nixos#${1}"
