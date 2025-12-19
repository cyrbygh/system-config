#!/usr/bin/env bash

set -euo pipefail

# Parse command line arguments
check_only=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --check)
      check_only=true
      shift
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [OPTIONS]"
      echo ""
      echo "Encrypt files for the current system configuration."
      echo ""
      echo "OPTIONS:"
      echo "    --check    Check if files need encryption without actually encrypting"
      echo "    --help     Show this help message"
      echo ""
      echo "Exit codes:"
      echo "    0    Success (no changes needed when using --check)"
      echo "    1    Files need encryption (when using --check) or other error"
      exit 0
      ;;
    *)
      echo "Error: Unknown option ${1}"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

SYSTEM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT_SYSTEM_DIR="${SYSTEM_CONFIG_DIR}/systems/current"

if [ ! -e "${CURRENT_SYSTEM_DIR}" ]; then
  echo "No system configuration installed."
  exit 1
fi

CURRENT_SYSTEM="$(basename "$(readlink "${CURRENT_SYSTEM_DIR}")")"

if [[ "${check_only}" == true ]]; then
  echo "Checking encryption status for system configuration [${CURRENT_SYSTEM}]."
else
  echo "Encrypting files for system configuration [${CURRENT_SYSTEM}]."
fi

pushd "${CURRENT_SYSTEM_DIR}" > /dev/null

if [[ "${check_only}" == true ]]; then
  _SYSTEM_OP=encrypt-check "${CURRENT_SYSTEM_DIR}/setup.sh"
else
  _SYSTEM_OP=encrypt "${CURRENT_SYSTEM_DIR}/setup.sh"
fi

popd > /dev/null
