# shellcheck shell=bash
# shellcheck disable=SC2154  # ShellSpec sets the SHELLSPEC_* variables
Include test/utils/repo.sh

Describe 'detect.sh'
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

  It 'lists what it found on the run summary page'
    r="$(repo '{"image":"linterpol:1","checks":[{"name":"ShellCheck","cmd":"a"},{"name":"rumdl","cmd":"b"}]}')"
    summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
    export GITHUB_STEP_SUMMARY="${summary}"
    expected="$(printf '%s\n' '### What dartender found' '| What | Found |' '|---|---|' \
      '| Package | none |' '| Example | none |' '| Python | none |' \
      '| Linters | ShellCheck, rumdl |' "| Lint image | \`linterpol:1\` |" '| Dependabot | none |')"
    When run script scripts/detect.sh "${r}"
    The output should be present
    The contents of file "${summary}" should equal "${expected}"
  End

  Describe 'what Dependabot has to watch'
    # Whether the dependabot line on stdin lists exactly these `<package-ecosystem> <directory>`
    # pairs, in any order.
    watches() {
      local line actual want
      line="$(grep '^dependabot=')" || return 1
      actual="$(jq -r '.[] | "\(."package-ecosystem") \(.directory)"' <<< "${line#dependabot=}")" \
        || return 1
      actual="$(sort <<< "${actual}")"
      want="$(printf '%s\n' "$@" | sort)"
      [[ "${actual}" == "${want}" ]]
    }

    Describe 'each kind of manifest'
      Parameters
        'a pubspec' 'pubspec.yaml' 'pub /'
        "an example's pubspec" 'example/pubspec.yaml' 'pub /example'
        'a Gradle build' 'example/android/settings.gradle.kts' 'gradle /example/android'
        'a Groovy Gradle build' 'android/settings.gradle' 'gradle /android'
        'a uv project' 'benchmark/python/uv.lock' 'uv /benchmark/python'
        'a Swift package' 'ios/a/Package.swift' 'swift /ios/a'
        'a workflow' '.github/workflows/ci.yml' 'github-actions /'
        'a workflow in a .yaml file' '.github/workflows/ci.yaml' 'github-actions /'
      End

      It "watches $1"
        r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
        track "${r}" "$2"
        When run script scripts/detect.sh "${r}"
        The output should satisfy watches "$3"
      End
    End

    It 'watches each composite action in its own folder'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" .github/actions/a/action.yml $'runs:\n  using: composite\n  steps: []\n'
      track "${r}" .github/actions/b/action.yaml $'runs:\n  using: composite\n  steps: []\n'
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'github-actions /.github/actions/a' \
        'github-actions /.github/actions/b'
    End

    It "leaves out an action that isn't composite, since it has no uses: to bump"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" .github/actions/a/action.yml $'runs:\n  using: composite\n  steps: []\n'
      track "${r}" .github/actions/b/action.yml $'runs:\n  using: node24\n  main: index.js\n'
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'github-actions /.github/actions/a'
    End

    It 'watches a folder once per ecosystem'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" .github/workflows/a.yml
      track "${r}" .github/workflows/b.yml
      track "${r}" pubspec.yaml
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'github-actions /' 'pub /'
    End

    It 'watches a new file before it is committed, like a caller setup.sh just wrote'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" pubspec.yaml
      mkdir -p "${r}/.github/workflows"
      : > "${r}/.github/workflows/ci.yml"
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'github-actions /' 'pub /'
    End

    It "leaves out files git ignores, like the plugin links in a clone's example"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" pubspec.yaml
      track "${r}" example/ios/.gitignore '**/.symlinks/'
      mkdir -p "${r}/example/ios/.symlinks/plugins/a"
      : > "${r}/example/ios/.symlinks/plugins/a/pubspec.yaml"
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'pub /'
    End

    It "leaves out a file that's deleted but not committed yet"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" pubspec.yaml
      track "${r}" example/pubspec.yaml
      track "${r}" .github/actions/a/action.yml $'runs:\n  using: composite\n  steps: []\n'
      rm "${r}/example/pubspec.yaml" "${r}/.github/actions/a/action.yml"
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'pub /'
    End

    It 'leaves out test folders, which hold fixtures'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" pubspec.yaml
      track "${r}" test/fixture/pubspec.yaml
      track "${r}" packages/a/test/fixture/android/settings.gradle
      When run script scripts/detect.sh "${r}"
      The output should satisfy watches 'pub /'
    End

    It 'treats the folder it reads as the root, the way the self-test reads its fixtures'
      r="$(repo)"
      fixture="${r}/test/workflow_tests/a"
      mkdir -p "${fixture}/.github"
      printf '%s' '{"image":"img","checks":[{"name":"a","cmd":"a"}]}' \
        > "${fixture}/.github/lint-checks.json"
      track "${r}" test/workflow_tests/a/pubspec.yaml
      track "${r}" test/workflow_tests/a/example/pubspec.yaml
      When run script scripts/detect.sh "${fixture}"
      The output should satisfy watches 'pub /' 'pub /example'
    End

    It 'lists them on the run summary page'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" pubspec.yaml
      track "${r}" example/pubspec.yaml
      summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
      export GITHUB_STEP_SUMMARY="${summary}"
      When run script scripts/detect.sh "${r}"
      The output should be present
      The contents of file "${summary}" should include \
        "| Dependabot | \`pub /\`, \`pub /example\` |"
    End

    It 'fails outside a git repo, instead of finding nothing to watch'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      rm -rf "${r}/.git"
      When run script scripts/detect.sh "${r}"
      The status should be failure
      The output should be present
      The stderr should be present
    End
  End

  Describe 'the package'
    Parameters
      'no package' '' 'package=false' 'flutter=false' 'none'
      'a pure Dart package' 'name: a' 'package=true' 'flutter=false' 'pure Dart'
      'a Flutter package' $'name: a\ndependencies:\n  flutter:\n    sdk: flutter' \
        'package=true' 'flutter=true' 'Flutter'
    End

    It "finds $1"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      if [[ -n "$2" ]]; then printf '%s\n' "$2" > "${r}/pubspec.yaml"; fi
      summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
      export GITHUB_STEP_SUMMARY="${summary}"
      When run script scripts/detect.sh "${r}"
      The line 3 of output should equal "$3"
      The line 4 of output should equal "$4"
      The contents of file "${summary}" should include "| Package | $5 |"
    End
  End

  Describe 'the example'
    Parameters
      'no example' '' 'example=false' 'example-tests=false' 'none'
      'an example without tests' 'example' 'example=true' 'example-tests=false' 'without tests'
      'an example with tests' 'example/test' 'example=true' 'example-tests=true' 'with tests'
    End

    It "finds $1"
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      printf 'name: a\n' > "${r}/pubspec.yaml"
      if [[ -n "$2" ]]; then
        mkdir -p "${r}/$2"
        printf 'name: a_example\n' > "${r}/example/pubspec.yaml"
      fi
      summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
      export GITHUB_STEP_SUMMARY="${summary}"
      When run script scripts/detect.sh "${r}"
      The line 5 of output should equal "$3"
      The line 6 of output should equal "$4"
      The contents of file "${summary}" should include "| Example | $5 |"
    End
  End

  # Pure Dart packages often ship example/example.dart, which gets checked with the package itself.
  It 'ignores an example folder with no pubspec of its own'
    r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
    printf 'name: a\n' > "${r}/pubspec.yaml"
    mkdir -p "${r}/example/test"
    printf 'void main() {}\n' > "${r}/example/example.dart"
    When run script scripts/detect.sh "${r}"
    The line 5 of output should equal 'example=false'
    The line 6 of output should equal 'example-tests=false'
  End

  Describe 'the Python projects'
    Describe 'each kind'
      Parameters
        'no project' '' '' 'python=[]' 'none'
        'a project with tests' 'benchmark/python/uv.lock' 'benchmark/python/tests/test_a.py' \
          'python=[{"directory":"benchmark/python","tests":true}]' \
          "\`benchmark/python\` with tests"
        'a project without tests' 'benchmark/python/uv.lock' '' \
          'python=[{"directory":"benchmark/python","tests":false}]' \
          "\`benchmark/python\` without tests"
        'a project at the root' 'uv.lock' 'tests/test_a.py' \
          'python=[{"directory":".","tests":true}]' "\`.\` with tests"
      End

      It "finds $1"
        r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
        if [[ -n "$2" ]]; then track "${r}" "$2"; fi
        if [[ -n "$3" ]]; then track "${r}" "$3"; fi
        summary="$(mktemp "${SHELLSPEC_TMPBASE}/summary.XXXXXX")"
        export GITHUB_STEP_SUMMARY="${summary}"
        When run script scripts/detect.sh "${r}"
        The line 8 of output should equal "$4"
        The contents of file "${summary}" should include "| Python | $5 |"
      End
    End

    It 'leaves out one in a test folder, which is a fixture'
      r="$(repo '{"image":"img","checks":[{"name":"a","cmd":"a"}]}')"
      track "${r}" test/fixture/uv.lock
      When run script scripts/detect.sh "${r}"
      The line 8 of output should equal 'python=[]'
    End

    It 'finds one inside the folder it reads, the way the self-test reads its fixtures'
      r="$(repo)"
      fixture="${r}/test/workflow_tests/a"
      mkdir -p "${fixture}/.github"
      printf '%s' '{"image":"img","checks":[{"name":"a","cmd":"a"}]}' \
        > "${fixture}/.github/lint-checks.json"
      track "${r}" test/workflow_tests/a/benchmark/python/uv.lock
      track "${r}" test/workflow_tests/a/benchmark/python/tests/test_a.py
      When run script scripts/detect.sh "${fixture}"
      The line 8 of output should equal 'python=[{"directory":"benchmark/python","tests":true}]'
    End
  End

  Describe 'a broken manifest'
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
      'a check without a name' '{"image":"img","checks":[{"cmd":"a"}]}'
      'a check without a command' '{"image":"img","checks":[{"name":"a"}]}'
      'a blank command' '{"image":"img","checks":[{"name":"a","cmd":" "}]}'
      'a later check without a command' '{"image":"img","checks":[{"name":"a","cmd":"a"},{"name":"b"}]}'
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
