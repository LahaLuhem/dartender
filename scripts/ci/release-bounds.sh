#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
name="$1" next="$2"

# Whether the first version in $a sorts below $b, which for a constraint is its lower bound.
# shellcheck disable=SC2016  # a jq program, whose $a and $b are jq variables
below='[$a, $b | [scan("[0-9]+") | tonumber] + [0, 0, 0] | .[:3]] | .[0] < .[1]'

packages="$("${here}/packages.sh")"
names=()
declare -A folders=()
while IFS=$'\t' read -r package dir _; do
  names+=("${package}")
  folders["${package}"]="${dir}"
done <<< "${packages}"

# pub.dev keeps a published bound for good, and one below a sibling's major pairs this release with
# a version of it the repo never built against.
own="${folders[${name}]}/pubspec.yaml"
stale=false
for sibling in "${names[@]}"; do
  version="$(yq '.version // ""' "${folders[${sibling}]}/pubspec.yaml")"
  bound="$(NAME="${sibling}" yq '.dependencies[strenv(NAME)] | select(tag == "!!str")' "${own}")"
  if [[ -z ${version} || ${bound} != *[0-9]* ]]; then continue; fi
  lags="$(jq -rn --arg a "${bound}" --arg b "${version%%.*}.0.0" "${below}")"
  if [[ ${lags} == true ]]; then
    echo "::error::${name} wants ${sibling} ${bound}, but this repo builds against ${sibling}" \
      "${version%%.*}.x, so that lower bound needs raising first." >&2
    stale=true
  fi
done
if [[ ${stale} == true ]]; then exit 1; fi

# Raised on every release, so no bound promises less than the repo was built against, and a major
# can't stop the workspace resolving.
for package in "${names[@]}"; do
  file="${folders[${package}]}/pubspec.yaml"
  bound="$(NAME="${name}" yq '(.dependencies, .dev_dependencies) | .[strenv(NAME)]
    | select(tag == "!!str")' "${file}")"
  if [[ ${bound} != *[0-9]* ]]; then continue; fi
  lags="$(jq -rn --arg a "${bound}" --arg b "${next}" "${below}")"
  if [[ ${lags} != true ]]; then continue; fi
  # Found as text and rewritten alone: yq's line numbers skip a file's opening comments, and its
  # round trip reflows the whole file.
  mapfile -t lines < "${file}"
  at=()
  for i in "${!lines[@]}"; do
    if [[ ${lines[i]} =~ ^"  ${name}:"([[:space:]]|$) ]]; then at+=("${i}"); fi
  done
  if [[ ${#at[@]} -ne 1 ]]; then
    echo "::error::${file#./} has ${#at[@]} lines that start '  ${name}:', so it's unclear which" \
      "bound to raise." >&2
    exit 1
  fi
  lines[at[0]]="  ${name}: ^${next}"
  printf '%s\n' "${lines[@]}" > "${file}"
  echo "${file#./}: ${name} ${bound} raised to ^${next}"
done
