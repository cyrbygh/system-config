#!/usr/bin/env bash

set -euo pipefail

SYSTEM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT_SYSTEM=""
CURRENT_SYSTEM_DIR="${SYSTEM_CONFIG_DIR}/systems/current"

if [ -e "${CURRENT_SYSTEM_DIR}" ]; then
  CURRENT_SYSTEM="$(basename "$(readlink "${CURRENT_SYSTEM_DIR}")")"
  echo "Current system config is [${CURRENT_SYSTEM}]."
  echo ""
fi

target="${CURRENT_SYSTEM}"

if [ ! -z "${1:-}" ]; then
  if [[ "${1:0:1}" == "_" ]] || [ ! -d "${SYSTEM_CONFIG_DIR}/systems/${1}" ]; then
    echo "${1} is not a valid system type."
    exit 1
  fi
  target="${1}"
fi

if [ "${target}" != "${CURRENT_SYSTEM}" ] && [ ! -z "${CURRENT_SYSTEM}" ]; then
  echo "Uninstalling old system config [${CURRENT_SYSTEM}]..."
  echo ""
  pushd "${SYSTEM_CONFIG_DIR}/systems/${CURRENT_SYSTEM}" > /dev/null
  _SYSTEM_OP=uninstall "${SYSTEM_CONFIG_DIR}/systems/${CURRENT_SYSTEM}/setup.sh"
  rm "${SYSTEM_CONFIG_DIR}/systems/current"
  popd > /dev/null
  echo ""
fi

if [ -z "${target}" ]; then
  echo "No system configuration target specified."
  exit 1
fi

if [ "${CURRENT_SYSTEM}" = "${target}" ]; then
  echo "Updating existing system config [${target}]."
else
  echo "Installing new system config [${target}]."
  ln -s "${SYSTEM_CONFIG_DIR}/systems/${target}" "${CURRENT_SYSTEM_DIR}"
fi
echo ""

pushd "${SYSTEM_CONFIG_DIR}/systems/${target}" > /dev/null
_SYSTEM_OP=install "${SYSTEM_CONFIG_DIR}/systems/${target}/setup.sh"
popd > /dev/null
