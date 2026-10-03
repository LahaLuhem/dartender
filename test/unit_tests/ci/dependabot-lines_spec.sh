# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables

Describe 'ci/dependabot-lines.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/dependabot-lines.sh"
  export REPO=owner/repo GH_TOKEN=job-token GH_FAILS=''

  setup() {
    repo="$(mktemp -d "${SHELLSPEC_TMPBASE}/repo.XXXXXX")"
    # Next to the repo rather than in it, so git never sees it.
    export PULLS="${repo}.pulls"
    : > "${PULLS}"
    git init -q "${repo}"
    cd "${repo}" || return
    pubspec . 'http: ^1.0.0' 'test: ^1.0.0'
    commit 'First'
    git tag 1.0.0
  }
  BeforeEach 'setup'

  # Writes folder $1's pubspec, with $2 as its one dependency and $3 as its one dev dependency.
  pubspec() {
    mkdir -p "$1"
    printf 'name: p\ndependencies:\n  %s\ndev_dependencies:\n  %s\n' "$2" "$3" > "$1/pubspec.yaml"
  }

  # Commits everything, as $2 when named and as a person otherwise.
  commit() {
    git add -A
    git -c user.name="${2:-A Person}" -c user.email=spec@example.com commit -q -m "$1"
  }

  # The merged PR GitHub says the last commit came in with: its author, number and title.
  merged_in() {
    local sha
    sha="$(git rev-parse HEAD)"
    jq -cn --arg sha "${sha}" --arg login "$1" --argjson number "$2" --arg title "$3" \
      '{sha: $sha, pulls: [{number: $number, title: $title, user: {login: $login}}]}' >> "${PULLS}"
  }

  Mock gh
    if [[ -n ${GH_FAILS} ]]; then
      echo "${GH_FAILS}" >&2
      exit 1
    fi
    # gh api repos/owner/repo/commits/<sha>/pulls --jq <filter>
    sha="${2#repos/owner/repo/commits/}"
    pulls="$(jq -c --arg sha "${sha%/pulls}" 'select(.sha == $sha) | .pulls' "${PULLS}")"
    jq -r "$4" <<< "${pulls:-[]}"
  End

  It "gives a Dependabot PR's title when it changed the package's dependencies"
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" . 1.0.0
    The output should equal 'Bump http from 1.0.0 to 2.0.0'
    The error should include '#4'
  End

  It 'gives nothing for a Dependabot PR that only changed dev dependencies'
    pubspec . 'http: ^1.0.0' 'test: ^2.0.0'
    commit 'Bump test from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump test from 1.0.0 to 2.0.0'
    When run script "${script}" . 1.0.0
    The output should equal ''
  End

  It "gives nothing for a person's PR, which got its own line when it merged"
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Move to http 2'
    merged_in 'a-person' 5 'Move to http 2'
    When run script "${script}" . 1.0.0
    The output should equal ''
  End

  It "counts a person's commit on a Dependabot PR as that PR's"
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Fix the build for http 2'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" . 1.0.0
    The output should equal 'Bump http from 1.0.0 to 2.0.0'
    The error should include '#4'
  End

  It 'gives a PR one line, however many of its commits changed dependencies'
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    pubspec . 'http: ">=1.0.0 <3.0.0"' 'test: ^1.0.0'
    commit 'Keep http 1 working'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" . 1.0.0
    The output should equal 'Bump http from 1.0.0 to 2.0.0'
    The error should include '#4'
  End

  It 'lists the PRs in the order they merged'
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    pubspec . 'http: ^3.0.0' 'test: ^1.0.0'
    commit 'Bump http from 2.0.0 to 3.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 6 'Bump http from 2.0.0 to 3.0.0'
    When run script "${script}" . 1.0.0
    The output should equal $'Bump http from 1.0.0 to 2.0.0\nBump http from 2.0.0 to 3.0.0'
    The error should include '#6'
  End

  It 'leaves out what merged before the release it starts from'
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    git tag 1.1.0
    pubspec . 'http: ^3.0.0' 'test: ^1.0.0'
    commit 'Bump http from 2.0.0 to 3.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 6 'Bump http from 2.0.0 to 3.0.0'
    When run script "${script}" . 1.1.0
    The output should equal 'Bump http from 2.0.0 to 3.0.0'
    The error should include '#6'
  End

  It "gives a workspace member the line for its own pubspec's change"
    pubspec packages/b 'http: ^1.0.0' 'test: ^1.0.0'
    commit 'Add b'
    git tag b-1.0.0
    pubspec packages/b 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" packages/b b-1.0.0
    The output should equal 'Bump http from 1.0.0 to 2.0.0'
    The error should include '#4'
  End

  It "leaves out a change to another package's dependencies"
    pubspec packages/a 'http: ^1.0.0' 'test: ^1.0.0'
    pubspec packages/b 'http: ^1.0.0' 'test: ^1.0.0'
    commit 'Add a and b'
    git tag a-1.0.0
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    pubspec packages/b 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" packages/a a-1.0.0
    The output should equal ''
  End

  It "fails when the release it starts from isn't there, instead of reading all history"
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    merged_in 'dependabot[bot]' 4 'Bump http from 1.0.0 to 2.0.0'
    When run script "${script}" . 0.9.0
    The status should be failure
    The output should equal ''
    The error should be present
  End

  It "fails when GitHub can't say which PR a commit came in with"
    pubspec . 'http: ^2.0.0' 'test: ^1.0.0'
    commit 'Bump http from 1.0.0 to 2.0.0' 'dependabot[bot]'
    export GH_FAILS='HTTP 502'
    When run script "${script}" . 1.0.0
    The status should be failure
    The output should equal ''
    The error should include 'HTTP 502'
  End
End
