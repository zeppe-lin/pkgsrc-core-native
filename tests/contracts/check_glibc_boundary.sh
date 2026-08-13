#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/glibc/recipe.yml

fail()
{
    printf '%s\n' "pkgsrc-core-native: glibc contract: $*" >&2
    exit 1
}

require_text()
{
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null ||
        fail "$file lacks required text: $text"
}

[ -f "$recipe" ] || fail 'missing glibc/recipe.yml'

require_text "$recipe" 'format: zeppe-lin.recipe/1'
require_text "$recipe" 'name: glibc'
require_text "$recipe" 'version: 2.44'
require_text "$recipe" 'release: 1'
require_text "$recipe" 'GPL-2.0-or-later'
require_text "$recipe" 'LGPL-2.1-or-later'
require_text "$recipe" 'url: https://ftp.gnu.org/gnu/glibc/glibc-2.44.tar.xz'
require_text "$recipe" 'sha256: 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667'

count=$(grep -F -- '- package: linux-api-headers' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'glibc must have exactly one linux-api-headers package edge'
count=$(grep -F -- '- package: libgcc' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'glibc must retain its exact libgcc runtime edge'
require_text "$recipe" 'headers="$PKG_BUILD_INPUT_ROOT/linux-api-headers/usr/include"'
require_text "$recipe" '--with-headers="$headers"'

# Kernel ABI authority must come from the sealed package input, never the seed
# root and never another embedded Linux source archive.
if grep -F -- '--with-headers=/usr/include' "$recipe" >/dev/null; then
    fail 'glibc falls back to seed-root kernel headers'
fi
if grep -E -- 'linux-[0-9].*tar' "$recipe" >/dev/null; then
    fail 'glibc embeds a second kernel source instead of consuming linux-api-headers'
fi

# Keep the traditional x86_64 interpreter ABI while storing its bytes beneath
# the merged /usr hierarchy owned by the filesystem package.
require_text "$recipe" '--sysconfdir=/etc'
require_text "$recipe" '--localstatedir=/var'
require_text "$recipe" 'libc_cv_slibdir=/usr/lib'
require_text "$recipe" 'libc_cv_rtlddir=/lib64'
require_text "$recipe" 'test -e "$PKG_DESTDIR/usr/lib/ld-linux-x86-64.so.2"'

# Service/configuration/timezone policy does not become libc authority merely
# because historical base packages placed those files beside libc.
require_text "$recipe" '--disable-build-nscd'
require_text "$recipe" '--disable-timezone-tools'
require_text "$recipe" 'rm -rf "$PKG_DESTDIR/etc" "$PKG_DESTDIR/var"'
for name in hosts resolv.conf nsswitch.conf host.conf ld.so.conf localtime nscd.conf; do
    if grep -E -- "(^|[ /])${name}([ \"']|$)" "$recipe" >/dev/null; then
        fail "glibc recipe carries machine/service policy: $name"
    fi
done

# These upstream helpers require shell/Perl runtime authority. Keep this first
# libc package closure-free rather than hiding undeclared interpreter edges.
for name in ldd mtrace sotruss xtrace; do
    require_text "$recipe" "\"\$PKG_DESTDIR/usr/bin/$name\""
done

require_text "$recipe" 'build: [x86_64]'
require_text "$recipe" 'target: [x86_64]'
require_text "$root/DESIGN.md" 'glibc` is the first consumer of that package-owned kernel ABI authority'
require_text "$root/DESIGN.md" 'linker/runtime objects and glibc static data. It does not absorb host'
require_text "$root/DESIGN.md" 'configuration, timezone policy, locale policy, or nscd service state.'
require_text "$root/DESIGN.md" '/lib64/ld-linux-x86-64.so.2'
require_text "$root/DESIGN.md" '`glibc` therefore records an explicit'
require_text "$root/DESIGN.md" '`run -> libgcc` edge now. That target-runtime authority is intentionally'
require_text "$root/DESIGN.md" 'unresolved until the native `libgcc` recipe exists'

printf '%s\n' 'glibc boundary contract: ok'
