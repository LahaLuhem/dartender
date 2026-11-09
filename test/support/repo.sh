# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

repo() {
  dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
  git init -q "${dir}"
  # Like a clone's, since callers.sh reads the default branch from it.
  git -C "${dir}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  mkdir "${dir}/.github"
  if [[ $# -gt 0 ]]; then printf '%s' "$1" > "${dir}/.github/lint-checks.json"; fi
  echo "${dir}"
}

track() {
  if [[ $2 == */* ]]; then mkdir -p "$1/${2%/*}"; fi
  printf '%s' "${3-}" > "$1/$2"
  git -C "$1" add "$2"
}
