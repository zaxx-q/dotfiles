#!/usr/bin/env bash
# Post hook of `chezmoi diff`, set in home/.chezmoi.toml.tmpl together with
# diff.exclude = ["scripts"]. chezmoi doesn't manage /etc, so all it can show of
# the system files is the script that installs them, and that setting hides
# scripts. This prints what `chezmoi apply` is going to change in the system
# files instead: a diff for each file that is missing or different, and nothing
# when they all match. It's the same text as at the top of the script when
# scripts aren't hidden (see home/.system/files-state.sh).
#
# Not when `chezmoi diff` was given a path, that is for files in ~.

set -o errexit -o nounset -o pipefail

[ "$(uname -s)" == "Linux" ] || exit 0

chezmoi_cmd=("${CHEZMOI_EXECUTABLE:-chezmoi}")
if [ -n "${CHEZMOI_CONFIG_FILE:-}" ]; then
  chezmoi_cmd+=(--config "${CHEZMOI_CONFIG_FILE}")
fi

source_dir="${CHEZMOI_SOURCE_DIR:-$("${chezmoi_cmd[@]}" source-path)}"
chezmoi_cmd+=(--source "${source_dir}")
work_dir="${CHEZMOI_COMMAND_DIR:-${PWD}}"

if [ -n "${CHEZMOI_ARGS:-}" ]; then
  read -r -a args <<<"${CHEZMOI_ARGS}"
  after_command=0

  for arg in "${args[@]}"; do
    if [ "${after_command}" == "0" ]; then
      if [ "${arg}" == "diff" ]; then
        after_command=1
      fi
      continue
    fi

    case "${arg}" in
    -*) ;;
    *)
      if [[ "${arg}" != /* ]]; then
        arg="${work_dir}/${arg}"
      fi

      # A path that exists was asked for, not the system files.
      if [ -e "${arg}" ]; then
        exit 0
      fi
      ;;
    esac
  done
fi

files="$("${chezmoi_cmd[@]}" execute-template '{{ template "system-files" . }}')"
changes="$(bash "$(dirname -- "${BASH_SOURCE[0]}")/files-state.sh" --diff "${files}")"
[ -n "${changes}" ] || exit 0

echo
echo "System files that chezmoi apply is going to change (outside of ~, chezmoi can't diff them):"
echo

# The output of the hook isn't going through the pager of chezmoi.
if [ -t 1 ] && command -v delta >/dev/null 2>&1; then
  delta --paging=never <<<"${changes}" || echo "${changes}"
else
  echo "${changes}"
fi
