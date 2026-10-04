#!/usr/bin/env bash
set -euo pipefail
options="$1"

# Held to the lists of the Dart that runs it, the one whose analyzer reads the file.
version="$(dart --version 2>&1 | sed -nE 's/^Dart SDK version: ([^ ]+) .*/\1/p')"
if [[ -z ${version} ]]; then
  echo "::error::\`dart --version\` didn't say which Dart this is." >&2
  exit 1
fi
linter() {
  gh api --header 'Accept: application/vnd.github.raw' \
    "repos/dart-lang/sdk/contents/pkg/linter/$1?ref=${version}"
}
rules="$(linter tool/machine/rules.json)"
count="$(jq length <<< "${rules}")"
if [[ ${count} -eq 0 ]]; then
  echo "::error::Dart ${version}'s list of lints came back empty." >&2
  exit 1
fi
# rules.json can lag the analyzer on which lints are deprecated or removed, and messages.yaml, which
# the analyzer is built from, can't. It keys a lint by its name in camelCase, or by a shared one.
# shellcheck disable=SC2016  # a yq program, whose ${1} is a regex group
gone="$(linter messages.yaml | yq -o=json -I=0 '[.LinterLintCode | to_entries | .[]
  | select(.value.state != null)
  | {"name": ((.value.sharedName // .key) | sub("([A-Z]|[0-9]+)"; "_${1}") | downcase),
    "state": (.value.state | keys | .[-1])}
  | select(.state == "deprecated" or .state == "removed")]')"
dropped="$(jq length <<< "${gone}")"
if [[ ${dropped} -eq 0 ]]; then
  echo "::error::Dart ${version}'s messages.yaml has no deprecated or removed lints, so its layout" \
    "has likely changed." >&2
  exit 1
fi
decided="$(yq -o=json -I=0 '.linter.rules // {} | keys' "${options}")"

# shellcheck disable=SC2016  # a jq program, whose $name is a jq variable
undecided="$(jq -r --argjson decided "${decided}" --argjson gone "${gone}" '.[].name
  | select(. as $name | $decided + [$gone[].name] | any(. == $name) | not)' <<< "${rules}")"
# The analyzer only reports these in a package's own options, never in an included file, so the
# repos would never hear of them.
# shellcheck disable=SC2016  # a jq program, whose $name is a jq variable
stale="$(jq -r --argjson decided "${decided}" '.[]
  | select(.name as $name | $decided | any(. == $name)) | "\(.name) \(.state)"' <<< "${gone}")"
# The analyzer takes some old spellings without a word, so only the list catches them.
# shellcheck disable=SC2016  # a jq program, whose $known and $name are jq variables
unknown="$(jq -r --argjson decided "${decided}" '[.[].name] as $known
  | $decided[] | select(. as $name | $known | any(. == $name) | not)' <<< "${rules}")"

failed=false
while IFS= read -r name; do
  if [[ -z ${name} ]]; then continue; fi
  echo "::error::Dart ${version} has ${name}, which ${options} neither turns on nor off." >&2
  failed=true
done <<< "${undecided}"
while IFS=' ' read -r name state; do
  if [[ -z ${name} ]]; then continue; fi
  echo "::error::${name} is ${state} in Dart ${version}, so ${options} shouldn't name it at all." >&2
  failed=true
done <<< "${stale}"
while IFS= read -r name; do
  if [[ -z ${name} ]]; then continue; fi
  echo "::error::${name} isn't a lint Dart ${version} lists, so it's misspelled or an old name." >&2
  failed=true
done <<< "${unknown}"
if [[ ${failed} == true ]]; then exit 1; fi
echo "${options} decides every lint Dart ${version} has, and names none it has dropped."
