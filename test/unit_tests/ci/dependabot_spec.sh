# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/dependabot.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/dependabot.sh"

  # A throwaway package folder whose .github/$2, dependabot.yml by default, holds $1.
  package() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/package.XXXXXX")"
    mkdir "${dir}/.github"
    if [[ $# -gt 0 ]]; then printf '%s\n' "$1" > "${dir}/.github/${2:-dependabot.yml}"; fi
    echo "${dir}"
  }

  It 'passes when a block watches each pair'
    p="$(package '{"version": 2, "updates": [
      {"package-ecosystem": "pub", "directory": "/"},
      {"package-ecosystem": "gradle", "directory": "/example/android"}]}')"
    export PAIRS='[{"package-ecosystem": "pub", "directory": "/"},
      {"package-ecosystem": "gradle", "directory": "/example/android"}]'
    When run script "${script}" "${p}"
    The status should be success
  End

  It 'names each pair that no block for its ecosystem and folder watches'
    p="$(package '{"version": 2, "updates": [{"package-ecosystem": "pub", "directory": "/"}]}')"
    export PAIRS='[{"package-ecosystem": "pub", "directory": "/"},
      {"package-ecosystem": "gradle", "directory": "/"},
      {"package-ecosystem": "pub", "directory": "/example"}]'
    When run script "${script}" "${p}"
    The status should be failure
    The output should include 'watches gradle in /.'
    The output should include 'watches pub in /example.'
    The output should not include 'watches pub in /.'
  End

  It 'names every pair when there is no dependabot.yml'
    p="$(package)"
    export PAIRS='[{"package-ecosystem": "pub", "directory": "/"}]'
    When run script "${script}" "${p}"
    The status should be failure
    The output should include 'watches pub in /.'
  End

  It 'reads a dependabot.yaml too'
    p="$(package '{"version": 2, "updates": [{"package-ecosystem": "pub", "directory": "/"}]}' \
      dependabot.yaml)"
    export PAIRS='[{"package-ecosystem": "pub", "directory": "/"}]'
    When run script "${script}" "${p}"
    The status should be success
  End

  # With a block that has $1, and the folder $2 there to match a glob.
  block() {
    p="$(package "{\"version\": 2, \"updates\": [{\"package-ecosystem\": \"pub\", $1}]}")"
    mkdir -p "${p}/$2"
    export PAIRS="[{\"package-ecosystem\": \"pub\", \"directory\": \"/$2\"}]"
  }

  # The way Dependabot reads them, matching globs against the folders there.
  Describe 'the folders a block covers'
    Parameters
      'example' '"directories": ["/example"]'
      'example' '"directories": ["/example/"]'
      'actions/a' '"directories": ["/actions/*"]'
      'example' '"directories": ["example"]'
      '.tool' '"directories": ["/*"]'
      'lib-one' '"directories": ["/lib-*"]'
    End

    It "counts $2 as watching /$1"
      block "$2" "$1"
      When run script "${script}" "${p}"
      The status should be success
    End
  End

  Describe 'the folders a block leaves out'
    Parameters
      'actions/a/b' '"directories": ["/actions/*"]'
      'actions/a' '"directory": "/actions/*"'
    End

    It "doesn't count $2 as watching /$1"
      block "$2" "$1"
      When run script "${script}" "${p}"
      The status should be failure
      The output should include "watches pub in /$1."
    End
  End
End
