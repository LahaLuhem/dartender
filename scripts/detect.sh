#!/usr/bin/env bash
# Prints what ci.yml needs to know about a package, as key=value lines for $GITHUB_OUTPUT.
set -euo pipefail
cd "${1:-.}"

manifest=.github/lint-checks.json
# No checks, or a check with no command, would lint nothing and still pass, so both fail here.
valid='.image and (.checks | length > 0) and all(.checks[];
  (.name | type == "string" and length > 0) and (.cmd | type == "string" and test("\\S")))'
if ! jq -e "${valid}" "${manifest}" >/dev/null 2>&1; then
  echo "::error::${manifest} is missing, malformed or empty." \
    "It needs an \"image\" and at least one check, each with a \"name\" and a \"cmd\"." >&2
  exit 1
fi
checks="$(jq -c .checks "${manifest}")"
image="$(jq -r .image "${manifest}")"
echo "lint-checks=${checks}"
echo "lint-image=${image}"

package=false flutter=false example=false example_tests=false
if [[ -f pubspec.yaml ]]; then
  package=true
  sdk="$(yq '.dependencies.flutter.sdk // ""' pubspec.yaml)"
  if [[ "${sdk}" == flutter ]]; then flutter=true; fi
  if [[ -f example/pubspec.yaml ]]; then
    example=true
    if [[ -d example/test ]]; then example_tests=true; fi
  fi
fi
echo "package=${package}"
echo "flutter=${flutter}"
echo "example=${example}"
echo "example-tests=${example_tests}"

# New files count too, so setup.sh's dependabot.yml covers the callers written in the same run.
files="$(git ls-files --cached --others --exclude-standard)"
watched='' projects=''
while IFS= read -r file; do
  # --cached still lists a file that's deleted but not committed yet.
  if [[ ! -e "${file}" ]]; then continue; fi
  path="/${file}"
  dir="${path%/*}"
  ecosystem=''
  case "${path}" in
    # Test fixtures, not real dependencies.
    */test/*) ;;
    /.github/workflows/*.yml | /.github/workflows/*.yaml) ecosystem=github-actions dir=/ ;;
    */pubspec.yaml) ecosystem=pub ;;
    */settings.gradle | */settings.gradle.kts) ecosystem=gradle ;;
    */uv.lock) ecosystem=uv ;;
    */Package.swift) ecosystem=swift ;;
    # Only composite actions have `uses:` lines to bump.
    */action.yml | */action.yaml)
      using="$(yq .runs.using "${file}")"
      if [[ "${using}" == composite ]]; then ecosystem=github-actions; fi
      ;;
    *) ;;
  esac
  if [[ -n "${ecosystem}" ]]; then watched+="${ecosystem}"$'\t'"${dir:-/}"$'\n'; fi
  if [[ "${ecosystem}" == uv ]]; then
    project="${dir#/}"
    project="${project:-.}"
    # A project with no tests may not have pytest at all, so only one with tests gets Pytest.
    tests=false
    if [[ -d "${project}/tests" ]]; then tests=true; fi
    projects+="${project}"$'\t'"${tests}"$'\n'
  fi
done <<< "${files}"
dependabot="$(jq -R -n -c '[inputs | select(. != "")] | unique
  | map(split("\t") | {"package-ecosystem": .[0], directory: .[1]})' <<< "${watched}")"
echo "dependabot=${dependabot}"
python="$(jq -R -n -c '[inputs | select(. != "") | split("\t")
  | {directory: .[0], tests: (.[1] == "true")}]' <<< "${projects}")"
echo "python=${python}"

# Only Actions has a summary page, so a run anywhere else skips it.
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  names="$(jq -r '[.[].name] | join(", ")' <<< "${checks}")"
  watching="$(jq -r 'map("`\(."package-ecosystem") \(.directory)`") | join(", ")' \
    <<< "${dependabot}")"
  kind=none
  if [[ "${flutter}" == true ]]; then kind=Flutter; elif [[ "${package}" == true ]]; then kind="pure Dart"; fi
  shown=none
  if [[ "${example_tests}" == true ]]; then shown="with tests"; elif [[ "${example}" == true ]]; then shown="without tests"; fi
  pythons="$(jq -r 'map("`\(.directory)` \(if .tests then "with" else "without" end) tests")
    | join(", ")' <<< "${python}")"
  cat >> "${GITHUB_STEP_SUMMARY}" <<EOF
### What dartender found
| What | Found |
|---|---|
| Package | ${kind} |
| Example | ${shown} |
| Python | ${pythons:-none} |
| Linters | ${names} |
| Lint image | \`${image}\` |
| Dependabot | ${watching:-none} |
EOF
fi
