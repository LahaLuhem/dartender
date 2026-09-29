#!/usr/bin/env bash
# What setup.sh runs in its container: the repo's callers, dependabot.yml and GitHub settings.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: setup.sh [-y]"
  exit 2
}

# Sets answer to true or false, with $2 as the default (true when left out) that -y takes. A plain
# call rather than an if condition, so set -e holds inside it.
ask() {
  answer="${2:-true}"
  if [[ ${yes} == true ]]; then return; fi
  local rc=0
  gum confirm --default="${answer}" "$1" || rc=$?
  # gum exits 0 for yes and 1 for no, so anything else, like 130 for ctrl+c, stops the setup.
  if [[ ${rc} -gt 1 ]]; then exit "${rc}"; fi
  answer=true
  if [[ ${rc} -eq 1 ]]; then answer=false; fi
}

# Sets answer to what gets typed for $1, starting from $2, which -y takes as it is.
ask_for() {
  answer="$2"
  if [[ ${yes} == true ]]; then return; fi
  answer="$(gum input --header "$1" --value "$2")"
}

# Like ask_for, but stops at anything that isn't a number, calling it $3 in the error.
ask_number() {
  ask_for "$1" "$2"
  # Neither gum nor mason checks it's a number.
  if [[ ! ${answer} =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    error "Invalid input: $3 has to be a number, not '${answer}'."
    exit 1
  fi
}

# What the repo's ci caller passes for the input $1 now, or else ci.yml's own default for it.
caller_value() {
  local caller=.github/workflows/ci.yml has=false
  export INPUT="$1"
  # Not yq -e, which prints "Error: no matches found" for a caller without the input.
  if [[ -f ${caller} ]]; then
    has="$(yq '(.jobs.ci.with // {}) | has(strenv(INPUT))' "${caller}")"
  fi
  if [[ ${has} == true ]]; then
    yq '.jobs.ci.with[strenv(INPUT)]' "${caller}"
  else
    yq '.on.workflow_call.inputs[strenv(INPUT)].default' "${here}/../../.github/workflows/ci.yml"
  fi
}

# The scripts the repo's lint-checks.json has ShellCheck check now. A repo without one yet gets
# scripts/*.sh when that finds any, since ShellCheck fails on a glob that finds nothing.
shellcheck_paths() {
  local manifest=.github/lint-checks.json
  if [[ -f ${manifest} ]]; then
    jq -r '.checks[] | select(.name == "ShellCheck") | .cmd | sub("^shellcheck\\s*"; "")' \
      "${manifest}"
  elif compgen -G 'scripts/*.sh' > /dev/null; then
    echo 'scripts/*.sh'
  fi
}

yes=false
if [[ ${1-} == -y ]]; then
  yes=true
  shift
fi
[[ $# -eq 0 ]] || usage
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
info "Setting up ${repo}"
# Before dependabot.sh, which then watches the callers and stops without a lint-checks.json.
ask "Write the callers and lint-checks.json in .github?"
if [[ ${answer} == true ]]; then
  coveralls="$(caller_value coveralls)"
  ask "Upload coverage to Coveralls?" "${coveralls}"
  coveralls="${answer}"
  min_coverage="$(caller_value min-coverage)"
  ask_number "Lowest line coverage that passes, in percent" "${min_coverage}" \
    "the lowest coverage"
  min_coverage="${answer}"
  coverage_excludes="$(caller_value coverage-excludes)"
  ask_for "Globs to leave out of coverage besides generated code, space-separated" \
    "${coverage_excludes}"
  coverage_excludes="${answer}"
  python_min_coverage="$(caller_value python-min-coverage)"
  ask_number "Lowest coverage for benchmark/python's tests, in percent, 0 for none" \
    "${python_min_coverage}" "the lowest Python coverage"
  python_min_coverage="${answer}"
  shellcheck="$(shellcheck_paths)"
  ask_for "Shell scripts for ShellCheck, space-separated globs, blank for none" "${shellcheck}"
  shellcheck="${answer}"
  "${here}/callers.sh" "${coveralls}" "${min_coverage}" "${coverage_excludes}" \
    "${python_min_coverage}" "${shellcheck}"
else
  info "Left the callers and lint-checks.json in .github as they are"
fi
ask "Write .github/dependabot.yml?"
if [[ ${answer} == true ]]; then
  "${here}/dependabot.sh"
else
  info "Left .github/dependabot.yml as it is"
fi
ask "Set the ruleset, sem-* labels and merge settings on GitHub?"
if [[ ${answer} == true ]]; then
  "${here}/apply.sh" "${repo}"
else
  info "Left the settings on GitHub as they are"
fi
success "Done with ${repo}"
