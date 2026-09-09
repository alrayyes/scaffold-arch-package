#!/usr/bin/env bash
# Regenerates checksums and .SRCINFO in place. check-srcinfo.sh is the
# read-only twin that fails on drift instead of fixing it; the two share the
# same `makepkg --printsrcinfo` call so they can't disagree about the
# target. Needs `makepkg`/`updpkgsums` on PATH, same privilege-drop as
# check-srcinfo.sh.
#
# `.`'s sha256sums go stale the same way .SRCINFO does: release-please bumps
# pkgver but has no idea a checksum needs recomputing against the new
# release tarball. `example-git` has no static source to checksum -- its
# pkgver() function derives the version from `git describe` at build time,
# so there's nothing for updpkgsums to do there.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  pacman -Sy --noconfirm pacman-contrib
  # The bind-mounted checkout keeps its original host uid/gid until this
  # chown -- restore it before exiting, or .git comes out the other side
  # owned by the container's builder uid instead of the host runner's, and
  # the workflow's next (non-container) step fails writing .git/config.
  orig_owner="$(stat -c '%u:%g' .)"
  trap 'chown -R "$orig_owner" .' EXIT
  if ! id builder &>/dev/null; then
    useradd -m builder
  fi
  chown -R builder:builder "$(pwd)"
  su builder -c "$0 $*"
  exit
fi

# codeload.github.com generates tag archives on demand and can lag a
# freshly pushed tag by a few seconds -- updpkgsums downloading that
# tarball to compute its checksum races that lag right after
# release-please tags a release. Confirmed live on v1.0.5: this step
# 404'd, so no checksums-update PR was ever opened and main was left with
# .SRCINFO and sha256sums still pointing at the previous release. Retry
# before giving up, same fix as build-and-lint.sh's own probe.
attempt=0
until (cd . && updpkgsums); do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 5 ]; then
    echo "updpkgsums still failing after $attempt attempts" >&2
    exit 1
  fi
  sleep 3
done

for dir in . example-git; do
  (cd "$dir" && makepkg --printsrcinfo > .SRCINFO)
done
