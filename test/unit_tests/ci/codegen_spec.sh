# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/codegen.sh'
  codegen="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/codegen.sh"

  package() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    mkdir -p "${repo}/.github"
    printf '%s' "$1" > "${repo}/.github/codegen.json"
    cd "${repo}" || return
  }

  Mock gen
    printf '%s in %s\n' "$*" "${PWD##*/}"
  End

  It 'runs a step where it says, and the rest at the root'
    package '{"steps":[{"name":"Root","cmd":"gen one"},
      {"name":"Example","folder":"example","cmd":"gen two"}]}'
    mkdir example
    When run script "${codegen}"
    The output should include "one in ${PWD##*/}"
    The output should include 'two in example'
  End

  It 'splits a command into words and expands its globs'
    package '{"steps":[{"name":"Root","cmd":"gen *.dart"}]}'
    touch a.dart b.dart
    When run script "${codegen}"
    The output should include "a.dart b.dart in ${PWD##*/}"
  End

  It 'names each step in the log, so a failure says which one'
    package '{"steps":[{"name":"Pigeon","cmd":"gen one"}]}'
    When run script "${codegen}"
    The output should include '::group::Pigeon'
  End

  It 'stops at the first step that fails, with its status'
    package '{"steps":[{"name":"First","cmd":"gen one"},{"name":"Second","cmd":"gen two"}]}'
    Mock gen
      printf '%s\n' "$*"
      [[ $1 == one ]] && exit 3
    End
    When run script "${codegen}"
    The status should equal 3
    The output should not include two
  End

  It 'fails when the step names a folder the repo does not have'
    package '{"steps":[{"name":"Gone","folder":"nope","cmd":"gen one"}]}'
    When run script "${codegen}"
    The status should be failure
    # It got as far as the step, so the folder is what stopped it.
    The output should include '::group::Gone'
    The stderr should be present
  End
End
