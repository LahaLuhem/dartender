#!/usr/bin/env bash
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: callers.sh <coveralls> <min-coverage> <coverage-excludes> <python-min-coverage>" \
    "<shellcheck-paths> [folder]"
  exit 2
}

[[ $# -ge 5 && $# -le 6 ]] || usage
coveralls="$1" min_coverage="$2" coverage_excludes="$3" python_min_coverage="$4"
shellcheck_paths="$5" repo="${6:-.}"
branch="$(git -C "${repo}" symbolic-ref --short refs/remotes/origin/HEAD)"
branch="${branch#origin/}"
# mason renders a section even for an empty string, so the brick switches these on booleans.
shellcheck=false
if [[ ${shellcheck_paths} == *[![:space:]]* ]]; then shellcheck=true; fi
python=false
if [[ -n ${python_min_coverage} ]]; then python=true; fi
# The release caller asks which package only where more than one publishes, as their tags name it.
listed="$("${here}/../ci/packages.sh" "${repo}")"
published=()
while IFS=$'\t' read -r name _ publishes; do
  if [[ ${publishes} == true ]]; then published+=("${name}"); fi
done <<< "${listed}"
workspace=false
if [[ ${#published[@]} -gt 1 ]]; then workspace=true; fi
# mason takes a list as JSON.
# shellcheck disable=SC2016  # a jq program, whose $ARGS is a jq variable
packages="$(jq -cn '$ARGS.positional' --args "${published[@]}")"

# Global, so mason leaves no mason.yaml in the repo.
mason add -g callers --path "${here}/../../bricks/callers" > /dev/null
rc=0
out="$(mason make callers --output-dir "${repo}" --on-conflict overwrite --set-exit-if-changed \
  --shellcheck "${shellcheck}" --shellcheck_paths "${shellcheck_paths}" --python "${python}" \
  --workspace "${workspace}" --packages "${packages}" \
  --default_branch "${branch}" --coveralls "${coveralls}" --min_coverage "${min_coverage}" \
  --coverage_excludes "${coverage_excludes}" --python_min_coverage "${python_min_coverage}" \
  2>&1)" || rc=$?
case "${rc}" in
  0) success "The callers and lint-checks.json in ${repo}/.github are already up to date" ;;
  # What --set-exit-if-changed exits with when it changed a file.
  70) success "Wrote the callers and lint-checks.json in ${repo}/.github" ;;
  *)
    error "mason couldn't write the callers and lint-checks.json: ${out}"
    exit "${rc}"
    ;;
esac
