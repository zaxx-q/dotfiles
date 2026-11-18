#!/usr/bin/env bash
# Hooks of `chezmoi re-add` and `chezmoi add` for the files of
# home/.chezmoidata/keep.yaml. Their source is a modify_ template and not a copy
# of the file, and chezmoi can't run a template backwards. They are set in
# home/.chezmoi.toml.tmpl, so run `chezmoi init` once on a machine to get them.
#
# After `chezmoi re-add` (which skips these files): the file of this machine goes
# into its hidden copy in the repo, except for the parts that the app rewrites by
# itself, those stay as the repo has them so git doesn't see them change (see
# home/.chezmoitemplates/keep-readd).
#
#   chezmoi re-add                           all of those files
#   chezmoi re-add ~/.pi/agent/settings.json only that one
#
# Before `chezmoi add`: refuses when one of those files is among the targets.
# `add` would delete the modify_ file and put a copy of the machine's file in its
# place, with the lines that change on their own, and no warning.
#
# It can also be run by hand to do the re-add, with the files as arguments or
# without for all of them.

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

exit "${refused}"
