# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/check-inputs.sh'
  check_inputs="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/check-inputs.sh"

  # A package repo to check, and a folder the stand-in for GitHub below serves other repos from.
  package() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    export REMOTE="${repo}.remote"
    mkdir -p "${repo}/.github/workflows" "${REMOTE}"
    cd "${repo}" || return
  }

  # Saves $4 as the file $2 of the remote repo $1, at ref $3.
  remote() {
    local file="${REMOTE}/$1/$3/$2"
    mkdir -p "${file%/*}"
    printf '%s\n' "$4" > "${file}"
  }

  # A workflow whose one step uses $1 and passes it the keys after that. The second key is line 9.
  step() {
    local key
    printf 'on: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n' > .github/workflows/ci.yml
    printf '      - uses: %s\n        with:\n' "$1" >> .github/workflows/ci.yml
    shift
    for key; do printf '          %s: x\n' "${key}" >> .github/workflows/ci.yml; done
  }

  # A workflow whose one job calls the reusable workflow $1 with the keys after that.
  job() {
    local key
    printf 'on: push\njobs:\n  a:\n    uses: %s\n    with:\n' "$1" > .github/workflows/ci.yml
    shift
    for key; do printf '      %s: x\n' "${key}" >> .github/workflows/ci.yml; done
  }

  # Stands in for `gh api repos/<owner>/<repo>/contents/<path>?ref=<ref>`, serving the raw file
  # from ${REMOTE}/<owner>/<repo>/<ref>/<path>.
  Mock gh
    for arg; do
      case "${arg}" in repos/*) url="${arg#repos/}" ;; *) ;; esac
    done
    ref="${url##*\?ref=}"
    url="${url%\?ref=*}"
    # Like the real one, a miss prints the error body to stdout and fails.
    cat "${REMOTE}/${url%%/contents/*}/${ref}/${url#*/contents/}" 2>/dev/null ||
      { echo '{"message":"Not Found","status":"404"}'; false; }
  End

  It 'passes a declared input'
    package
    remote acme/tool action.yml v1 $'inputs:\n  name: {}'
    step acme/tool@v1 name
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  It 'fails on an undeclared input, naming it, its line and what the action takes'
    package
    remote acme/tool action.yml v1 $'inputs:\n  name: {}'
    step acme/tool@v1 name nmae
    expected="::error file=.github/workflows/ci.yml,line=9::\"nmae\" isn't an input of acme/tool@v1."
    When run script "${check_inputs}"
    The status should be failure
    The line 1 of output should equal "${expected} It takes: name."
    The line 2 of output should equal 'Calls checked: 1.'
  End

  It 'falls back to action.yaml'
    package
    remote acme/tool action.yaml v1 $'inputs:\n  name: {}'
    step acme/tool@v1 name
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  It 'reads an action from a folder inside its repo'
    package
    remote acme/kit setup/action.yml v2 $'inputs:\n  channel: {}'
    step acme/kit/setup@v2 channel
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  It 'checks a reusable workflow against its workflow_call inputs'
    package
    remote acme/ci .github/workflows/ci.yml main $'on:\n  workflow_call:\n    inputs:\n      dir: {}'
    job acme/ci/.github/workflows/ci.yml@main dir colour
    When run script "${check_inputs}"
    The status should be failure
    The line 1 of output should include '"colour" isn'
    The line 2 of output should equal 'Calls checked: 1.'
  End

  It 'checks a local reusable workflow'
    package
    printf 'on:\n  workflow_call:\n    inputs:\n      dir: {}\n' > .github/workflows/shared.yml
    job ./.github/workflows/shared.yml dir
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  # The action's own file has no steps, so this also covers a file with nothing to check.
  It 'checks a local action'
    package
    mkdir -p actions/detect
    printf 'inputs:\n  working-directory: {}\n' > actions/detect/action.yml
    step ./actions/detect working-directory
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  It 'reads $/ as this repo'
    package
    mkdir -p actions/detect
    printf 'inputs:\n  working-directory: {}\n' > actions/detect/action.yml
    step '$/actions/detect' working-directory depth
    When run script "${check_inputs}"
    The status should be failure
    The line 1 of output should include '"depth" isn'
    The line 2 of output should equal 'Calls checked: 1.'
  End

  It 'lets container actions take args and entrypoint'
    package
    remote acme/box action.yml v1 $'runs:\n  using: docker\n  image: Dockerfile'
    step acme/box@v1 args entrypoint
    When run script "${check_inputs}"
    The status should be success
    The output should equal 'Calls checked: 1.'
  End

  It 'rejects every key for an action without inputs'
    package
    remote acme/bare action.yml v1 'name: bare'
    step acme/bare@v1 anything
    When run script "${check_inputs}"
    The status should be failure
    The line 1 of output should end with 'It takes: nothing.'
  End

  It "fails when it can't read what an action takes"
    package
    step acme/gone@v1 name
    When run script "${check_inputs}"
    The status should be failure
    The line 1 of output should equal \
      "::error file=.github/workflows/ci.yml::Couldn't read what acme/gone@v1 accepts."
  End

  Describe 'skips'
    Parameters
      'container images' 'docker://alpine:3'
      'refs built at run time' "acme/tool@\${{ matrix.ref }}"
    End

    It "$1"
      package
      step "$2" anything
      When run script "${check_inputs}"
      The status should be success
      The output should equal 'Calls checked: 0.'
    End
  End

  Describe 'checks the steps of composite actions'
    Parameters
      'actions/wrap'
      '.github/actions/wrap'
    End

    It "in $1"
      package
      remote acme/tool action.yml v1 $'inputs:\n  name: {}'
      mkdir -p "$1"
      printf 'runs:\n  using: composite\n  steps:\n    - uses: acme/tool@v1\n      with:\n        nmae: x\n' \
        > "$1/action.yml"
      When run script "${check_inputs}"
      The status should be failure
      The line 1 of output should start with "::error file=$1/action.yml,line=6::\"nmae\" isn't"
    End
  End
End
