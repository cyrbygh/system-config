# Import util.sh for the common functionality.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util.sh"

function link {
  source="$(abspath "${1}")"
  target="$(abspath "${2}")"

  case "${_SYSTEM_OP}" in
    install)
      echo "Creating link [$(nicepath "${source}")] -> [$(nicepath "${target}")]."
      ;;
    uninstall)
      echo "Removing link [$(nicepath "${source}")] -> [$(nicepath "${target}")]."
      ;;
    *)
      # No-op if _SYSTEM_OP is not set to install or uninstall.
      return 0
      ;;
  esac

  if [ ! -f "${source}" ] && [ ! -d "${source}" ] ; then
    error " -> !! Source does not exist [${source}] !! "
    return 1
  fi

  if [ -f "${target}" ] || [ -d "${target}" ]; then
    if [ ! -L "${target}" ]; then
      error " -> !! ${target} exists but is not a symlink! !!"
      return 1
  elif [ ! "${source}" -ef "$(readlink "${target}")" ]; then
      error " -> !! ${target} is a symlink, but does not point to the source !!"
      error "    [${source}] != [$(readlink "${target}")]"
      return 1
    fi
  fi

  case "${_SYSTEM_OP}" in
    uninstall)
      rm "${target}"
      echo " -> Symlink removed."
      ;;
    install)
      if [ -e "${target}" ]; then
        echo " -> Already exists."
      else
        mkdir -p "$(dirname "${target}")"
        ln -s "${source}" "${target}"
        if [[ $? != 0 ]]; then
          error " -> Failed to create symlink."
        else
          success " -> Symlink created."
        fi
      fi
      ;;
  esac
}
