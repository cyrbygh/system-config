#!/usr/bin/env bash

# Include everything in the global config.
pushd ../_global > /dev/null
. setup.sh
popd > /dev/null
. ../../scripts/encrypt.sh

link ./sway ~/.config/sway/config
link ./waybar ~/.config/waybar
link ../_shared/foot.ini ~/.config/foot/foot.ini
link ../_shared/kitty.conf ~/.config/kitty/kitty.conf
link ../_shared/mako.conf ~/.config/mako/config
link ../_shared/env/nixos ~/.env/nixos
link ../_shared/env/flatpak ~/.env/flatpak
link ../_shared/env/kitty ~/.env/kitty
link ../_shared/gitconfig ~/.gitconfig

crypt ./ssh/id_ed25519
link ./ssh/id_ed25519.decrypted ~/.ssh/id_ed25519
link ./ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub

