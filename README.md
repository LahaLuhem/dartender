Shared CI for my Dart and Flutter packages on pub.dev. Every package repo calls the workflows here,
so a fix lands once instead of six times. \
A bartender for Dart: one bar, serves every pub the same drinks the same pour.

> [!NOTE]
> Under construction. For now it lints, checks action inputs, and runs the package and example
> checks. PR conventions, Dependabot auto-merge, publishing and the setup scripts are on their way.

## What's inside

| Path | What |
|---|---|
| `.github/workflows/ci.yml` | The checks a package repo runs on its PRs and pushes to main |
| `.github/workflows/self-test.yml` | Dartender's own CI |
| `actions/detect/` | Works out what's in a repo, so `ci.yml` only runs what applies |
| `actions/lint/` | Runs one linter from the [linterpol](https://github.com/LahaLuhem/linterpol) image |
| `actions/check-inputs/` | Fails on a `with:` key the action or workflow behind `uses:` doesn't take |
| `actions/setup-flutter/` | Flutter stable with its pub cache, then `flutter pub get` |
| `scripts/` | The shell the actions run |
| `test/unit_tests/` | A spec for each script |
| `test/workflow_tests/` | Packages laid out like the real repos, which the self-test runs `ci.yml` against |

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
