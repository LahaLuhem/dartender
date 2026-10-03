# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh
Include test/utils/gh.sh
Include test/utils/pub.sh

# mason only runs in the setup image, so this covers what callers.sh hands it and makes of the answer.
Describe 'setup/callers.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/callers.sh"

  # Listed by the pub stand-in as the repo's one package, at its root.
  one_package() { pub_lists p:.; }
  BeforeEach 'fresh_gh' 'one_package'

  # A repo with that package's pubspec, which the listing reads publish_to from.
  package_repo() {
    local r
    r="$(repo)"
    : > "${r}/pubspec.yaml"
    echo "${r}"
  }

  make_call() {
    grep '^mason make ' "${CALLS}" || :
  }

  adds_the_brick() {
    local path
    path="$(sed -n 's/^mason add -g callers --path //p')"
    [[ -n ${path} ]] && grep -qx 'name: callers' "${path}/brick.yaml"
  }

  It "renders dartender's brick into the repo, for the repo's default branch"
    r="$(package_repo)"
    git -C "${r}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The contents of file "${CALLS}" should satisfy adds_the_brick
    The result of function make_call should include "--output-dir ${r} "
    The result of function make_call should include '--default_branch master '
  End

  It 'hands mason the values it is given'
    r="$(package_repo)"
    When run script "${script}" false 90 'lib/a.dart lib/b.dart' 80 '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should end with \
      '--coveralls false --min_coverage 90 --coverage_excludes lib/a.dart lib/b.dart --python_min_coverage 80'
  End

  It 'hands mason the shell scripts for ShellCheck'
    r="$(package_repo)"
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
      r="$(package_repo)"
      When run script "${script}" true 95 '' 0 "$2" "${r}"
      The status should be success
      The output should be present
      The result of function make_call should include '--shellcheck false '
    End
  End

  It 'hands mason the Python coverage'
    r="$(package_repo)"
    When run script "${script}" true 95 '' 80 '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should include '--python true '
  End

  It 'leaves the Python coverage out when given none'
    r="$(package_repo)"
    When run script "${script}" true 95 '' '' '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should include '--python false '
  End

  It 'offers the release caller each package that publishes, where more than one does'
    r="$(package_repo)"
    printf 'publish_to: none\n' > "${r}/pubspec.yaml"
    mkdir -p "${r}/packages/a" "${r}/packages/b" "${r}/packages/c"
    : > "${r}/packages/a/pubspec.yaml"
    : > "${r}/packages/b/pubspec.yaml"
    printf 'publish_to: none\n' > "${r}/packages/c/pubspec.yaml"
    pub_lists w:. a:packages/a b:packages/b c:packages/c
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should include '--workspace true --packages ["a","b"] '
  End

  It 'asks no package where only one publishes'
    r="$(package_repo)"
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The result of function make_call should include '--workspace false --packages ["p"] '
  End

  It "fails with pub's own error when the packages can't be listed, rendering nothing"
    r="$(package_repo)"
    pub_fails 'Error on line 1 of pubspec.yaml'
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be failure
    The error should include 'Error on line 1 of pubspec.yaml'
    The result of function make_call should be blank
  End

  It 'says so when the callers are already up to date'
    r="$(package_repo)"
    export MASON_RC=0
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should include 'already'
  End

  It 'says it wrote the callers when mason changed them'
    r="$(package_repo)"
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be success
    The output should be present
    The output should not include 'already'
  End

  It "fails with mason's own error when mason fails"
    r="$(package_repo)"
    export MASON_RC=1
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be failure
    The error should include 'mason stand-in failed'
  End

  It "renders nothing when it can't tell the default branch"
    r="$(package_repo)"
    git -C "${r}" symbolic-ref --delete refs/remotes/origin/HEAD
    When run script "${script}" true 95 '' 0 '' "${r}"
    The status should be failure
    The error should be present
    The result of function make_call should be blank
  End

  It 'refuses a command line without the five values, before anything else'
    # In a repo, so nothing but the count can stop it.
    r="$(package_repo)"
    cd "${r}" || return
    When run script "${script}" true 95 '' ''
    The status should be failure
    The error should be present
    The contents of file "${CALLS}" should equal ''
  End
End
