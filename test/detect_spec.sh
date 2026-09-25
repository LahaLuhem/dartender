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

  Describe 'a manifest that would lint nothing'
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
