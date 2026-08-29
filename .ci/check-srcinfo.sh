#!/usr/bin/env bash
# Regenerates .SRCINFO for both packages and fails on drift. The same script
# runs at pre-push and in CI, so the two cannot disagree about what counts as
# stale. Needs `makepkg` on PATH — present on any Arch install, and the CI
# job runs it inside the pinned archlinux container.
set -euo pipefail

# makepkg refuses to run as root even just to print .SRCINFO — fine locally
# (nobody develops as root), not fine in CI's container, which starts as
# root. Re-exec as an unprivileged user there instead of duplicating this
# whole script's logic inside `su`.
if [ "$(id -u)" -eq 0 ]; then
  if ! id builder &>/dev/null; then
    useradd -m builder
  fi
  chown -R builder:builder "$(pwd)"
  exec su builder -c "$0 $*"
fi

status=0

for dir in . example-git; do
  before="$(cat "$dir/.SRCINFO")"
  after="$(cd "$dir" && makepkg --printsrcinfo)"

  if [ "$before" != "$after" ]; then
    echo "::error::$dir/.SRCINFO is stale — regenerate with:" >&2
    echo "  (cd $dir && makepkg --printsrcinfo > .SRCINFO)" >&2
    diff <(echo "$before") <(echo "$after") || true
    status=1
  fi
done

exit "$status"
