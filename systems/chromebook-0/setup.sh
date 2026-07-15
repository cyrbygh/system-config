#!/usr/bin/env bash
set -euo pipefail

# Include everything in the global config.
pushd ../_global > /dev/null
. setup.sh
popd > /dev/null
. ../../scripts/encrypt.sh

link ../_shared/env/nixos ~/.env/nixos
link ../_shared/gitconfig ~/.gitconfig

crypt ./wg/host
crypt ./wg/private_key
