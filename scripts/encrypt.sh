# Check if age is installed.
if ! command -v age &> /dev/null; then
    echo "Error: age is not installed. Please install age to use encrypted file operations."
    exit 1
fi

# Import util.sh for the common functionality.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util.sh"

# Find the current system directory.
CURRENT_SYSTEM_DIR="${SYSTEM_CONFIG_DIR}/systems/current"
if [[ ! -e "${CURRENT_SYSTEM_DIR}" ]]; then
    echo "Error: No current system configuration found at ${CURRENT_SYSTEM_DIR}."
    exit 1
fi

# Resolve the symlink to get the actual system directory.
CURRENT_SYSTEM_DIR="$(cd "${CURRENT_SYSTEM_DIR}" &> /dev/null && pwd)"

# Check if encryption key exists when script is sourced.
ENCRYPTION_KEY_PATH="${CURRENT_SYSTEM_DIR}/encryption_key"
if [[ ! -f "${ENCRYPTION_KEY_PATH}" ]]; then
    echo "Error: Encryption key not found at ${ENCRYPTION_KEY_PATH}."
    exit 1
fi

# Check if decryption key exists when script is sourced.
DECRYPTION_KEY_PATH="${CURRENT_SYSTEM_DIR}/decryption_key"
if [[ ! -f "${DECRYPTION_KEY_PATH}" ]]; then
    echo "Error: Decryption key not found at ${DECRYPTION_KEY_PATH}."
    exit 1
fi

function crypt {
    # No-op if _SYSTEM_OP is not set to install, uninstall, encrypt, or encrypt-check.
    case "${_SYSTEM_OP}" in
        install|uninstall|encrypt|encrypt-check)
            # Continue with crypt operation.
            ;;
        *)
            return 0
            ;;
    esac

    local source="${1}"

    if [[ -z "${source}" ]]; then
        error "Usage: crypt <source>"
        return 1
    fi

    encrypted_file="$(abspath "${source}.encrypted")"
    decrypted_file="$(abspath "${source}.decrypted")"

    case "${_SYSTEM_OP}" in
        encrypt|encrypt-check)
            # Encrypt: encrypt decrypted file to encrypted file.
            # Encrypt-check: verify if decrypted file needs encryption without actually encrypting.
            if [[ ! -f "${decrypted_file}" ]]; then
                error " -> !! Decrypted source does not exist [${decrypted_file}] !!"
                return 1
            fi

            if [[ "${_SYSTEM_OP}" == "encrypt-check" ]]; then
                echo "Checking if [$(nicepath "${decrypted_file}")] matches -> [$(nicepath "${encrypted_file}")]."
            else
                echo "Encrypting [$(nicepath "${decrypted_file}")] -> [$(nicepath "${encrypted_file}")]."
            fi

            # Check if the encrypted file needs updating.
            local needs_update=true
            if [[ -f "${encrypted_file}" ]]; then
                # Decrypt existing encrypted file to compare.
                local temp_decrypted="${decrypted_file}.cmp"
                if age -d -i "${DECRYPTION_KEY_PATH}" -o "${temp_decrypted}" "${encrypted_file}" 2>/dev/null; then
                    if cmp -s "${decrypted_file}" "${temp_decrypted}"; then
                        needs_update=false
                    fi
                    rm -f "${temp_decrypted}"
                fi
            fi

            if [[ "${needs_update}" = false ]]; then
                echo " -> Up to date."
            else
                if [[ "${_SYSTEM_OP}" == "encrypt-check" ]]; then
                    echo " -> Needs encryption."
                    return 1
                fi

                # Encrypt the file using age.
                if ! age -R "${ENCRYPTION_KEY_PATH}" -o "${encrypted_file}" "${decrypted_file}"; then
                    error " -> !! Failed to encrypt [${decrypted_file}] !!"
                    return 1
                fi
                printf "\033[0;32m -> Updated.\033[0m\n"
            fi
            ;;
        uninstall)
            # Uninstall: remove decrypted file.
            echo "Removing decrypted file [$(nicepath "${decrypted_file}")]."

            # Remove the decrypted file.
            if [[ -f "${decrypted_file}" ]]; then
                rm "${decrypted_file}"
                echo " -> Decrypted file removed."
            else
                echo " -> Decrypted file does not exist."
            fi
            ;;
        install)
            # Install: decrypt encrypted file.
            if [[ ! -f "${encrypted_file}" ]]; then
                error " -> !! Encrypted source does not exist [${encrypted_file}] !!"
                return 1
            fi

            existing_decrypted="$(cat "${decrypted_file}" || echo "")"

            echo "Decrypting [$(nicepath "${encrypted_file}")] -> [$(nicepath "${decrypted_file}")]."

            decryption_tmp="$(mktemp)"
            cleanup() {
                rm -f "${decryption_tmp}"
            }
            trap cleanup EXIT

            # Decrypt the file using age.
            if ! age -d -i "${DECRYPTION_KEY_PATH}" -o "${decryption_tmp}" "${encrypted_file}"; then
                error " -> !! Failed to decrypt [${encrypted_file}] !!"
                return 1
            fi

            if [[ "${existing_decrypted}" == "$(cat "${decryption_tmp}")" ]]; then
                echo " -> Already decrypted."
            elif [ -n "${existing_decrypted}" ]; then
                error " -> !! Decrypted content mismatch. Maybe need to encrypt first? !!"
                return 1
            else
                mv "${decryption_tmp}" "${decrypted_file}"
                printf "\033[0;32m -> Decryption successful.\033[0m\n"
            fi
            ;;
    esac
}
