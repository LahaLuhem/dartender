# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'detect.sh'
  # A throwaway repo whose lint manifest holds $1. No argument, no manifest.
  repo() {
    dir="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    mkdir "${dir}/.github"
    if [[ $# -gt 0 ]]; then printf '%s' "$1" > "${dir}/.github/lint-checks.json"; fi
    echo "${dir}"
  }

  It 'hands ci.yml the lint matrix and the image'
    r="$(repo '{"image":"linterpol:1","checks":[{"name":"ShellCheck","cmd":"shellcheck *.sh"}]}')"
    # No argument, the way the action calls it.
    cd "${r}" || return
    When run script "${SHELLSPEC_PROJECT_ROOT}/scripts/detect.sh"
    The line 1 of output should equal 'lint-checks=[{"name":"ShellCheck","cmd":"shellcheck *.sh"}]'
    The line 2 of output should equal 'lint-image=linterpol:1'
  End

  It 'reads the folder passed to it'
    r="$(repo '{"image":"linterpol:1","checks":[{"name":"a","cmd":"a"}]}')"
    here="$(repo)"
    cd "${here}" || return
    When run script "${SHELLSPEC_PROJECT_ROOT}/scripts/detect.sh" "${r}"
    The line 2 of output should equal 'lint-image=linterpol:1'
  End

  It 'lists what it found on the run summary page'
    r="$(repo '{"image":"linterpol:1","checks":[{"name":"ShellCheck","cmd":"a"},{"name":"rumdl","cmd":"b"}]}')"
    summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
    export GITHUB_STEP_SUMMARY="${summary}"
    expected="$(printf '%s\n' '### What dartender found' '| What | Found |' '|---|---|' \
      '| Package | none |' '| Example | none |' \
      '| Linters | ShellCheck, rumdl |' "| Lint image | \`linterpol:1\` |")"
    When run script scripts/detect.sh "${r}"
    The output should be present
    The contents of file "${summary}" should equal "${expected}"
  End

  Describe 'the package'
    Parameters
      'no package' '' 'package=false' 'flutter=false' 'none'
      'a pure Dart package' 'name: a' 'package=true' 'flutter=false' 'pure Dart'
      'a Flutter package' $'name: a\ndependencies:\n  flutter:\n    sdk: flutter' \
        'package=true' 'flutter=true' 'Flutter'
    End

    It "finds $1"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      if [[ -n "$2" ]]; then printf '%s\n' "$2" > "${r}/pubspec.yaml"; fi
      summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
      export GITHUB_STEP_SUMMARY="${summary}"
      When run script scripts/detect.sh "${r}"
      The line 3 of output should equal "$3"
      The line 4 of output should equal "$4"
      The contents of file "${summary}" should include "| Package | $5 |"
    End
  End

  Describe 'the example'
    Parameters
      'no example' '' 'example=false' 'example-tests=false' 'none'
      'an example without tests' 'example' 'example=true' 'example-tests=false' 'without tests'
      'an example with tests' 'example/test' 'example=true' 'example-tests=true' 'with tests'
    End

    It "finds $1"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      printf 'name: a\n' > "${r}/pubspec.yaml"
      if [[ -n "$2" ]]; then
        mkdir -p "${r}/$2"
        printf 'name: a_example\n' > "${r}/example/pubspec.yaml"
      fi
      summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
      export GITHUB_STEP_SUMMARY="${summary}"
      When run script scripts/detect.sh "${r}"
      The line 5 of output should equal "$3"
      The line 6 of output should equal "$4"
      The contents of file "${summary}" should include "| Example | $5 |"
    End
  End

  # Pure Dart packages often ship example/example.dart, which gets checked with the package itself.
  It 'ignores an example folder with no pubspec of its own'
    r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
    printf 'name: a\n' > "${r}/pubspec.yaml"
    mkdir -p "${r}/example/test"
    printf 'void main() {}\n' > "${r}/example/example.dart"
    When run script scripts/detect.sh "${r}"
    The line 5 of output should equal 'example=false'
    The line 6 of output should equal 'example-tests=false'
  End

  Describe 'a broken manifest'
    It 'fails when there is none'
      r="$(repo)"
      When run script scripts/detect.sh "${r}"
      The status should be failure
      The stderr should start with '::error::'
      The output should equal ''
    End

    Parameters
      'an empty file' ''
      'broken JSON' '{'
      'one without an image' '{"checks":[{"name":"a","cmd":"a"}]}'
      'one without checks' '{"image":"img"}'
      'an empty check list' '{"image":"img","checks":[]}'
      'a check without a name' '{"image":"img","checks":[{"cmd":"a"}]}'
      'a check without a command' '{"image":"img","checks":[{"name":"a"}]}'
      'a blank command' '{"image":"img","checks":[{"name":"a","cmd":" "}]}'
      'a later check without a command' '{"image":"img","checks":[{"name":"a","cmd":"a"},{"name":"b"}]}'
    End

    It "fails on $1"
      r="$(repo "$2")"
      When run script scripts/detect.sh "${r}"
      The status should be failure
      The stderr should start with '::error::'
      The output should equal ''
    End
  End
End
