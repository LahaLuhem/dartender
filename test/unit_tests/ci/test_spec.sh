# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/pub.sh

Describe 'ci/test.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/test.sh"

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
    export FLUTTER=false MIN_COVERAGE=95 EXCLUDES='**/*.g.dart lib/gen/**'
  }
  BeforeEach 'setup'

  package() {
    local name="$1" dir="$2" folder
    shift 2
    mkdir -p "${dir}"
    printf 'name: %s\n' "${name}" > "${dir}/pubspec.yaml"
    for folder in "$@"; do mkdir -p "${dir}/${folder}"; done
  }

  command_with() {
    if [[ ${FLUTTER} == true ]]; then
      printf '%s\n' test
    else
      printf '%s\n' dart test --check-ignore
    fi
    printf '%s\n' --coverage --min-coverage 95 --exclude-coverage '**/*.g.dart lib/gen/**' \
      --collect-coverage-from imports --no-optimization "$@"
  }

  Mock very_good
    # Like the real one, it skips the run as a pass when its folder has no test folder.
    if [[ -d test ]]; then printf '%s\n' "$@"; else echo 'No test folder found in .'; fi
  End

  It 'tests a single package from its root, reporting on its lib'
    package a . lib test
    pub_lists a:.
    expected="$(command_with --report-on=lib test)"
    When run script "${script}"
    The output should equal "${expected}"
  End

  It "tests a workspace's packages in one run, reporting on each lib there is"
    package w . test
    package a packages/a lib test
    package b packages/b lib
    package c packages/c test
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    expected="$(command_with test --report-on=packages/a/lib packages/a/test \
      --report-on=packages/b/lib packages/c/test)"
    When run script "${script}"
    The output should equal "${expected}"
  End

  It 'tests a workspace whose root has no test folder of its own'
    package w .
    package a packages/a lib test
    package b packages/b lib test
    pub_lists w:. a:packages/a b:packages/b
    expected="$(command_with --report-on=packages/a/lib packages/a/test \
      --report-on=packages/b/lib packages/b/test)"
    When run script "${script}"
    The output should equal "${expected}"
  End

  It "runs very_good's Flutter command for a Flutter package"
    package a . lib test
    pub_lists a:.
    export FLUTTER=true
    expected="$(command_with --report-on=lib test)"
    When run script "${script}"
    The output should equal "${expected}"
  End

  It 'fails the way the coverage gate does'
    package a . lib test
    pub_lists a:.
    Mock very_good
      (exit 69)
    End
    When run script "${script}"
    The status should equal 69
  End

  It "fails without testing anything when the packages can't be listed"
    package a . lib test
    pub_fails 'Error on line 1 of packages/b/pubspec.yaml'
    When run script "${script}"
    The status should be failure
    The output should equal ''
    The error should equal 'Error on line 1 of packages/b/pubspec.yaml'
  End
End
