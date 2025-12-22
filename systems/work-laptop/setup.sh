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

crypt ./wg/host
crypt ./wg/private_key

WG_CONNECT_PATH="${HOME}/.local/bin/wg-connect"

case "${_SYSTEM_OP}" in
    "install")
        rm -f "${WG_CONNECT_PATH}"
        echo "#!/usr/bin/env bash" > "${WG_CONNECT_PATH}"
        echo "REMOTE_HOST=\"$(cat ./wg/host.decrypted)\" PRIVATE_KEY=\"$(cat ./wg/private_key.decrypted)\" ${PWD}/wg/connect.sh \$@" >> "${WG_CONNECT_PATH}"
        chmod +x "${WG_CONNECT_PATH}"
        echo "Wrote custom WireGuard script to ${WG_CONNECT_PATH}"
        ;;
    "uninstall")
        rm -f "${WG_CONNECT_PATH}"
        echo "Removed custom WireGuard script from ${WG_CONNECT_PATH}"
        ;;
esac
