# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/lint.sh'
  lint="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/lint.sh"

  # A bare package repo to run in, with the variables actions/lint sets.
  package() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
    export LINTERPOL_IMAGE=linterpol:1 LINT_CMD='shellcheck *.sh'
    export DEFAULTS="${SHELLSPEC_PROJECT_ROOT}/actions/lint/defaults"
  }

  # Stands in for the image, printing what it was asked to run, one argument per line.
  Mock docker
    printf '%s\n' "$@"
  End

  It 'runs the command in the image over a read-only mount, split into words, globs expanded'
    package
    touch a.sh b.sh
    expected="$(printf '%s\n' run --rm -v "${PWD}:/work:ro" linterpol:1 shellcheck a.sh b.sh)"
    When run script "${lint}"
    The output should equal "${expected}"
  End

  It 'fails the way the linter does'
    package
    Mock docker
      (exit 3)
    End
    When run script "${lint}"
    The status should equal 3
  End

  It 'lints with the shared configs when the repo brings none'
    package
    rumdl="$(cat "${DEFAULTS}/rumdl.toml")"
    yamllint="$(cat "${DEFAULTS}/yamllint.yaml")"
    When run script "${lint}"
    The output should be present
    The contents of file .rumdl.toml should equal "${rumdl}"
    The contents of file .yamllint.yaml should equal "${yamllint}"
  End

  It "keeps the repo's own configs"
    package
    echo own > .rumdl.toml
    echo own > .yamllint.yaml
    When run script "${lint}"
    The output should be present
    The contents of file .rumdl.toml should equal own
    The contents of file .yamllint.yaml should equal own
  End
End
