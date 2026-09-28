#!/usr/bin/env bash
# What setup.sh runs in its container: the repo's callers, dependabot.yml and GitHub settings.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/common.sh"

usage() {
  error "Usage: setup.sh [-y] [--check <local gate>]..."
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

# What the repo's ci caller passes for the input $1 now, or else ci.yml's own default for it.
caller_value() {
  local caller=.github/workflows/ci.yml
  export INPUT="$1"
  if [[ -f ${caller} ]] \
    && yq -e '(.jobs.ci.with // {}) | has(strenv(INPUT))' "${caller}" > /dev/null; then
    yq '.jobs.ci.with[strenv(INPUT)]' "${caller}"
  else
    yq '.on.workflow_call.inputs[strenv(INPUT)].default' "${here}/../../.github/workflows/ci.yml"
  fi
}

yes=false
if [[ ${1-} == -y ]]; then
  yes=true
  shift
fi
parse_checks "$@"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
info "Setting up ${repo}"
# Before dependabot.yml, which then covers them.
ask "Write the callers in .github/workflows?"
if [[ ${answer} == true ]]; then
  coveralls="$(caller_value coveralls)"
  ask "Upload coverage to Coveralls?" "${coveralls}"
  coveralls="${answer}"
  min_coverage="$(caller_value min-coverage)"
  ask_for "Lowest line coverage that passes, in percent" "${min_coverage}"
  min_coverage="${answer}"
  # Neither gum nor mason checks it's a number.
  if [[ ! ${min_coverage} =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    error "Invalid input: the lowest coverage has to be a number, not '${min_coverage}'."
    exit 1
  fi
  coverage_excludes="$(caller_value coverage-excludes)"
  ask_for "Globs to leave out of coverage besides generated code, space-separated" \
    "${coverage_excludes}"
  coverage_excludes="${answer}"
  "${here}/callers.sh" "${coveralls}" "${min_coverage}" "${coverage_excludes}"
else
  info "Left the callers in .github/workflows as they are"
fi
ask "Write .github/dependabot.yml?"
if [[ ${answer} == true ]]; then
  "${here}/dependabot.sh"
else
  info "Left .github/dependabot.yml as it is"
fi
ask "Set the ruleset, sem-* labels and merge settings on GitHub?"
if [[ ${answer} == true ]]; then
  "${here}/apply.sh" "${repo}" "$@"
else
  info "Left the settings on GitHub as they are"
fi
success "Done with ${repo}"
