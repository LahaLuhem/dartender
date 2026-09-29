# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh
Include test/utils/gh.sh

# mason only runs in the setup image, so this covers what callers.sh hands it and makes of the answer.
Describe 'setup/callers.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/callers.sh"

  BeforeEach 'fresh_gh'

  make_call() {
    grep '^mason make ' "${CALLS}" || :
  }

  # Whether the log on stdin has mason adding a folder that holds dartender's callers brick.
  adds_the_brick() {
    local path
    path="$(sed -n 's/^mason add -g callers --path //p')"
    [[ -n ${path} ]] && grep -qx 'name: callers' "${path}/brick.yaml"
  }

  It "renders dartender's brick into the repo, for the repo's default branch"
    r="$(repo)"
    git -C "${r}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should satisfy adds_the_brick
    The result of function make_call should include "--output-dir ${r} "
    The result of function make_call should include '--default_branch master '
  End

  It 'hands mason the values it is given'
    r="$(repo)"
    When run script "${script}" false 90 'lib/a.dart lib/b.dart' 80 '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should end with \
      '--coveralls false --min_coverage 90 --coverage_excludes lib/a.dart lib/b.dart --python_min_coverage 80'
  End

  It 'hands mason the shell scripts for ShellCheck'
    r="$(repo)"
    When run script "${script}" true 95 '' 0 'scripts/*.sh benchmark/*.sh' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should include \
      '--shellcheck true --shellcheck_paths scripts/*.sh benchmark/*.sh '
  End

  Describe 'no shell scripts for ShellCheck'
    Parameters
      'nothing' ''
      'only spaces' '  '
    End

    It "leaves ShellCheck out for $1"
      r="$(repo)"
      When run script "${script}" true 95 '' 0 "$2" "${r}"
      The status should be success
      The output should be present
      The result of function make_call should include '--shellcheck false '
    End
  End

  It 'says so when the callers are already up to date'
    r="$(repo)"
    export MASON_RC=0
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should include 'already'
  End

  It 'says it wrote the callers when mason changed them'
    r="$(repo)"
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The output should not include 'already'
  End

  It "fails with mason's own error when mason fails"
    r="$(repo)"
    export MASON_RC=1
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be failure
    The error should include 'mason stand-in failed'
  End

  It "renders nothing when it can't tell the default branch"
    r="$(repo)"
    git -C "${r}" symbolic-ref --delete refs/remotes/origin/HEAD
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be failure
    The error should be present
    The result of function make_call should be blank
  End

  It 'refuses a command line without the five values, before anything else'
    # In a repo, so nothing but the count can stop it.
    r="$(repo)"
    cd "${r}" || return
    When run script "${script}" true 95 '' ''
    The status should be failure
    The error should be present
    The contents of file "${CALLS}" should equal ''
  End
End
