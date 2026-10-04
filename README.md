Shared CI for my Dart and Flutter packages on pub.dev. Every package repo calls the workflows here,
so a fix lands once instead of six times. \
A bartender for Dart: one bar, serves every pub the same drinks the same pour.

> [!NOTE]
> Under construction.

## How it fits together

The jobs live here, and every package repo runs them from `main`. A package repo keeps only a few
small files of its own, plus some settings on GitHub that the jobs count on, and
[`setup.sh`](#setting-up-a-repo) makes all of them.

| In a package repo | What it's for |
|---|---|
| The caller workflows in `.github/workflows/` | Run `ci.yml`, `conventions.yml`, `publish.yml`, `changelog.yml` and `release.yml` from here, see [Calling it](#calling-it) |
| `.github/lint-checks.json` | Which linters run, see [Lints](#lints) |
| `.github/dependabot.yml` | What Dependabot keeps up to date |
| The `dartender` ruleset, the `sem-*` labels and the merge settings on GitHub | Required checks, and a changelog section for each PR |

Anything only one repo needs, like browser tests, lives in a workflow of that repo's own, next to
the callers.

## Setting up a repo

`scripts/setup/setup.sh` gets a package repo ready for the workflows here. Run it when a repo moves
onto dartender, and [again](#when-to-run-it-again) when something changes.

### What you need

- **bash 5.** macOS still ships 3.2, so `brew install bash`.
- **Docker, running.** Every other tool the setup uses comes in an image that `setup.sh` builds.
- **gh, logged in as the repo's admin.** The setup changes the repo's settings with that login.

### Running it

From the root of a clone of the repo:

```bash
(
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT INT TERM \
    && curl -fsSL https://github.com/LahaLuhem/dartender/archive/main.tar.gz \
       | tar -xz -C "$tmp" --strip-components=1 \
    && bash "$tmp/scripts/setup/setup.sh"
)
```

That runs the latest `setup.sh` from a temp folder, which goes when the run ends. The first run
takes longer, while Docker builds the image.

It asks before each part, and for the few settings the callers take, which start from what the repo
has now. Enter takes the starting answer:

| It asks | Starting from |
|---|---|
| Write the callers and `lint-checks.json`? | Yes |
| Upload coverage to Coveralls? | What the `ci` caller passes now, or else `ci.yml`'s default |
| The lowest line coverage that passes | The same |
| Globs to leave out of coverage, besides generated code | The same |
| The lowest coverage for `benchmark/python`'s tests, 0 for none, where there's one | The same |
| The shell scripts for ShellCheck | What ShellCheck checks now, or else `scripts/*.sh` when there's no `lint-checks.json` yet and that finds any |
| Write `dependabot.yml`? | Yes |
| Set the ruleset, labels and merge settings on GitHub? | Yes |

The ones in the middle only come up after a yes to the callers. A no leaves that part as it is, and
ctrl+c stops the setup. Put `-y` after `setup.sh` to go with every starting answer without being
asked, which is also the only way to run it without a terminal.

Then look over what it wrote in `.github/`, and commit it. The first run also says to delete the
repo's older ruleset, if it has one, since nothing runs that one's required checks anymore.

### What it sets

| What | Where | Taken from |
|---|---|---|
| The `ci`, `conventions`, `publish`, `changelog` and `release` callers | `.github/workflows/`, for you to commit | The templates in [`bricks/callers/`](bricks/callers/), your answers, and the packages the repo publishes |
| `lint-checks.json` | `.github/`, for you to commit | The same |
| `dependabot.yml`, a weekly block for each folder Dependabot has to watch | `.github/`, for you to commit | The repo's files, new ones included |
| The `dartender` ruleset, which requires `ci / ok` and `conventions / ok` and lets the changelog App past | GitHub | [`protected.example.json`](scripts/setup/protected.example.json) |
| The `sem-*` labels, one per changelog section | GitHub | [`sem-labels.json`](scripts/sem-labels.json) |
| Merge settings, like rebase merges only and auto-merge | GitHub | [`apply.sh`](scripts/setup/apply.sh) |

What's already set stays as it is, so running it again is safe. The files get rewritten whole,
though, so hand edits don't survive the next run.

### The repo's own checks

A check only one repo runs, like browser tests, goes in a ruleset of the repo's own, made under
**Settings → Rules → Rulesets**. GitHub requires the checks of every ruleset on a branch, so both
have to pass.

- **Give it a name of its own.** The setup takes over the one called `dartender`.
- **Point it at the default branch, and add the check** by its job's `name:`, or the job's id when
  it has none.
- **Add the repo's admins and the changelog App to its bypass list**, since each ruleset has its
  own and the App's changelog commits and releases have to get past every one.

### When to run it again

- **The repo gets something new for Dependabot to watch**, like an example app. CI's Dependabot
  config job fails and names it.
- **dartender changes what it writes or sets**, like a new label.
- **An answer changes**, like the lowest coverage.
- **A package starts or stops publishing**, since the release form lists the ones that do.

<details>
<summary>What happens under the hood</summary>

`setup.sh` builds the `dartender-setup` image from [`scripts/setup/Dockerfile`](scripts/setup/Dockerfile)
and runs [`inside.sh`](scripts/setup/inside.sh) in it. The clone comes in as the working folder,
dartender's scripts come in read-only, so a cached image never runs old ones, and your gh token
comes in as `GH_TOKEN`.

`inside.sh` asks its questions with [gum](https://github.com/charmbracelet/gum), then has
[`callers.sh`](scripts/setup/callers.sh) fill in the templates with
[mason](https://github.com/felangel/mason). Those files come first, so the `dependabot.yml` that
[`dependabot.sh`](scripts/setup/dependabot.sh) writes next already watches them. Last,
[`apply.sh`](scripts/setup/apply.sh) sets up GitHub.

If GitHub won't take the ruleset, say with a token that can't manage rulesets, it stops and says
how to import it by hand.

</details>

## Calling it

A package repo calls each workflow from a caller that `setup.sh` writes, with a job pinned to
`@main`, like `uses: LahaLuhem/dartender/.github/workflows/ci.yml@main`. The required checks,
`ci / ok` and `conventions / ok`, take their names from the `ci` and `conventions` jobs.

| Job | Calls | Grants | For |
|---|---|---|---|
| `ci` | `ci.yml` | `contents: write`, `pull-requests: write` | Auto-merging Dependabot's PRs |
| `conventions` | `conventions.yml` | `contents: read`, `pull-requests: read` | Reading the PR's commits and labels |
| `publish` | `publish.yml` | `contents: read`, `id-token: write` | The OIDC token pub.dev takes instead of a login |
| `changelog` | `changelog.yml` | `contents: read`, `pull-requests: read` | Reading the merged PR. The App's token does the writing |
| `release` | `release.yml` | `contents: read`, `pull-requests: read` | Reading Dependabot's PRs. The App's token does the pushing |

If a caller grants less than a job asks for, the run won't start, even when that job would skip.
The `release` caller runs the `ci` caller first, from a job of its own with the same grants.

The `publish` caller runs on a version tag, whose form depends on how many packages the repo
publishes:

| The repo publishes | Tag | Tag pattern to set on pub.dev |
|---|---|---|
| One package | `1.2.3` | `{{version}}` |
| More than one | `<package>-1.2.3` | `<package>-{{version}}`, on each package |

A tag in the other form fails the run, which says the form the repo takes.

The `changelog` caller runs on each push to the default branch. For a merged PR, it adds the PR's
title under the section its `sem-*` label names, in the `CHANGELOG.md` of each published package
the PR changed. A file counts for the deepest package folder holding it, so in a repo of one
package every PR's line goes there. `sem-skip` PRs get none, and Dependabot's get theirs at
[release](#releasing). A line that shouldn't go to every package the PR changed needs a PR per
package, or a hand edit after the merge.

Each `CHANGELOG.md` goes in as a commit of its own, with the changelog App's token, which the
ruleset lets past, and a release pushes with it too. So the repo needs the App installed, its ID in
an `APP_ID` variable and its private key in an `APP_PRIVATE_KEY` secret. The setup doesn't make
those.

The ruleset has to be in place before the `ci` caller lands. Until it requires `ci / ok`, `gh`
merges Dependabot's PRs on the spot instead of waiting for CI. A run that says yes to GitHub takes
care of that.

A repo's own workflow can use the setup actions here too, after its checkout, like
`uses: LahaLuhem/dartender/actions/setup-flutter@main`.

## Releasing

A release starts from the repo's **Actions** tab: **Release**, then **Run workflow** on the default
branch. Its form asks which part of the version moves, which package where the repo publishes more
than one, and whether it's a dry run. A dry run goes through everything but the push.

The repo's own CI runs first. Once it passes, the release, for that package:

1. Adds the title of each Dependabot PR since the last release that changed the package's
   `dependencies:`, under Changed. Dev dependencies don't count.
2. Bumps the version with cider, and dates what's under Unreleased as that version.
3. Raises any lower bound the repo's other packages have on it to the new version.
4. Runs `flutter pub get` in the example, where its `pubspec.lock` is tracked, since that pins the
   version.
5. Commits it all as whoever started the run, then runs `dart pub publish --dry-run`.
6. Pushes the commit and the version's tag together, with the changelog App's token.

That tag starts the `publish` caller. The run's summary shows the release notes, a dry run's too.

A release needs a tag for the package's current version, where Dependabot's lines start from, and
something to release, under Unreleased or from Dependabot. In a workspace, a package whose lower
bound on another of the repo's packages is below the major the repo has of it can't be released
until that bound goes up, since pub.dev keeps a published bound for good.

## Workspaces

A repo can be a [pub workspace](https://dart.dev/tools/pub/workspaces) of several packages. The jobs
get a repo's packages from pub, which lists a single package as a workspace of one, so a workspace
needs nothing set up of its own.

| What | In a workspace |
|---|---|
| Format, Analyze and Dependency validator | One run from the root, which covers every package |
| Tests | One run over every package's tests, gated on their combined coverage |
| Dartdoc | Each package that publishes |
| Publish | The package the tag names, see [Calling it](#calling-it) |
| Changelog | Each published package the PR changed, see [Calling it](#calling-it) |
| Release | The package picked in the form, see [Releasing](#releasing) |
| `dependabot.yml` | One `pub` block, at the root, since pub only updates a workspace from there |

Not covered: Flutter workspaces, and a member with an example app of its own.

## Lints

`lint-checks.json` lists the linters CI runs, each from the
[linterpol](https://github.com/LahaLuhem/linterpol) image, and `setup.sh` writes it. Repos without
their own `.rumdl.toml` or `.yamllint.yaml` get the ones in `actions/lint/defaults/`. A linter only
one repo needs goes in a workflow of that repo's own, since the setup's next run rewrites the file.

## Python

A repo's Python goes in one [uv](https://docs.astral.sh/uv/) project at `benchmark/python`, with
its tests in `benchmark/python/tests`. `ci.yml` runs Ruff lint, Ruff format and Pytest there, with
the project's own Ruff and pytest, so both go in its dev dependencies. A `benchmark/python` without
`tests` fails the run, and Python anywhere else goes unchecked.

The coverage gate, which the setup asks for, is off at 0. Above that it needs pytest-cov too, and a
`--cov` in the project's pytest settings, since without one nothing gets measured and anything
passes.

## What's inside

| Path | What |
|---|---|
| `.github/workflows/ci.yml` | The checks a package repo runs on its PRs, its pushes to main and before a release, plus auto-merge for Dependabot's PRs |
| `.github/workflows/conventions.yml` | The rules a package repo's PRs follow |
| `.github/workflows/publish.yml` | Publishes a package repo's tagged release to pub.dev |
| `.github/workflows/changelog.yml` | Writes each merged PR's line in the `CHANGELOG.md` of every published package it changed |
| `.github/workflows/release.yml` | Releases a package repo's package from its Actions tab, see [Releasing](#releasing) |
| `.github/workflows/self-test.yml` | Dartender's own CI |
| `actions/detect/` | Works out what's in a repo, so `ci.yml` only runs what applies |
| `actions/lint/` | Runs one linter from the [linterpol](https://github.com/LahaLuhem/linterpol) image |
| `actions/check-inputs/` | Fails on a `with:` key the action or workflow behind `uses:` doesn't take |
| `actions/setup-flutter/` | Flutter stable with its pub cache, then `flutter pub get` unless `pub-get` is false |
| `actions/setup-python-uv/` | uv with its cache, then `uv sync --frozen` for the project's Python and locked dependencies |
| `actions/branch-name/` | Fails on a PR branch that isn't named `<type>/#<issue>-<name>` |
| `actions/commit-conventions/` | Fails on a blank PR description, a merge commit, or an overlong commit subject |
| `actions/sem-label/` | Fails unless the PR has exactly one `sem-*` label, read fresh from the API |
| `actions/dependabot/` | Fails when the repo's `dependabot.yml` leaves out something for Dependabot to watch |
| `actions/test/` | Tests every package in one very_good run, gated on their combined coverage |
| `actions/dartdoc/` | Fails unless dart doc comes back clean for every package the repo publishes |
| `actions/tag-package/` | Finds the folder of the package a tag publishes |
| `actions/changelog-type/` | Finds the PR a pushed commit came from, and the changelog section its line goes under |
| `actions/changelog/` | Adds that line with cider to each package the PR changed, and commits each through the contents API |
| `actions/release/` | Writes Dependabot's lines, bumps and dates the release, commits it as whoever started the run, and pushes commit and tag together |
| `bricks/callers/` | The templates `setup.sh` fills in for a package repo: its callers and `lint-checks.json` |
| `scripts/` | The shell the actions run, and the `sem-*` labels in `sem-labels.json` |
| `scripts/setup/` | `setup.sh`, the image it runs in, and what runs there, see [Setting up a repo](#setting-up-a-repo) |
| `test/unit_tests/` | A spec for each script |
| `test/utils/` | What the specs share, like stand-ins for `gh` and `docker` |
| `test/workflow_tests/` | Packages laid out like the real repos, which the self-test runs the workflows against |

## Specs

`test/run.sh` runs the [ShellSpec](https://shellspec.info) specs in Docker the same way CI does.
It hands any arguments to `shellspec`, so `test/run.sh test/unit_tests/detect_spec.sh` runs only
that one. Where specs go and how to write them is in [CODESTYLE.md](CODESTYLE.md#specs).

## Changing things here

Every package repo runs whatever is on `main`, so `main` only moves through PRs that pass
`self-test-ok`. That's also why the workflows reach their own actions with `$/`: it pins them to
the commit being run, so a PR tests its own version of everything.

Style for the shell, the specs and the prose lives in [CODESTYLE.md](CODESTYLE.md).

Commits here are [conventional](https://www.conventionalcommits.org), so `git cliff` turns the
history into a changelog. The package repos stick to one changelog entry per PR, which
`changelog.yml` writes as the PR merges, or `release.yml` at release for Dependabot's.
