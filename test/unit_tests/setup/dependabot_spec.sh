# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh

Describe 'setup/dependabot.sh'
  script="${SHELLSPEC_PROJECT_ROOT}/scripts/setup/dependabot.sh"
  manifest='{"image":"img","checks":[{"name":"a","cmd":"a"}]}'

  blocks() {
    yq '[.updates[] | ."package-ecosystem" + " " + .directory] | sort | .[]' \
      "${r}/.github/dependabot.yml"
  }

  misgrouped() {
    local updates
    updates="$(yq -o json '.updates' "${r}/.github/dependabot.yml")"
    jq -r '.[] | select(
      (.groups | keys) != [."package-ecosystem"]
      or [.groups[] | .patterns // ["*"]] != [["*"]]
      or [.groups[] | ."update-types" | sort] != [["minor", "patch"]]
    ) | ."package-ecosystem" + " " + .directory' <<< "${updates}"
  }

  intervals() {
    yq '[.updates[].schedule.interval] | unique | .[]' "${r}/.github/dependabot.yml"
  }

  version() {
    yq .version "${r}/.github/dependabot.yml"
  }

  mtime() {
    stat -c %Y "${r}/.github/dependabot.yml"
  }

  It 'writes a weekly block for each folder and ecosystem Dependabot has to watch'
    r="$(repo "${manifest}")"
    track "${r}" .github/workflows/ci.yml
    track "${r}" pubspec.yaml
    track "${r}" example/pubspec.yaml
    track "${r}" example/android/settings.gradle.kts
    expected="$(printf '%s\n' 'github-actions /' 'gradle /example/android' 'pub /' 'pub /example')"
    # From inside the repo with no argument, the way a package repo's admin runs it.
    cd "${r}" || return
    When run script "${script}"
    The status should be success
    The output should be present
    The result of function blocks should equal "${expected}"
    The result of function intervals should equal 'weekly'
    The result of function version should equal 2
  End

  It "groups each folder's minors and patches under its ecosystem, leaving majors a PR each"
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    track "${r}" example/pubspec.yaml
    track "${r}" example/android/settings.gradle.kts
    When run script "${script}" "${r}"
    The status should be success
    The output should be present
    The result of function blocks should be present
    The result of function misgrouped should be blank
  End

  It 'replaces the file that is there, so a block for a folder that went away goes too'
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    printf '%s\n' 'version: 2' 'updates:' '  - package-ecosystem: pub' '    directory: /gone' \
      '    schedule:' '      interval: daily' > "${r}/.github/dependabot.yml"
    When run script "${script}" "${r}"
    The status should be success
    The output should be present
    The result of function blocks should equal 'pub /'
    The contents of file "${r}/.github/dependabot.yml" should not include '/gone'
  End

  It 'leaves the file alone when it is already up to date, and says so'
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    "${script}" "${r}" > /dev/null
    # Backdated, so a rewrite would show even within the same second.
    touch -t 200001010000 "${r}/.github/dependabot.yml"
    stamp="$(mtime)"
    When run script "${script}" "${r}"
    The status should be success
    The output should include 'already'
    The result of function mtime should equal "${stamp}"
  End

  It 'leaves the file alone when detect.sh fails'
    # No lint manifest, which detect.sh stops on.
    r="$(repo)"
    printf 'old\n' > "${r}/.github/dependabot.yml"
    When run script "${script}" "${r}"
    The status should be failure
    The stderr should be present
    The contents of file "${r}/.github/dependabot.yml" should equal 'old'
  End

  # By a relative path, since the script finds detect.sh from where it sits.
  It 'writes into the folder it is given'
    r="$(repo "${manifest}")"
    track "${r}" pubspec.yaml
    When run script scripts/setup/dependabot.sh "${r}"
    The status should be success
    The output should be present
    The result of function blocks should equal 'pub /'
  End
End
