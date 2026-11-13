#!/usr/bin/env bash
set -euo pipefail
cd "${1:-.}"

manifest=.github/lint-checks.json
# No checks, or a check with no command, would lint nothing and still pass.
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

# By convention a repo's one Python project, its benchmarks', lives here with its tests.
python=false
if [[ -d benchmark/python ]]; then
  if [[ ! -d benchmark/python/tests ]]; then
    echo "::error::Convention not followed: benchmark/python needs a tests folder." >&2
    exit 1
  fi
  python=true
fi
echo "python=${python}"

# Optional: a repo with nothing to generate has no manifest.
codegen=false
codegen_manifest=.github/codegen.json
if [[ -f ${codegen_manifest} ]]; then
  valid='(.steps | length > 0) and all(.steps[];
    (.name | type == "string" and length > 0) and (.cmd | type == "string" and test("\\S"))
    and ((.folder // ".") | type == "string" and test("\\S")))'
  if ! jq -e "${valid}" "${codegen_manifest}" >/dev/null 2>&1; then
    echo "::error::${codegen_manifest} is malformed or empty. It needs at least one step," \
      "each with a \"name\" and a \"cmd\", and an optional \"folder\"." >&2
    exit 1
  fi
  codegen=true
fi
echo "codegen=${codegen}"

# New files count too, so setup.sh's dependabot.yml covers the callers written in the same run.
files="$(git ls-files --cached --others --exclude-standard)"
watched='' pinned=''
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
    # pub only updates a workspace from its root, which covers the members.
    */pubspec.yaml)
      resolution="$(yq '.resolution // ""' "${file}")"
      if [[ "${resolution}" != workspace ]]; then ecosystem=pub; fi
      # An exact pin is how a repo marks a generator, so the codegen job owns its bumps.
      exact="$(yq -o json '.dev_dependencies // {}' "${file}" | jq -r --arg dir "${dir:-/}" \
        'to_entries[] | select((.value | type) == "string"
          and (.value | test("^[0-9]+\\.[0-9]+\\.[0-9]+([-+][0-9A-Za-z.+-]+)?$")))
        | "\($dir)\t\(.key)"')"
      if [[ -n "${exact}" ]]; then pinned+="${exact}"$'\n'; fi
      ;;
    */settings.gradle | */settings.gradle.kts) ecosystem=gradle ;;
    */uv.lock) ecosystem=uv ;;
    # Xcode's pins only: Dependabot can't resolve a plugin's Package.swift without Flutter's build.
    */*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
      ecosystem=swift dir="${dir%/*.xcodeproj/*}"
      ;;
    */*.xcworkspace/xcshareddata/swiftpm/Package.resolved)
      ecosystem=swift dir="${dir%/*.xcworkspace/*}"
      ;;
    # Only composite actions have `uses:` lines to bump.
    */action.yml | */action.yaml)
      using="$(yq .runs.using "${file}")"
      if [[ "${using}" == composite ]]; then ecosystem=github-actions; fi
      ;;
    *) ;;
  esac
  if [[ -n "${ecosystem}" ]]; then watched+="${ecosystem}"$'\t'"${dir:-/}"$'\n'; fi
done <<< "${files}"
dependabot="$(jq -R -n -c '[inputs | select(. != "")] | unique
  | map(split("\t") | {"package-ecosystem": .[0], directory: .[1]})' <<< "${watched}")"
echo "dependabot=${dependabot}"

# A workspace member has no block of its own, so its pins go to the nearest one above it.
blocks="$(jq -r '.[] | select(."package-ecosystem" == "pub") | .directory' <<< "${dependabot}")"
owned=''
while IFS=$'\t' read -r pin_dir pin; do
  if [[ -z "${pin}" ]]; then continue; fi
  best=''
  while IFS= read -r block; do
    if [[ -z "${block}" ]]; then continue; fi
    if [[ "${pin_dir}" != "${block}" && "${pin_dir}" != "${block%/}/"* ]]; then continue; fi
    if [[ ${#block} -gt ${#best} ]]; then best="${block}"; fi
  done <<< "${blocks}"
  if [[ -n "${best}" ]]; then owned+="${best}"$'\t'"${pin}"$'\n'; fi
done <<< "${pinned}"
generators="$(jq -R -n -c '[inputs | select(. != "") | split("\t")]
  | group_by(.[0]) | map({directory: .[0][0], packages: (map(.[1]) | unique)})' <<< "${owned}")"
echo "generators=${generators}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  names="$(jq -r '[.[].name] | join(", ")' <<< "${checks}")"
  watching="$(jq -r 'map("`\(."package-ecosystem") \(.directory)`") | join(", ")' \
    <<< "${dependabot}")"
  kind=none
  if [[ "${flutter}" == true ]]; then kind=Flutter; elif [[ "${package}" == true ]]; then kind="pure Dart"; fi
  shown=none
  if [[ "${example_tests}" == true ]]; then shown="with tests"; elif [[ "${example}" == true ]]; then shown="without tests"; fi
  python_shown=none
  if [[ "${python}" == true ]]; then python_shown="\`benchmark/python\`"; fi
  codegen_shown=none
  if [[ "${codegen}" == true ]]; then
    codegen_shown="$(jq -r '[.steps[].name] | join(", ")' "${codegen_manifest}")"
  fi
  cat >> "${GITHUB_STEP_SUMMARY}" <<EOF
### What dartender found
| What | Found |
|---|---|
| Package | ${kind} |
| Example | ${shown} |
| Python | ${python_shown} |
| Codegen | ${codegen_shown} |
| Linters | ${names} |
| Lint image | \`${image}\` |
| Dependabot | ${watching:-none} |
EOF
fi
