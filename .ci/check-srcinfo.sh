#!/usr/bin/env bash
# Regenerates .SRCINFO for both packages and fails on drift. The same script
# runs at pre-push and in CI, so the two cannot disagree about what counts as
# stale. Needs `makepkg` on PATH — present on any Arch install, and the CI
# job runs it inside the pinned archlinux container.
set -euo pipefail

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
