#!/usr/bin/env bash
# Builds and namcap-lints one package directory ("." for stable, "example-git"
# for rolling), inside the pinned archlinux container this runs under in CI.
# makepkg refuses to run as root, so this creates an unprivileged build user
# and hands off to it for everything past the one-time root-only setup below.
set -euo pipefail

dir="${1:?usage: build-and-lint.sh <package-dir>}"
repo_root="$(pwd)"

pacman -Syu --noconfirm --needed namcap git

if ! id builder &>/dev/null; then
  useradd -m builder
fi
chown -R builder:builder "$repo_root"
git config --global --add safe.directory "$repo_root"

# The stable PKGBUILD downloads a tagged release tarball. On a freshly
# bootstrapped template — or any project before its first tag — that source
# doesn't exist yet on GitHub. Stand in a tarball built from the current
# checkout so build()/package() still get exercised on every push; a real
# project only needs this crutch until its first real release ships.
#
# That "until" has to be checked, not assumed: once a real release exists,
# this crutch's own git-archive tarball has a different byte layout than
# GitHub's own archive endpoint, so it can never match a real sha256sum
# from `updpkgsums` — and since it's placed at the exact local filename
# makepkg expects, makepkg finds it and never even attempts the real
# download, so the mismatch only surfaces as a checksum failure, with no
# hint that a stand-in tarball is the actual cause. Try the real source
# first; only fall back to the stand-in when it genuinely doesn't exist yet.
if [ "$dir" = "." ]; then
  pkgname=$(awk -F= '/^pkgname=/{print $2; exit}' "$dir/PKGBUILD")
  pkgver=$(awk -F= '/^pkgver=/{print $2; exit}' "$dir/PKGBUILD" | awk '{print $1}')
  # source=() is a real bash array; sourcing the PKGBUILD (after pkgname/
  # pkgver are already known, so the array expands correctly) is the only
  # way to read it that can't drift from what makepkg itself will resolve -
  # a second hardcoded copy of the URL pattern here would be exactly the
  # kind of duplicate that goes stale unnoticed.
  source_url=$(
    cd "$dir" && pkgname="$pkgname" pkgver="$pkgver" bash -c '
      source PKGBUILD
      echo "${source[0]#*::}"
    '
  )
  if ! curl --fail --silent --show-error --output /dev/null --head "$source_url"; then
    echo "no real release at $source_url yet - building a stand-in tarball from HEAD"
    archive_dir="scaffold-arch-package-$pkgver"
    work=$(mktemp -d)
    mkdir -p "$work/$archive_dir"
    git archive HEAD | tar -x -C "$work/$archive_dir"
    tar -C "$work" -czf "$dir/$pkgname-$pkgver.tar.gz" "$archive_dir"
    chown builder:builder "$dir/$pkgname-$pkgver.tar.gz"
    rm -rf "$work"
  else
    echo "real release found at $source_url - letting makepkg download it for real"
  fi
fi

# namcap always exits 0 regardless of what it finds — it's a linter, not a
# checker with a pass/fail contract — so failing the job on a real ("E:")
# finding is this script's job, not namcap's. A "W:" warning is printed but
# doesn't fail the run; some are expected and permanent here, like namcap
# flagging the stable package's demo script as "not an ELF binary" on an
# arch it declares as if it built one.
su builder -c "
  set -euo pipefail
  cd '$repo_root/$dir'
  namcap PKGBUILD | tee /tmp/namcap-pkgbuild.out
  makepkg --syncdeps --noconfirm
  namcap ./*.pkg.tar.zst | tee /tmp/namcap-pkg.out
  ! grep -qE ' E: ' /tmp/namcap-pkgbuild.out /tmp/namcap-pkg.out
"
