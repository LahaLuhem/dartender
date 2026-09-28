Shared CI for my Dart and Flutter packages on pub.dev. Every package repo calls the workflows here,
so a fix lands once instead of six times. \
A bartender for Dart: one bar, serves every pub the same drinks the same pour.

> [!NOTE]
> Under construction. For now it lints, checks action inputs and the Dependabot config, runs the
> package, example and PR checks, auto-merges Dependabot's PRs and publishes to pub.dev. Workspaces
> are on their way.

## How it fits together

The jobs live here, and every package repo runs them from `main`. A package repo keeps only a few
small files of its own, plus some settings on GitHub that the jobs count on.

| In a package repo | What it's for | Where it comes from |
|---|---|---|
| 3 caller workflows in `.github/workflows/` | Run `ci.yml`, `conventions.yml` and `publish.yml` from here | Written by hand, see [Calling it](#calling-it) |
| `.github/lint-checks.json` | Which linters run | Written by hand, see [Lints](#lints) |
| `.github/dependabot.yml` | What Dependabot keeps up to date | `setup.sh`, see [Setting up a repo](#setting-up-a-repo) |
| A ruleset, the `sem-*` labels and the merge settings on GitHub | Required checks, and a changelog section for each PR | `setup.sh` as well |

## Setting up a repo

`scripts/setup/setup.sh` gets a package repo ready for the workflows here. Run it when a repo moves
onto dartender, and again whenever something it sets needs to change.

### What you need

- **bash 5.** macOS still ships 3.2, so `brew install bash`.
- **Docker, running.** Every other tool the setup uses comes in an image that `setup.sh` builds.
- **gh, logged in as the repo's admin.** The setup changes the repo's settings with that login.
- **A clone of the repo with a `.github/lint-checks.json`.** The setup stops without one.

### Running it

From the root of the clone:

```bash
tmp=$(mktemp -d) \
  && curl -fsSL https://github.com/LahaLuhem/dartender/archive/main.tar.gz \
     | tar -xz -C "$tmp" --strip-components=1 \
  && bash "$tmp/scripts/setup/setup.sh"
```

That downloads dartender's `main` into a fresh temp folder and runs `setup.sh` from there, so every
run gets the latest. The first run takes longer, while Docker builds the image.

Then look over the `.github/dependabot.yml` it wrote, and commit it.

### What it sets

| What | Where | Taken from |
|---|---|---|
| `.github/dependabot.yml`, a weekly block for each folder Dependabot has to watch | The clone, for you to commit | The repo's files, new ones included |
| The `Protected` ruleset, which requires `ci / ok` and `conventions / ok` | GitHub | [`protected.example.json`](scripts/setup/protected.example.json) |
| The seven `sem-*` labels, one per changelog section | GitHub | [`sem-labels.json`](scripts/sem-labels.json) |
| Merge settings, like rebase merges only and auto-merge | GitHub | [`apply.sh`](scripts/setup/apply.sh) |

Whatever is already set stays as it is, and it says so, so running it again is safe. It writes
`dependabot.yml` whole each time, so edits made by hand don't survive the next run.

### The repo's own checks

If the repo has checks of its own that should block a merge, like a benchmark, name each one with
`--check` at the end of that last line, so the ruleset requires it next to `ci / ok` and
`conventions / ok`:

```bash
  && bash "$tmp/scripts/setup/setup.sh" --check benchmark-ok --check 'Browser tests (dart2js + dart2wasm)'
```

A check goes by its job's `name:`, or the job's id when it has none. Quote a name with spaces.

Pass the same `--check`s every time. The ruleset ends up with exactly the checks a run names, so a
run without them takes them out again.

### When to run it again

- **The repo gets something new for Dependabot to watch**, like an example app. CI's Dependabot
  config job fails and names it.
- **dartender changes what it sets**, like a new label.
- **The repo's own checks change.**

<details>
<summary>What happens under the hood</summary>

`setup.sh` builds the `dartender-setup` image from [`scripts/setup/Dockerfile`](scripts/setup/Dockerfile)
and runs [`inside.sh`](scripts/setup/inside.sh) in it. The clone comes in as the working folder,
dartender's scripts come in read-only, so a cached image never runs old ones, and your gh token
comes in as `GH_TOKEN`. `inside.sh` writes the `dependabot.yml` with
[`dependabot.sh`](scripts/setup/dependabot.sh), then sets up GitHub with
[`apply.sh`](scripts/setup/apply.sh).

If GitHub won't take the ruleset, say with a token that can't manage rulesets, it stops and says
how to import it by hand.

</details>

## Calling it

A package repo calls each workflow from a caller file of its own, with one job pinned to `@main`,
like `uses: LahaLuhem/dartender/.github/workflows/ci.yml@main`. The required checks, `ci / ok` and
`conventions / ok`, take their names from the `ci` and `conventions` jobs, so keep those names.

| Job | Calls | Grants | For |
|---|---|---|---|
| `ci` | `ci.yml` | `contents: write`, `pull-requests: write` | Auto-merging Dependabot's PRs |
| `conventions` | `conventions.yml` | `contents: read`, `pull-requests: read` | Reading the PR's commits and labels |
| `publish` | `publish.yml` | `contents: read`, `id-token: write` | The OIDC token pub.dev takes instead of a login |

`ci.yml`'s inputs, like the minimum coverage, are at the top of the file with their defaults.

The `publish` caller runs on pushed tags that match the package's pattern on pub.dev, like
`'[0-9]+.[0-9]+.[0-9]+'` for `{{version}}`.

If a caller grants less than a job asks for, the run won't start, even when that job would skip.

Run `setup.sh` before adding the `ci` caller. Until the ruleset requires `ci / ok`, `gh` merges
Dependabot's PRs on the spot instead of waiting for CI.

## Lints

A repo lists its linters in `.github/lint-checks.json`, and this repo's own is a working example.
Repos without their own `.rumdl.toml` or `.yamllint.yaml` get the ones in `actions/lint/defaults/`.

## What's inside

| Path | What |
|---|---|
| `.github/workflows/ci.yml` | The checks a package repo runs on its PRs and pushes to main, plus auto-merge for Dependabot's PRs |
| `.github/workflows/conventions.yml` | The rules a package repo's PRs follow |
| `.github/workflows/publish.yml` | Publishes a package repo's tagged release to pub.dev |
| `.github/workflows/self-test.yml` | Dartender's own CI |
| `actions/detect/` | Works out what's in a repo, so `ci.yml` only runs what applies |
| `actions/lint/` | Runs one linter from the [linterpol](https://github.com/LahaLuhem/linterpol) image |
| `actions/check-inputs/` | Fails on a `with:` key the action or workflow behind `uses:` doesn't take |
| `actions/setup-flutter/` | Flutter stable with its pub cache, then `flutter pub get` unless `pub-get` is false |
| `actions/branch-name/` | Fails on a PR branch that isn't named `<type>/#<issue>-<name>` |
| `actions/commit-conventions/` | Fails on a blank PR description, a merge commit, or a commit subject over 82 characters |
| `actions/sem-label/` | Fails unless the PR has exactly one of the seven `sem-*` labels, read fresh from the API |
| `actions/dependabot/` | Fails when the repo's `dependabot.yml` leaves out something for Dependabot to watch |
| `scripts/` | The shell the actions run, and the seven `sem-*` labels in `sem-labels.json` |
| `scripts/setup/` | `setup.sh`, the image it runs in, and what runs there, see [Setting up a repo](#setting-up-a-repo) |
| `test/unit_tests/` | A spec for each script |
| `test/utils/` | What the specs share, like stand-ins for `gh` and `docker` |
| `test/workflow_tests/` | Packages laid out like the real repos, which the self-test runs `ci.yml` and a `publish.yml` dry-run against |

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
