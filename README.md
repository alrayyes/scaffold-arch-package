# scaffold-arch-package

A [GitHub template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)
for packaging a project as an Arch Linux (`pacman`) package: two working
`PKGBUILD`s, CI that actually builds and lints both, and everything needed
to publish the result to the AUR.

It's the GitHub-native sibling of
[`alrayyes/scaffold-arch-package`](https://git.higherlearning.eu/alrayyes/scaffold-arch-package)
on Forgejo — same packaging design, `.github/workflows/` instead of
`.forgejo/workflows/`, [release-please](https://github.com/googleapis/release-please)
instead of semantic-release, [Dependabot](https://docs.github.com/en/code-security/dependabot)
instead of Renovate.

## Using this template

Click **Use this template** on GitHub, or:

```sh
gh repo create <your-project> --template alrayyes/scaffold-arch-package --public
```

Then adapt it to your project:

1. Replace `pkgname=example` in `PKGBUILD` and `example-git/PKGBUILD` with
   your project's actual package name, and update `pkgdesc`, `url`,
   `license`, `depends`/`makedepends`, and `source` to point at your own
   repository.
2. Replace `build()`/`package()` in both `PKGBUILD`s with your project's
   real build steps — the committed ones just run `make`/`make install`
   against this template's own trivial demo (`example.sh` + `Makefile`), so
   CI has something real to exercise. Delete `example.sh` and `Makefile`
   once your project's own build stands in for them.
3. Regenerate `.SRCINFO` for both packages (see "Everyday commands" below)
   and commit it alongside the `PKGBUILD` change — CI fails the build if
   they've drifted apart.
4. Update this README's own content for your project — the sections below
   describe the packaging pattern this template gives you, not your
   project.

## Two release channels

Real Arch users expect a choice between two package families, and the AUR's
own naming convention already distinguishes them:

- **`example`** (`PKGBUILD` at the repo root) — the **stable** channel.
  Builds from a tagged GitHub release: `source=` points at GitHub's
  tag-archive endpoint
  (`https://github.com/<owner>/<repo>/archive/refs/tags/v$pkgver.tar.gz`),
  and `pkgver` tracks whatever tag was last cut. This is what most users
  install: it only moves when a release ships.
- **`example-git`** (`example-git/PKGBUILD`) — the **rolling** channel,
  the standard AUR `-git` convention. Always builds off `main`:
  `source=` is a `git+https://...#branch=main` URL, and `pkgver()` derives
  a version string from `git describe` (or a `r<commits>.<short-sha>`
  fallback when there's no tag yet) every time it's rebuilt.
  `provides=("example")` and `conflicts=("example")` tell pacman the two
  are the same package for dependency resolution, so someone can only ever
  have one installed — whichever channel they picked.

Both are normal, coexisting things to publish on the AUR; plenty of
projects ship both so a user can pick "stable" or "always current" for
themselves.

**What cuts the tag the stable channel tracks**: this repo's
`release-please.yml` workflow. `PKGBUILD`'s `pkgver` line carries a
`# x-release-please-version` marker (see `release-please-config.json`'s
`extra-files` entry), so every release-please release bumps it to match the
tag automatically. That bump does **not** regenerate `.SRCINFO` or the
`sha256sums` on its own — do both by hand after merging a release-please
pull request:

```sh
updpkgsums                          # real checksum against the new tag's tarball
makepkg --printsrcinfo > .SRCINFO   # after PKGBUILD's pkgver AND sha256sums changed
```

`updpkgsums` first, `.SRCINFO` last — reversing this order regenerates `.SRCINFO`
against the old checksum and leaves it stale on the `sha256sums` line alone,
which `check-srcinfo.sh` then fails on separately from the `pkgver` drift it's
actually meant to catch.

(`updpkgsums` ships in `pacman-contrib`.) `example-git` needs none of this —
it has no release step; it always builds off whatever `main` currently is.

## Everyday commands

```sh
bun install                              # linters + git hooks

shellcheck .ci/*.sh
namcap PKGBUILD
namcap example-git/PKGBUILD

makepkg --printsrcinfo > .SRCINFO                    # stable
(cd example-git && makepkg --printsrcinfo > .SRCINFO) # rolling
./.ci/check-srcinfo.sh                                # fails on drift

makepkg -si                              # build + install, stable
(cd example-git && makepkg -si)          # build + install, rolling

bun run format:check                     # prettier --check, add --write to fix
bun run lint:md
```

`makepkg` refuses to run as root, and building either package needs a real
Arch userland — most contributors' machines aren't one, so CI runs both
inside a pinned `archlinux:base-devel` container
(`.ci/build-and-lint.sh`) rather than expecting `makepkg`/`namcap` on your
`PATH`. See `CONTRIBUTING.md` for the full local setup.

## Publishing to the AUR

The AUR has no sponsorship requirement — any registered user can push a new
package. Once per package name:

1. [Create an AUR account](https://aur.archlinux.org/register) if you don't
   have one, and [add an SSH public key](https://aur.archlinux.org/account)
   to it under **My Account**.
2. Clone the (currently empty) AUR repo for the package name — once for
   each channel:

   ```sh
   git clone ssh://aur@aur.archlinux.org/example.git aur-example
   git clone ssh://aur@aur.archlinux.org/example-git.git aur-example-git
   ```

3. Copy in the matching `PKGBUILD` and `.SRCINFO`:

   ```sh
   cp PKGBUILD .SRCINFO aur-example/
   cp example-git/PKGBUILD example-git/.SRCINFO aur-example-git/
   ```

4. Commit and push each:

   ```sh
   cd aur-example && git add PKGBUILD .SRCINFO && \
     git commit -m "release: v0.1.0" && git push
   ```

Repeat step 4 in `aur-example-git` whenever `example-git/PKGBUILD` changes
meaningfully (its own `pkgver` doesn't need a commit — `pkgver()` recomputes
it at build time on the installer's own machine).

**Optional: auto-push on release.** CI could push the stable package to its
AUR remote automatically whenever release-please cuts a tag — add a step to
`release-please.yml` that clones the AUR repo over SSH and pushes the
regenerated `PKGBUILD`/`.SRCINFO`, using a maintainer's own AUR SSH key
stored as a repository secret (`AUR_SSH_PRIVATE_KEY` or similar). This
template doesn't wire that up — the AUR ties a package to one person's
account and key, which isn't something a generic template should assume or
automate on your behalf.

## Labels, branch protection

`main` requires a pull request before merging — nothing merges without a
passing `ci` run. Dependabot watches `package.json` (via the `npm`
ecosystem) and the GitHub Actions pins in `.github/workflows/`, both weekly.
