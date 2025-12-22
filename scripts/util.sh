function error {
  printf "\033[0;31m%s\033[0m\n" "${1}"
}

function success {
    printf "\033[0;32m%s\033[0m\n" "${1}"
}

function abspath {
    [[ ${1} = /* ]] && echo "${1}" || echo "${PWD}/${1#./}"
}

function crypt-link {
    crypt "${1}"
    link "${1}.decrypted" "${2}"
}

# The directory of the system config repo.
SYSTEM_CONFIG_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"

# Helper function to relativize paths in a way that makes them more nicer for display (i.e. relativizes to the system-config dir or home directory)
function nicepath {
  local path="${1}"

  # If path starts with base, remove the prefix and add ./ prefix.
  if [[ "${path}" == "${SYSTEM_CONFIG_DIR}"/* ]]; then
    path="./${path#"${SYSTEM_CONFIG_DIR}"/}"
  elif [[ "${path}" == "${HOME}"/* ]]; then
    # Replace home directory with ~.
    path="~/${path#"${HOME}"/}"
  elif [[ "${path}" == "${HOME}" ]]; then
    path="~"
  fi

  echo "${path}"
}
