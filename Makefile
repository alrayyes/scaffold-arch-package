# Minimal, generic `make install` that PKGBUILD's build()/package()
# functions call — see the comment at the top of example.sh for why this
# exists. Swap it for your own project's real build system.
PREFIX ?= /usr
DESTDIR ?=

.PHONY: build install uninstall clean

build:
	@true

install: build
	install -Dm755 example.sh "$(DESTDIR)$(PREFIX)/bin/example"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/example/LICENSE"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/example"
	rm -f "$(DESTDIR)$(PREFIX)/share/licenses/example/LICENSE"

clean:
	@true
