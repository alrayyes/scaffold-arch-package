#!/usr/bin/env bash
# The thing being packaged. A template needs something real to build and
# install, or PKGBUILD's build()/package() functions are untested prose —
# swap this (and Makefile) for your own project's actual build when you
# adapt this template; everything else about the packaging stays the same.
set -euo pipefail

echo "example: hello from the scaffold-arch-package demo package"
