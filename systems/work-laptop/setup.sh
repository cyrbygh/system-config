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
crypt-link ./claude_global_conf.md ~/.claude/CLAUDE.md

# Claude commands. The real command names live in an encrypted script so they are not exposed here.
# Order matters on uninstall, since crypt removes the decrypted script it needs to source.
if [[ "${_SYSTEM_OP}" == "uninstall" ]]; then
  . ./claude_commands/setup.sh.decrypted
  crypt ./claude_commands/setup.sh
else
  crypt ./claude_commands/setup.sh
  . ./claude_commands/setup.sh.decrypted
fi

