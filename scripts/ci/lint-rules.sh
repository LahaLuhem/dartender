#!/usr/bin/env bash
set -euo pipefail
options="$1"

# Held to the list of the Dart that runs it, the one whose analyzer reads the file.
version="$(dart --version 2>&1 | sed -nE 's/^Dart SDK version: ([^ ]+) .*/\1/p')"
if [[ -z ${version} ]]; then
  echo "::error::\`dart --version\` didn't say which Dart this is." >&2
  exit 1
fi
rules="$(gh api --header 'Accept: application/vnd.github.raw' \
  "repos/dart-lang/sdk/contents/pkg/linter/tool/machine/rules.json?ref=${version}")"
count="$(jq length <<< "${rules}")"
if [[ ${count} -eq 0 ]]; then
  echo "::error::Dart ${version}'s list of lints came back empty." >&2
  exit 1
fi
decided="$(yq -o=json -I=0 '.linter.rules // {} | keys' "${options}")"

# The analyzer warns about a deprecated or removed lint turned on, so neither needs a decision.
# shellcheck disable=SC2016  # a jq program, whose $name is a jq variable
undecided="$(jq -r --argjson decided "${decided}" '.[]
  | select(.state == "stable" or .state == "experimental") | .name
  | select(. as $name | $decided | any(. == $name) | not)' <<< "${rules}")"
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
while IFS= read -r name; do
  if [[ -z ${name} ]]; then continue; fi
  echo "::error::${name} isn't a lint Dart ${version} lists, so it's misspelled or an old name." >&2
  failed=true
done <<< "${unknown}"
if [[ ${failed} == true ]]; then exit 1; fi
echo "${options} turns every lint Dart ${version} lists on or off."
