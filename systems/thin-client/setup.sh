#!/usr/bin/env bash
set -euo pipefail

# Include everything in the global config.
pushd ../_global > /dev/null
. setup.sh
popd > /dev/null
. ../../scripts/encrypt.sh

link ../_shared/env/nixos ~/.env/nixos
link ../_shared/gitconfig ~/.gitconfig

crypt-link ./ssh/id_ed25519 ~/.ssh/id_ed25519
link ./ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
