#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/glibc-bootstrap/recipe.yml

fail()
{
    printf '%s\n' "pkgsrc-core-native: glibc-bootstrap contract: $*" >&2
    exit 1
}

require_text()
{
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null ||
        fail "$file lacks required text: $text"
}

[ -f "$recipe" ] || fail 'missing glibc-bootstrap/recipe.yml'

require_text "$recipe" 'format: zeppe-lin.recipe/1'
require_text "$recipe" 'name: glibc-bootstrap'
require_text "$recipe" 'version: 2.44'
require_text "$recipe" 'release: 1'
require_text "$recipe" 'summary: GNU C Library bootstrap sysroot'
require_text "$recipe" 'url: https://ftp.gnu.org/gnu/glibc/glibc-2.44.tar.xz'
require_text "$recipe" 'sha256: 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667'

count=$(grep -F -- '- package: linux-api-headers' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'bootstrap sysroot must have exactly one linux-api-headers build edge'
if grep -E -- '^  (run|check|lifecycle):' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot must not claim target/check/lifecycle package closure'
fi

require_text "$recipe" 'linux_headers="$PKG_BUILD_INPUT_ROOT/linux-api-headers/usr/include"'
require_text "$recipe" '--with-headers="$linux_headers"'
if grep -F -- '--with-headers=/usr/include' "$recipe" >/dev/null; then
    fail 'bootstrap glibc falls back to seed-root kernel headers'
fi
if grep -E -- 'linux-[0-9].*tar' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot embeds a kernel source instead of consuming linux-api-headers'
fi

# The bootstrap package builds a real glibc link surface in a private stage,
# then projects only the compile/link sysroot needed by GCC target runtimes.
require_text "$recipe" 'make -j "$PKG_JOBS"'
require_text "$recipe" 'make install_root="$stage" install'
require_text "$recipe" 'cd "$stage/usr/include"'
require_text "$recipe" 'libc_cv_rtlddir=/lib64'
require_text "$recipe" 'for object in crt1.o crti.o crtn.o; do'
require_text "$recipe" '"$stage/usr/lib/$object"'
require_text "$recipe" '$stage/usr/lib/libc.so"'
require_text "$recipe" '$stage/usr/lib/libc.so.6"'
require_text "$recipe" '$stage/usr/lib/libc_nonshared.a"'
require_text "$recipe" 'loader="$stage/lib64/ld-linux-x86-64.so.2"'
require_text "$recipe" 'ln -s lib "$PKG_DESTDIR/usr/lib64"'
require_text "$recipe" 'ln -s usr/lib64 "$PKG_DESTDIR/lib64"'

# Synthetic libc/stubs bytes are not an acceptable final libgcc link surface.
for forbidden in \
    'bootstrap-stubs.h' \
    'bootstrap-libc.c' \
    'install-bootstrap-headers' \
    '-nostdlib -nostartfiles -shared'; do
    if grep -F -- "$forbidden" "$recipe" >/dev/null; then
        fail "bootstrap sysroot retains synthetic link surface: $forbidden"
    fi
done

# It is construction authority, not a second deployable libc package.
for path in '/etc' '/var' '/usr/share/locale'; do
    if grep -F -- "PKG_DESTDIR$path" "$recipe" >/dev/null; then
        fail "bootstrap sysroot carries target/runtime policy tree: $path"
    fi
done

require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/include/gnu/stubs.h"'
require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/include/linux/types.h"'
require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/lib/libc.so.6"'
require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/lib/ld-linux-x86-64.so.2"'
require_text "$recipe" 'build: [x86_64]'
require_text "$recipe" 'target: [x86_64]'
require_text "$root/DESIGN.md" '`glibc-bootstrap` is a construction-only bootstrap sysroot authority.'
require_text "$root/DESIGN.md" 'real glibc compile/link surface'
require_text "$root/DESIGN.md" 'does not create synthetic libc or loader ABI bytes'
require_text "$root/DESIGN.md" 'must consume `glibc-bootstrap` through `--with-sysroot`'

printf '%s\n' 'glibc-bootstrap boundary contract: ok'
