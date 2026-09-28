# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

# A throwaway git repo whose lint manifest holds $1, with origin's HEAD on main like a clone's. No
# argument, no manifest.
repo() {
  dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
  git init -q "${dir}"
  git -C "${dir}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  mkdir "${dir}/.github"
  if [[ $# -gt 0 ]]; then printf '%s' "$1" > "${dir}/.github/lint-checks.json"; fi
  echo "${dir}"
}

# Writes $3, or nothing, to the file $2 in the repo $1, and has git track it.
track() {
  if [[ $2 == */* ]]; then mkdir -p "$1/${2%/*}"; fi
  printf '%s' "${3-}" > "$1/$2"
  git -C "$1" add "$2"
}
