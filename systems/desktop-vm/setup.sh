#!/usr/bin/env bash
set -euo pipefail

# Include everything in the global config.
pushd ../_global > /dev/null
. setup.sh
popd > /dev/null
. ../../scripts/encrypt.sh

link ./sway ~/.config/sway/config
link ./waybar ~/.config/waybar
link ./kitty.conf ~/.config/kitty/kitty.conf
link ./env/kitty ~/.env/kitty

link ../_shared/mako.conf ~/.config/mako/config
link ../_shared/env/nixos ~/.env/nixos
link ../_shared/env/flatpak ~/.env/flatpak
link ../_shared/gitconfig ~/.gitconfig

crypt ./ssh/id_ed25519
link ./ssh/id_ed25519.decrypted ~/.ssh/id_ed25519
link ./ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub

