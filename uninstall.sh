#!/usr/bin/env bash

set -euo pipefail

SYSTEM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT_SYSTEM_DIR="${SYSTEM_CONFIG_DIR}/systems/current"

if [ ! -e "${CURRENT_SYSTEM_DIR}" ]; then
  echo "No system configuration installed."
  exit 1
fi

CURRENT_SYSTEM="$(basename $(readlink ${CURRENT_SYSTEM_DIR}))"
echo "Uninstalling system configuration [${CURRENT_SYSTEM}]."

pushd "${CURRENT_SYSTEM_DIR}" > /dev/null
_SYSTEM_OP=uninstall "${CURRENT_SYSTEM_DIR}/setup.sh"
popd > /dev/null

rm -f "${CURRENT_SYSTEM_DIR}"
