#!/usr/bin/env bash
# Tells if the system files of this repo are installed, without sudo. chezmoi
# runs it while it renders .chezmoiscripts/run_after_10-system-files.sh.tmpl,
# that's how `chezmoi status` and `chezmoi apply` find out that a file in /etc
# was deleted or changed.
#
# The argument is lines of "<file in the repo>|<destination>" (the output of the
# system-files template, the rest of each line is ignored). It prints one word
# for every line, in the same order:
#
#   ok       the destination is a real file with the same content
#   differs  it has other content, or it's a symlink that gets replaced
#   missing  it doesn't exist
#
# A file this user can't read (mode 600, or in a folder it can't enter) can't be
# compared. For those the script keeps the hash of the repo file it installed
# last in ~/.local/state/dfr/system-files, and they are out of date when the
# repo file changed since then (or when it was never installed).
#
# With --diff as the first argument it prints what is different for each file
# that isn't ok instead, as a unified diff when this user can read the file. That
# is what the top of the script shows in `chezmoi diff`, chezmoi itself can only
# show the script since it doesn't manage /etc.
#
# This always exits 0 and prints a word for every line, a failure here would
# break every chezmoi command since it's called from a template.

records="${HOME}/.local/state/dfr/system-files"

_hash() {
  sha256sum -- "${1}" 2>/dev/null | cut -d " " -f 1
}

_state() {
  local src="${1}"
  local dest="${2}"
  local dir

  if [ -L "${dest}" ]; then
    echo "differs"
    return
  fi

  if [ -f "${dest}" ] && [ -r "${dest}" ]; then
    if [ "$(_hash "${src}")" == "$(_hash "${dest}")" ]; then
      echo "ok"
    else
      echo "differs"
    fi
    return
  fi

  if [ -e "${dest}" ] && [ ! -f "${dest}" ]; then
    # A folder or something else in the way, the script will complain about it.
    echo "differs"
    return
  fi

  if [ ! -e "${dest}" ]; then
    # It's only really missing when this user can look inside the closest folder
    # that exists, else the folder hides it.
    dir="$(dirname -- "${dest}")"
    while [ ! -e "${dir}" ] && [ "${dir}" != "/" ]; do
      dir="$(dirname -- "${dir}")"
    done

    if [ -x "${dir}" ]; then
      echo "missing"
      return
    fi
  fi

  # Not readable, so it can't be compared, use the record of the last install.
  if [ "$(cat -- "${records}/${dest//\//%}" 2>/dev/null)" == "$(_hash "${src}")" ]; then
    echo "ok"
  else
    echo "differs"
  fi
}

# What is different for a file that isn't ok, as text for a person.
_diff() {
  local src="${1}"
  local dest="${2}"
  local state="${3}"

  [ "${state}" != "ok" ] || return 0
  command -v diff >/dev/null 2>&1 || return 0

  if [ -L "${dest}" ]; then
    echo "${dest} is a symlink, chezmoi apply replaces it with a copy of the file"
  elif [ "${state}" == "missing" ]; then
    diff -u --label "${dest} (not installed)" --label "${dest} (repo)" /dev/null "${src}" || true
  elif [ -f "${dest}" ] && [ -r "${dest}" ]; then
    diff -u --label "${dest} (installed)" --label "${dest} (repo)" "${dest}" "${src}" || true
  elif [ -e "${dest}" ] && [ ! -f "${dest}" ]; then
    echo "${dest} is not a file, chezmoi apply can't replace it"
  else
    echo "${dest} can't be read by this user, ./run sys:diff shows what is different"
  fi
}

mode="state"
if [ "${1:-}" == "--diff" ]; then
  mode="diff"
  shift
fi

while IFS="|" read -r src dest _; do
  [ -n "${src}" ] || continue

  state="$(_state "${src}" "${dest}")"

  if [ "${mode}" == "diff" ]; then
    _diff "${src}" "${dest}" "${state}"
  else
    echo "${state}"
  fi
done <<<"${1:-}"

exit 0
