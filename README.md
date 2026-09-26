Shared CI for my Dart and Flutter packages on pub.dev. Every package repo calls the workflows here,
so a fix lands once instead of six times. \
A bartender for Dart: one bar, serves every pub the same drinks the same pour.

> [!NOTE]
> Under construction. For now it lints, checks action inputs, runs the package, example and PR
> checks, and auto-merges Dependabot's PRs. Publishing and the setup scripts are on their way.

## What's inside

| Path | What |
|---|---|
| `.github/workflows/ci.yml` | The checks a package repo runs on its PRs and pushes to main, plus auto-merge for Dependabot's PRs |
| `.github/workflows/conventions.yml` | The rules a package repo's PRs follow |
| `.github/workflows/self-test.yml` | Dartender's own CI |
| `actions/detect/` | Works out what's in a repo, so `ci.yml` only runs what applies |
| `actions/lint/` | Runs one linter from the [linterpol](https://github.com/LahaLuhem/linterpol) image |
| `actions/check-inputs/` | Fails on a `with:` key the action or workflow behind `uses:` doesn't take |
| `actions/setup-flutter/` | Flutter stable with its pub cache, then `flutter pub get` |
| `actions/branch-name/` | Fails on a PR branch that isn't named `<type>/#<issue>-<name>` |
| `actions/commit-conventions/` | Fails on a blank PR description, a merge commit, or a commit subject over 82 characters |
| `actions/sem-label/` | Fails unless the PR has exactly one of the seven `sem-*` labels, read fresh from the API |
| `scripts/` | The shell the actions run |
| `test/unit_tests/` | A spec for each script |
| `test/workflow_tests/` | Packages laid out like the real repos, which the self-test runs `ci.yml` against |

## Calling it

A package repo calls each workflow from a caller file of its own, with one job pinned to `@main`:
`uses: LahaLuhem/dartender/.github/workflows/ci.yml@main`. The required checks, `ci / ok` and
`conventions / ok`, take their names from these jobs, so keep them.

| Job | Calls | Grants | For |
|---|---|---|---|
| `ci` | `ci.yml` | `contents: write`, `pull-requests: write` | Auto-merging Dependabot's PRs |
| `conventions` | `conventions.yml` | `contents: read`, `pull-requests: read` | Reading the PR's commits and labels |

If a caller grants less than a job asks for, the run won't start, even when that job would skip.
With nothing required, `gh` merges Dependabot's PRs on the spot instead of waiting, so a repo gets
its ruleset before its `ci` caller.

## Lints

A repo lists its linters in `.github/lint-checks.json`, and this repo's own is a working example.
Repos without their own `.rumdl.toml` or `.yamllint.yaml` get the ones in `actions/lint/defaults/`.

## Specs

`test/run.sh` runs the [ShellSpec](https://shellspec.info) specs in Docker the same way CI does.
It hands any arguments to `shellspec`, so `test/run.sh test/unit_tests/detect_spec.sh` runs just
that one. Where specs go and how to write them is in [CODESTYLE.md](CODESTYLE.md#specs).

## Changing things here

Every package repo runs whatever is on `main`, so `main` only moves through PRs that pass
`self-test-ok`. That's also why the workflows reach their own actions with `$/`: it pins them to
the commit being run, so a PR tests its own version of everything.

Style for the shell, the specs and the prose lives in [CODESTYLE.md](CODESTYLE.md).

Commits here are [conventional](https://www.conventionalcommits.org), so `git cliff` turns the
history into a changelog. The package repos stick to one changelog entry per PR, written at
release time.
