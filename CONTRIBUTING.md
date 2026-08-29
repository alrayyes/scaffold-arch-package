# Contributing

This file is for whoever changes this template. The [README](README.md) is
for whoever generates a project from it.

## Getting set up

- **[bun](https://bun.sh)** for the tooling — commitlint, Prettier,
  markdownlint, and the [lefthook](https://lefthook.dev) that runs the git
  hooks. There's a `package.json`, but nothing here is JavaScript; it exists
  only so those tools resolve and stay pinned.
- **Arch Linux, or a container of it**, for `makepkg` and
  [`namcap`](https://gitlab.archlinux.org/pacman/namcap) —
  `pacman -S --needed base-devel namcap`. Building a package needs a real
  Arch userland, which most contributors' machines aren't, so neither is a
  pre-commit dependency: `makepkg` (regenerating `.SRCINFO`) only runs at
  pre-push, and `namcap` only runs in CI's pinned `archlinux` container via
  `.ci/build-and-lint.sh` — which you can also run by hand the same way CI
  does, given Arch or Docker.
- **[ShellCheck](https://www.shellcheck.net)** on your `PATH` for the shell
  scripts under `.ci/`.

One command installs the JS-side linters and the git hooks:

```sh
bun install
```

An uninstalled hook silently does nothing, which is worse than not having
one, so the `prepare` script runs `lefthook install` for you. You find out at
the pipeline otherwise, not at the commit.

## Everyday commands

Every one of these is what a hook or CI runs — see `lefthook.yml` and
`.github/workflows/*.yml` for exactly which.

```sh
shellcheck .ci/*.sh
namcap PKGBUILD
namcap example-git/PKGBUILD

# Regenerate .SRCINFO after any PKGBUILD change — commit both together.
makepkg --printsrcinfo > .SRCINFO
(cd example-git && makepkg --printsrcinfo > .SRCINFO)
./.ci/check-srcinfo.sh          # fails if either drifted

bun run format:check            # prettier --check, add --write to fix
bun run lint:md
```

## How it fits together

Two PKGBUILDs, one repo, same convention the AUR itself uses for a
stable/rolling pair:

- `PKGBUILD` at the repo root — the **stable** package, `pkgname=example`,
  building from a tagged release tarball.
- `example-git/PKGBUILD` — the **rolling** `-git` package, always building
  off `main`.

Both currently package this template repository's own trivial demo
(`example.sh` + `Makefile`) rather than a real project, so CI has something
real to build and lint on every push instead of a PKGBUILD nothing ever
exercises. See the comment at the top of each `PKGBUILD` and of
`example.sh` for what to replace when adapting this template. `README.md`
covers the two-channel design itself and how to publish to the AUR.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):
`type(scope): description`, types `feat`/`fix`/`docs`/`style`/`refactor`/
`perf`/`test`/`build`/`ci`/`chore`/`revert`. Subject under 50 characters,
lowercase, no trailing full stop. commitlint enforces the shape at
commit-msg and again in CI; the length and case rules are tighter than what
it checks, so hold to them anyway.

## Branching, review, and release

Every change goes through a pull request — nothing is pushed straight to
`main`, including the bootstrapping that built this repo. Branch protection
on `main` requires a pull request before merging.

Once a pull request's checks are green, squash-merge it and delete the
branch. [release-please](https://github.com/googleapis/release-please) reads
the Conventional Commits on `main` and, when there's something to release,
opens (or updates) a release pull request of its own proposing the next
version. Merging that pull request is what actually cuts the tag and the
GitHub release — see `README.md`'s "Two release channels" section for what
that tag means for the stable `PKGBUILD`.
