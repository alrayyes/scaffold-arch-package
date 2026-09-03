#!/usr/bin/env bash
# Every source entry that renames its download ("localname::url") where the
# url embeds $pkgver needs $pkgver in its LOCAL name too, not just the url --
# otherwise makepkg's source cache (keyed by local filename, not the url)
# silently reuses a prior version's already-downloaded file on a version
# bump instead of fetching the new one, and the stale file fails checksum
# against the new PKGBUILD's sha256sums entry. Confirmed live on
# washy-washy-cli-bin's man page asset; see rules/packaging.md.
#
# Pure text inspection, not a real build -- this only needs to catch the
# pattern, not exercise makepkg, and it should be as cheap to run as
# check-srcinfo.sh's own drift check.
set -euo pipefail

status=0
while IFS= read -r line; do
  [[ "$line" =~ \"([^\"]+)::([^\"]+)\" ]] || continue
  localname="${BASH_REMATCH[1]}"
  url="${BASH_REMATCH[2]}"
  # shellcheck disable=SC2016 # literal glob match against "$pkgver", not expansion
  if [[ "$url" == *'$pkgver'* && "$localname" != *'$pkgver'* ]]; then
    echo "::error::PKGBUILD: source entry's local name has no \$pkgver but its URL does:" >&2
    echo "  $line" >&2
    status=1
  fi
done < PKGBUILD

exit "$status"
