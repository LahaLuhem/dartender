# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/commit-conventions.sh'
  check="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/commit-conventions.sh"

  # A repo with one commit on main, which is where the pull request starts.
  pull_request() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    cd "${repo}" || return
    git init -q -b main
    git config user.name spec
    git config user.email spec@example.com
    git commit -q --allow-empty -m base
    BASE_SHA="$(git rev-parse HEAD)"
    export BASE_SHA PR_BODY='Does a thing.'
  }

  # Moves the pull request's end to HEAD.
  head_here() {
    HEAD_SHA="$(git rev-parse HEAD)"
    export HEAD_SHA
  }

  It 'passes a pull request that keeps to the rules'
    pull_request
    git commit -q --allow-empty -m 'feat: a thing'
    head_here
    When run script "${check}"
    The status should be success
  End

  It 'fails a description of only blank lines'
    pull_request
    git commit -q --allow-empty -m 'feat: a thing'
    head_here
    export PR_BODY=$'\n  \n'
    When run script "${check}"
    The status should be failure
    The output should include 'needs a description'
  End

  It 'fails a merge from the base branch'
    pull_request
    git switch -q -c topic
    git commit -q --allow-empty -m 'feat: a thing'
    git switch -q main
    git commit -q --allow-empty -m 'fix: meanwhile on main'
    git switch -q topic
    git merge -q --no-edit main
    head_here
    When run script "${check}"
    The status should be failure
    The output should include 'instead of merging'
  End

  It 'passes a subject of exactly 82 characters'
    pull_request
    subject="$(printf '%82s' '' | tr ' ' x)"
    git commit -q --allow-empty -m "${subject}"
    head_here
    When run script "${check}"
    The status should be success
  End

  It 'fails a subject of 83'
    pull_request
    subject="$(printf '%83s' '' | tr ' ' x)"
    git commit -q --allow-empty -m "${subject}"
    head_here
    When run script "${check}"
    The status should be failure
    The output should include 'over 82 characters'
  End

  It 'reports every problem, not just the first'
    pull_request
    subject="$(printf '%83s' '' | tr ' ' x)"
    git commit -q --allow-empty -m "${subject}"
    head_here
    export PR_BODY=''
    When run script "${check}"
    The status should be failure
    The line 1 of output should include 'needs a description'
    The line 2 of output should include 'over 82 characters'
  End
End
