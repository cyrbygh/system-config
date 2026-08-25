#!/usr/bin/env bash
set -euo pipefail

# Include everything in the global config.
pushd ../_global > /dev/null
. setup.sh
popd > /dev/null
. ../../scripts/encrypt.sh

crypt-link ./gitconfig ~/.gitconfig
link ../_shared/gitconfig ~/.gitconfig-anon

crypt-link ./env ~/.env/work

