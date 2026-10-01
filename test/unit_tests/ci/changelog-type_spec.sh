# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Describe 'ci/changelog-type.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/ci/changelog-type.sh"
  labels="${SHELLSPEC_PROJECT_ROOT}/scripts/sem-labels.json"
  export REPO=owner/repo SHA=acfd6e34b152ddafe5168cf760c7e9dbbba7a116 LABEL='' TITLE=''
  another_commit=0000000000000000000000000000000000000000

  pull() {
    jq -n --argjson number "$1" --arg sha "$2" --arg login "$3" --arg title "${4:-Add a thing}" \
      '{number: $number, title: $title, merge_commit_sha: $sha, user: {login: $login}}'
  }

  Mock gh
    case "$*" in
      "api repos/${REPO}/commits/${SHA}/pulls") printf '%s\n' "${PULLS}" ;;
      "api repos/${REPO}/pulls/7 --jq .labels[].name") printf '%s\n' "${LABELS}" ;;
      *)
        echo "unexpected call: gh $*" >&2
        exit 9
        ;;
    esac
  End

  Describe 'a PR whose sem-* label has a changelog section'
    Parameters
      sem-add
      sem-change
      sem-deprecate
      sem-remove
      sem-bugfix
      sem-security
    End

    It "puts a $1 PR's line under the section the label's description names"
      PULLS="[$(pull 7 "${SHA}" LahaLuhem)]"
      section="$(jq -r --arg label "$1" '.[] | select(.name == $label).description
        | ltrimstr("Changelog: ") | ascii_downcase' "${labels}")"
      export PULLS LABELS="$1"
      When run script "${script}"
      The status should be success
      The line 1 of output should equal "type=${section}"
      The error should include '#7'
    End
  End

  It "hands on the PR's title as written, on one line"
    title=$'Add `putAll`  for $HOME\nand more'
    PULLS="[$(pull 7 "${SHA}" LahaLuhem "${title}")]"
    # shellcheck disable=SC2016  # the title as it has to come out, backticks and dollar sign intact
    expected="$(printf '%s\n' type=added 'title=Add `putAll`  for $HOME and more')"
    export PULLS LABELS=sem-add
    When run script "${script}"
    The status should be success
    The output should equal "${expected}"
    The error should include '#7'
  End

  It 'writes nothing for a sem-skip PR, and says so'
    PULLS="[$(pull 7 "${SHA}" LahaLuhem)]"
    export PULLS LABELS=sem-skip
    When run script "${script}"
    The status should be success
    The output should be blank
    The error should include 'sem-skip'
  End

  It "writes nothing for Dependabot's PRs, whose lines come at release time"
    PULLS="[$(pull 7 "${SHA}" 'dependabot[bot]')]"
    export PULLS LABELS=''
    When run script "${script}"
    The status should be success
    The output should be blank
    The error should include 'Dependabot'
  End

  Describe 'a commit no PR merged, like a release commit'
    Parameters
      'no PR at all' none
      'only a PR it sits in' another
    End

    It "writes nothing for $1, and says so"
      PULLS='[]'
      if [[ $2 == another ]]; then PULLS="[$(pull 5 "${another_commit}" LahaLuhem)]"; fi
      export PULLS
      When run script "${script}"
      The status should be success
      The output should be blank
      The error should include 'No pull request merged'
    End
  End

  It 'takes the PR that merged the commit, when the commit sits in others too'
    other="$(pull 5 "${another_commit}" LahaLuhem Other)"
    PULLS="[${other}, $(pull 7 "${SHA}" LahaLuhem)]"
    export PULLS LABELS=sem-add
    When run script "${script}"
    The status should be success
    The line 2 of output should equal 'title=Add a thing'
    The error should include '#7'
  End

  Describe 'a PR without exactly one sem-* label the repos use'
    Parameters
      'no sem-* label' 'bug' 'it has 0'
      'two' $'sem-add\nsem-bugfix' 'it has 2'
      'an unknown one' 'sem-feature' "sem-feature isn't"
    End

    It "fails on $1, with sem-label.sh's message and nothing for the outputs"
      PULLS="[$(pull 7 "${SHA}" LahaLuhem)]"
      export PULLS LABELS="$2"
      When run script "${script}"
      The status should be failure
      The output should be blank
      The error should include "$3"
    End
  End

  It "fails when the API can't be reached"
    Mock gh
      (exit 4)
    End
    When run script "${script}"
    The status should be failure
    The output should be blank
  End

  Describe "the self-test's stand-ins for a PR"
    Mock gh
      echo "unexpected call: gh $*" >&2
      (exit 9)
    End

    It 'takes a stand-in label and title without asking the API'
      export LABEL=sem-change TITLE=Probe
      expected="$(printf '%s\n' type=changed title=Probe)"
      When run script "${script}"
      The status should be success
      The output should equal "${expected}"
      The error should include 'stand-in'
    End

    It "fails on a stand-in label that sem-labels.json doesn't have"
      export LABEL=sem-feature TITLE=Probe
      When run script "${script}"
      The status should be failure
      The output should be blank
      The error should include 'sem-feature'
    End
  End
End
