#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/tests/fixtures/collections/bootstrap-seed-probe/seed-probe/recipe.yml
fail() { printf 'bootstrap-seed-probe-contract: %s\n' "$*" >&2; exit 1; }
require_text()
{
  grep -F -- "$2" "$1" >/dev/null || fail "$1 lacks required probe: $2"
}

[ -f "$recipe" ] || fail 'committed seed-probe recipe is absent'
require_text "$recipe" 'name: seed-probe'
require_text "$recipe" 'requirements: {}'
require_text "$recipe" 'sources: []'
require_text "$recipe" '[ -c /dev/null ]'
require_text "$recipe" '[ "$TMPDIR" = /tmp ]'
require_text "$recipe" '[ "$HOME" = /build/work/home ]'
require_text "$recipe" '/bin/sh -c'
require_text "$recipe" 'bison -o parser.c parser.y'
require_text "$recipe" 'flex -o scanner.c scanner.l'
require_text "$recipe" 'g++ -std=c++14 conftest.cc'
require_text "$recipe" 'g++ -std=c++14 multiprecision.cc -lmpc -lmpfr -lgmp'
require_text "$recipe" 'make -f Makefile'
require_text "$recipe" 'sha256sum "$PKG_PACKAGE_ROOT/seed-probe.ok"'
require_text "$recipe" 'readelf -h "$PKG_PACKAGE_ROOT/usr/libexec/seed-probe"'
require_text "$recipe" '[ "$HOME" = /tmp/home ]'
require_text "$root/README.md" 'make bootstrap-qualify BOOTSTRAP_PRIVILEGE=sudo'
require_text "$root/README.md" 'one real `pkgctl build seed-probe --check`'
require_text "$root/DESIGN.md" 'File existence is not executable authority.'
require_text "$root/DESIGN.md" 'separate checked `seed-probe` transaction'
if grep -E -- '(^|[[:space:]])(curl|wget|git|ssh)([[:space:]]|$)' "$recipe" >/dev/null; then
  fail 'seed probe reaches network/acquisition tooling'
fi

printf '%s\n' 'bootstrap seed probe contract: ok'
