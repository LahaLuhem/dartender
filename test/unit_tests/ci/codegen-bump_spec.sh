# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/codegen-bump.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/codegen-bump.sh"

  setup() {
    checkout="$(mktemp -d "${SHELLSPEC_TMPBASE}/bump.XXXXXX")"
    # Resolved, since the stand-in records where pub ran from.
    checkout="$(cd "${checkout}" && pwd -P)"
    mkdir -p "${checkout}/example"
    cd "${checkout}" || return
  }
  BeforeEach 'setup'

  bumps() {
    sed "s|^${checkout}|.|" "${ADDED}"
  }

  It 'moves a pinned generator up to its newest, pinned exactly again'
    export GENERATORS='[{"directory":"/","packages":["pigeon"]}]'
    pub_outdated pigeon:dev:29.2.0
    When run script "${script}"
    The status should be success
    The output should include 'Generators bumped: 1.'
    The result of function bumps should equal '. pub add dev:pigeon:29.2.0'
  End

  It 'leaves one that is already newest alone, since pub outdated leaves it out'
    export GENERATORS='[{"directory":"/","packages":["pigeon"]}]'
    pub_outdated
    When run script "${script}"
    The status should be success
    The output should include 'Generators bumped: 0.'
    The result of function bumps should be blank
  End

  It "leaves a dev dependency alone that the repo hasn't pinned, since it stays Dependabot's"
    export GENERATORS='[{"directory":"/","packages":["pigeon"]}]'
    pub_outdated build_runner:dev:2.18.0
    When run script "${script}"
    The status should be success
    The result of function bumps should be blank
  End

  It 'leaves a regular dependency of the same name alone'
    export GENERATORS='[{"directory":"/","packages":["pigeon"]}]'
    pub_outdated pigeon:direct:29.2.0
    When run script "${script}"
    The status should be success
    The result of function bumps should be blank
  End

  It "bumps each folder's own, in that folder"
    export GENERATORS='[{"directory":"/","packages":["pigeon"]},
      {"directory":"/example","packages":["flutter_gen_runner"]}]'
    pub_outdated pigeon:dev:29.2.0 flutter_gen_runner:dev:5.16.0
    expected="$(printf '%s\n' '. pub add dev:pigeon:29.2.0' \
      './example pub add dev:flutter_gen_runner:5.16.0')"
    When run script "${script}"
    The status should be success
    The output should include 'Generators bumped: 2.'
    The result of function bumps should equal "${expected}"
  End

  It 'does nothing in a repo that pins none'
    export GENERATORS='[]'
    pub_outdated
    When run script "${script}"
    The status should be success
    The output should include 'Generators bumped: 0.'
    The result of function bumps should be blank
  End

  It 'stops when pub cannot say what is outdated, rather than reporting nothing to do'
    export GENERATORS='[{"directory":"/","packages":["pigeon"]}]'
    pub_fails 'Could not resolve.'
    When run script "${script}"
    The status should be failure
    The stderr should be present
    The output should not include 'Generators bumped'
  End
End
