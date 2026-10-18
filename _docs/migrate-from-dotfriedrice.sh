#!/usr/bin/env bash
# One-time helper for a machine that was set up with the old, symlink based
# DotFriedRice installer. Run it BEFORE the first `chezmoi apply`.
#
# Why: the old setup symlinked files and directories from your home into the
# clone (~/dotfriedrice). Files that only exist there, such as config.local,
# ~/.pi/agent/auth.json or the zsh history, would be left behind, and chezmoi
# could write straight through a directory link into the clone.
#
# What it does:
#   1. Replaces every symlink in your home that points into the old clone with
#      a real copy of what it pointed to (whole directories for directory links).
#   2. Removes links into the clone that are dangling, and the old `dotfriedrice`
#      command.
#   3. Copies the zsh history to its new place, ~/.config/zsh/.zsh_history.
#   4. Drops the obsolete `export DOTFRIEDRICE_PATH=` line from .zprofile.local.
#   5. Replaces /etc symlinks into the clone (dnf.conf, keyd, ...) with real
#      files, using sudo, so package managers keep working.
#
# The old clone itself is never modified, moved or deleted. Keep it until you're
# happy with the new setup.
#
# Usage:
#   _docs/migrate-from-dotfriedrice.sh [--dry-run] [PATH_TO_OLD_CLONE]
#
# The clone defaults to $DOTFRIEDRICE_PATH, then ~/dotfriedrice.

set -o errexit
set -o pipefail
set -o nounset

DRY_RUN=0
OLD=""

for arg in "${@}"; do
  case "${arg}" in
  -n | --dry-run) DRY_RUN=1 ;;
  -h | --help)
    sed -n '2,/^$/p' "${0}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  -*)
    echo "Unknown flag: ${arg}" >&2
    exit 1
    ;;
  *) OLD="${arg}" ;;
  esac
done

OLD="${OLD:-"${DOTFRIEDRICE_PATH:-"${HOME}/dotfriedrice"}"}"

if [ ! -d "${OLD}" ]; then
  echo "The old clone '${OLD}' doesn't exist, pass its path as an argument." >&2
  exit 1
fi

if [ ! -f "${OLD}/dotfriedrice" ] && [ ! -f "${OLD}/dotfriedrice-config" ]; then
  echo "'${OLD}' doesn't look like a DotFriedRice clone (no dotfriedrice script)." >&2
  exit 1
fi

OLD="$(realpath -ms -- "${OLD}")"
OLD_REAL="$(realpath -- "${OLD}")"
CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"

run() {
  if [ "${DRY_RUN}" == "1" ]; then
    printf '  [dry run] %s\n' "${*}"
  else
    "${@}"
  fi
}

# Print the normalized path that a symlink points to if that is inside the old
# clone. Symlinks on the way are not resolved, so a chain (~/.XCompose ->
# ~/.config/XCompose -> clone) only counts at its last hop.
points_into_clone() {
  local link="${1}"
  local raw=
  raw="$(readlink -- "${link}")"

  [[ "${raw}" != /* ]] && raw="$(dirname -- "${link}")/${raw}"
  raw="$(realpath -ms -- "${raw}")"

  case "${raw}" in
  "${OLD}" | "${OLD}"/* | "${OLD_REAL}" | "${OLD_REAL}"/*)
    printf '%s\n' "${raw}"
    ;;
  *) return 1 ;;
  esac
}

materialized=0
removed=0

migrate_link() {
  local link="${1}"
  local target=

  target="$(points_into_clone "${link}")" || return 0

  if [ "${target}" == "${OLD}/dotfriedrice" ] || [ "${target}" == "${OLD_REAL}/dotfriedrice" ]; then
    echo "remove     ${link} (the old dotfriedrice command)"
    run rm -f -- "${link}"
    removed=$((removed + 1))
    return 0
  fi

  if [ ! -e "${target}" ] && [ ! -L "${target}" ]; then
    echo "remove     ${link} (dangling, ${target} doesn't exist)"
    run rm -f -- "${link}"
    removed=$((removed + 1))
    return 0
  fi

  echo "copy       ${link} <- ${target}"

  if [ "${DRY_RUN}" == "1" ]; then
    materialized=$((materialized + 1))
    return 0
  fi

  local tmp="${link}.dfr-migrate.$$"

  rm -rf -- "${tmp}"
  cp -a -- "${target}" "${tmp}"
  rm -f -- "${link}"
  mv -- "${tmp}" "${link}"
  materialized=$((materialized + 1))
}

echo ":: Replacing symlinks into '${OLD}' with real files"

# Places the old installer linked into. find doesn't follow symlinks, so a
# directory link shows up as one entry and is copied as a whole.
find_links() {
  find "${HOME}" -maxdepth 1 -type l -print0 2>/dev/null

  local root
  for root in "${CONFIG_HOME}" "${HOME}/.pi" "${HOME}/.vscode" "${HOME}/.local/bin" \
    "${HOME}/.local/share/applications" "${HOME}/.local/share/thumbnailers"; do
    if [ -d "${root}" ]; then
      find "${root}" -maxdepth 6 -type l -print0 2>/dev/null
    fi
  done
}

mapfile -d '' -t links < <(find_links | sort -z -u)

for link in "${links[@]}"; do
  migrate_link "${link}"
done

remaining=0
for link in "${links[@]}"; do
  if [ -L "${link}" ] && points_into_clone "${link}" >/dev/null; then
    remaining=$((remaining + 1))
  fi
done

echo
echo ":: Zsh history"

old_history="${OLD}/.config/zsh/.zsh_history"
new_history="${CONFIG_HOME}/zsh/.zsh_history"

if [ -f "${old_history}" ] && [ ! -e "${new_history}" ]; then
  run mkdir -p -- "$(dirname -- "${new_history}")"
  run cp -a -- "${old_history}" "${new_history}"
  echo "copied     ${old_history} -> ${new_history}"
else
  echo "nothing to copy"
fi

echo
echo ":: .zprofile.local"

zprofile_local="${CONFIG_HOME}/zsh/.zprofile.local"

if [ -f "${zprofile_local}" ] && grep -q '^export DOTFRIEDRICE_PATH=' "${zprofile_local}"; then
  run sed -i '/^export DOTFRIEDRICE_PATH=/d' "${zprofile_local}"
  echo "removed the DOTFRIEDRICE_PATH line from ${zprofile_local}"
else
  echo "nothing to change"
fi

echo
echo ":: System files in /etc"

system_links=()
for path in /etc/dnf/dnf.conf /etc/keyd/default.conf /etc/conf.d/pacman-contrib \
  /etc/pacman.d/01-options.conf /etc/pacman.d/02-ignore.conf /etc/wsl.conf; do
  if [ -L "${path}" ] && points_into_clone "${path}" >/dev/null; then
    system_links+=("${path}")
  fi
done

if ((${#system_links[@]} == 0)); then
  echo "nothing to change"
else
  for path in "${system_links[@]}"; do
    target="$(points_into_clone "${path}")"

    if [ -f "${target}" ]; then
      echo "copy       ${path} <- ${target} (sudo)"
      run sudo cp --remove-destination -- "${target}" "${path}"
    else
      echo "remove     ${path} (dangling, sudo)"
      run sudo rm -f -- "${path}"
    fi
  done
fi

echo
if [ "${DRY_RUN}" == "1" ]; then
  echo "Dry run, nothing was changed."
else
  echo "Done: ${materialized} copied, ${removed} removed, ${remaining} links into the clone left."
fi

cat <<EOF

Next:
  chezmoi init <your fork's URL or path>   # asks for name, email and signing key
  chezmoi diff                             # review what's about to change
  chezmoi apply

Your old clone is untouched at ${OLD}. Delete it when you're done.
EOF
