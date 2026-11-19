#!/usr/bin/env bash
# Hooks of `chezmoi re-add` and `chezmoi add` for what chezmoi can't re-add by
# itself. They are set in home/.chezmoi.toml.tmpl, so run `chezmoi init` once on
# a machine to get them.
#
# 1. The files of home/.chezmoidata/keep.yaml. Their source is a modify_ template
#    and not a copy of the file, and chezmoi can't run a template backwards.
#    After `chezmoi re-add` (which skips these files): the file of this machine
#    goes into its hidden copy in the repo, except for the parts that the app
#    rewrites by itself, those stay as the repo has them so git doesn't see them
#    change (see home/.chezmoitemplates/keep-readd).
#
#      chezmoi re-add                           all of those files
#      chezmoi re-add ~/.pi/agent/settings.json only that one
#
#    Before `chezmoi add`: refuses when one of those files is among the targets.
#    `add` would delete the modify_ file and put a copy of the machine's file in
#    its place, with the lines that change on their own, and no warning.
#
# 2. The system files, the ones outside of ~ that `chezmoi apply` installs from
#    home/.system/ (the list is home/.chezmoitemplates/system-files). chezmoi
#    only knows ~, so after a plain `chezmoi re-add` the ones that you changed in
#    /etc and so on are copied into the repo, what `./run sys:add` does. It
#    doesn't work with a path, chezmoi itself refuses one that is outside of ~
#    ("not in destination directory") before this runs. Only files that are in
#    the list, a new one is for `./run sys:add`. Not world readable files are
#    left alone, the repo is public.
#
#    A file that changed in the repo since it was installed (a `git pull`) isn't
#    overwritten with the old one in /etc, and neither is one that changed in
#    both places. That is known from ~/.local/state/dfr/system-files/, where the
#    script keeps the hash of what it installed last. Without that record the
#    file is taken over, as chezmoi does for files in ~.
#
# It can also be run by hand to do the re-add, with the files as arguments, for
# these and for system files (`keep-readd.sh /etc/kanata/config.kbd`), or
# without arguments for all of them.

set -o errexit -o nounset -o pipefail

command="${CHEZMOI_COMMAND:-re-add}"
chezmoi_cmd=("${CHEZMOI_EXECUTABLE:-chezmoi}")
if [ -n "${CHEZMOI_CONFIG_FILE:-}" ]; then
  chezmoi_cmd+=(--config "${CHEZMOI_CONFIG_FILE}")
fi

source_dir="${CHEZMOI_SOURCE_DIR:-$("${chezmoi_cmd[@]}" source-path)}"
chezmoi_cmd+=(--source "${source_dir}")
dest_dir="${CHEZMOI_DEST_DIR:-${HOME}}"
work_dir="${CHEZMOI_COMMAND_DIR:-${PWD}}"

# The files that were asked for. As a hook the command line is in
# CHEZMOI_ARGS, flags are skipped and so is anything that isn't a path that
# exists (the value of a flag like `-x scripts`). No files means all of them.
words=("$@")
if [ -n "${CHEZMOI_ARGS:-}" ]; then
  words=()
  read -r -a args <<<"${CHEZMOI_ARGS}"
  after_command=0

  for arg in "${args[@]}"; do
    if [ "${after_command}" == "0" ]; then
      if [ "${arg}" == "${command}" ]; then
        after_command=1
      fi
      continue
    fi

    case "${arg}" in
    --dry-run* | -n* | -[!-]*n*)
      # Nothing is going to change, so don't touch the repo or refuse.
      exit 0
      ;;
    -*) ;;
    *) words+=("${arg}") ;;
    esac
  done
fi

selected=()
for word in "${words[@]+"${words[@]}"}"; do
  if [[ "${word}" != /* ]]; then
    word="${work_dir}/${word}"
  fi

  if [ -e "${word}" ]; then
    selected+=("${word%/}")
  fi
done

# Whether a file is one of the files asked for, either by its name or by a
# folder that holds it. For re-add nothing asked for means all.
_selected() {
  local path

  if [ "${#selected[@]}" -eq 0 ]; then
    [ "${command}" != "add" ]
    return
  fi

  for path in "${selected[@]}"; do
    if [[ "${1}" == "${path}" || "${1}" == "${path}/"* ]]; then
      return 0
    fi
  done

  return 1
}

# shellcheck disable=SC2016
targets="$("${chezmoi_cmd[@]}" execute-template '{{ range $target, $entry := .keep }}{{ $target }}|{{ $entry.base }}{{ "\n" }}{{ end }}')"
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
refused=0

while IFS="|" read -r target base; do
  [ -n "${target}" ] || continue

  dest="${dest_dir}/${target}"
  _selected "${dest}" || continue

  if [ "${command}" == "add" ]; then
    echo "chezmoi add would replace the modify_ file of ${dest} with a copy of it, which brings back what the app rewrites by itself. Use chezmoi re-add for this file instead." >&2
    refused=1
    continue
  fi

  [ -f "${dest}" ] || continue

  KEEP_TARGET="${target}" KEEP_DEST="${dest}" "${chezmoi_cmd[@]}" execute-template '{{ template "keep-readd" . }}' >"${tmp}"

  if ! cmp -s "${tmp}" "${source_dir}/${base}"; then
    cat "${tmp}" >"${source_dir}/${base}"
    echo "Re-added ${dest} to ${base}"
  fi
done <<<"${targets}"

# The system files, only after a re-add and on Linux (that's where they are).
_hash() {
  sha256sum -- "${1}" | cut -d " " -f 1
}

records="${HOME}/.local/state/dfr/system-files"

# Copy a file from the system into its place in the repo, if that's what
# happened to it. $1 the file in the repo, $2 the installed file.
_system_file() {
  local src="${1}"
  local dest="${2}"
  local name="${src#"${source_dir}/"}"
  local mode record

  # Only files that are already in the repo, `./run sys:add` adds new ones.
  # Missing files and symlinks are for `chezmoi apply`, it installs a copy.
  [ -f "${src}" ] || return 0
  [ -f "${dest}" ] && [ ! -L "${dest}" ] && [ -r "${dest}" ] || return 0
  ! cmp -s -- "${src}" "${dest}" || return 0

  mode="$(stat -c %a -- "${dest}")"
  if ! ((8#${mode} & 4)); then
    echo "${dest}: mode ${mode}, not world readable, so not re-added. It may hold secrets and this repo is public, ./run sys:add --force does it anyway" >&2
    return 0
  fi

  record="$(cat -- "${records}/${dest//\//%}" 2>/dev/null || true)"
  if [ -n "${record}" ]; then
    if [ "$(_hash "${dest}")" == "${record}" ]; then
      echo "${dest}: ${name} changed in the repo since it was installed, so not re-added. chezmoi apply installs it" >&2
      return 0
    elif [ "$(_hash "${src}")" != "${record}" ]; then
      echo "${dest}: changed here and in the repo (${name}) since it was installed, so not re-added. ./run sys:diff shows what is different" >&2
      return 0
    fi
  fi

  cat -- "${dest}" >"${src}.new"
  mv -- "${src}.new" "${src}"

  # Git only remembers whether a file is executable.
  if ((8#${mode} & 8#111)); then
    chmod 755 -- "${src}"
  else
    chmod 644 -- "${src}"
  fi

  mkdir -p -- "${records}"
  _hash "${src}" >"${records}/${dest//\//%}"
  echo "Re-added ${dest} to ${name}"
}

if [ "${command}" != "add" ] && [ "$(uname -s)" == "Linux" ]; then
  if files="$("${chezmoi_cmd[@]}" execute-template '{{ template "system-files" . }}' 2>&1)"; then
    while IFS="|" read -r src dest _; do
      [ -n "${src}" ] || continue
      _selected "${dest}" || continue

      _system_file "${src}" "${dest}"
    done <<<"${files}"
  else
    echo "Couldn't list the system files, so they weren't re-added: ${files}" >&2
  fi
fi

exit "${refused}"
