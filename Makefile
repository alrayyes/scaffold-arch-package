# Minimal, generic `make install` that PKGBUILD's build()/package()
# functions call — see the comment at the top of example.sh for why this
# exists. Swap it for your own project's real build system.
PREFIX ?= /usr
DESTDIR ?=
# The stable and -git PKGBUILDs package the same demo under two different
# pkgnames (example, example-git). namcap requires a LicenseRef license
# file at /usr/share/licenses/<pkgname>/, so this has to track whichever
# one is actually building rather than being hardcoded — PKGBUILD passes
# it in via `make PKGNAME="$pkgname" install`.
PKGNAME ?= example

.PHONY: build install uninstall clean

build:
	@true

install: build
	install -Dm755 example.sh "$(DESTDIR)$(PREFIX)/bin/example"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/$(PKGNAME)/LICENSE"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/example"
	rm -f "$(DESTDIR)$(PREFIX)/share/licenses/$(PKGNAME)/LICENSE"

clean:
	@true
