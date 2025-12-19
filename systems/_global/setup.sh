#!/usr/bin/env bash

# Check if zsh is installed.
if ! command -v zsh &> /dev/null; then
    echo "Error: zsh is required, but not installed."
    exit 1
fi

source ../../scripts/link.sh

link ./gitignore ~/.gitignore
link ./nanorc ~/.nanorc
link ./tmux.conf ~/.tmux.conf
link ./vimrc ~/.vimrc
link ./../.. ~/.system-config
link ./zshrc.sh ~/.zshrc
mkdir -p ~/.scripts
mkdir -p ~/.env
link ./env/ ~/.env/global
