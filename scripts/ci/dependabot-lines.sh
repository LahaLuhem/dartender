#!/usr/bin/env bash
# shellcheck disable=SC2154  # actions/release sets what this reads
set -euo pipefail
folder="$1" since="$2"

pubspec=pubspec.yaml
if [[ ${folder} != . ]]; then pubspec="${folder}/pubspec.yaml"; fi

# As values, so a comment or quoting change in the pubspec isn't a dependency change.
dependencies() {
  if git cat-file -e "$1:${pubspec}" 2>/dev/null; then
    git show "$1:${pubspec}" | yq -o=json -I=0 '.dependencies'
  fi
}

shas="$(git log --reverse --format=%H "${since}..HEAD" -- "${pubspec}")"
declare -A seen=()
titles=()
while IFS= read -r sha; do
  if [[ -z ${sha} ]]; then continue; fi
  before="$(dependencies "${sha}^")"
  after="$(dependencies "${sha}")"
  if [[ ${before} == "${after}" ]]; then continue; fi
  # The PR's author rather than the commit's, so a fix pushed onto a Dependabot PR counts as its.
  pull="$(gh api "repos/${REPO}/commits/${sha}/pulls" \
    --jq '.[] | select(.user.login == "dependabot[bot]") | [.number, .title] | @tsv')"
  if [[ -z ${pull} ]]; then continue; fi
  number="${pull%%$'\t'*}"
  if [[ -n ${seen[${number}]-} ]]; then continue; fi
  seen["${number}"]=1
  echo "#${number} is Dependabot's and changed the dependencies in ${pubspec}, so it gets a line." >&2
  titles+=("${pull#*$'\t'}")
done <<< "${shas}"
if [[ ${#titles[@]} -gt 0 ]]; then printf '%s\n' "${titles[@]}"; fi
