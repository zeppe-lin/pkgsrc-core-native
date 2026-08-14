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
require_text "$recipe" 'GPL-2.0 WITH Linux-syscall-note'
require_text "$recipe" 'GPL-2.0-or-later'
require_text "$recipe" 'LGPL-2.1-or-later'
require_text "$recipe" 'url: https://ftp.gnu.org/gnu/glibc/glibc-2.44.tar.xz'
require_text "$recipe" 'sha256: 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667'

count=$(grep -F -- '- package: linux-api-headers' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'bootstrap sysroot must have exactly one linux-api-headers build edge'
if grep -E -- '^  (run|check|lifecycle):' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot must not claim target/check/lifecycle package closure'
fi

require_text "$recipe" 'linux_headers="$PKG_BUILD_INPUT_ROOT/linux-api-headers/usr/include"'
require_text "$recipe" 'cd "$linux_headers"'
require_text "$recipe" 'cd "$PKG_DESTDIR/usr/include"'
require_text "$recipe" '--with-headers="$linux_headers"'
if grep -F -- '--with-headers=/usr/include' "$recipe" >/dev/null; then
    fail 'bootstrap glibc falls back to seed-root kernel headers'
fi
if grep -E -- 'linux-[0-9].*tar' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot embeds a kernel source instead of consuming linux-api-headers'
fi

# This package is the bounded pre-libgcc sysroot, not a second full libc.
if grep -F -- 'install-bootstrap-headers' "$recipe" >/dev/null; then
    fail 'bootstrap recipe relies on a non-upstream install-bootstrap-headers knob'
fi
require_text "$recipe" 'install_root="$PKG_DESTDIR"'
require_text "$recipe" 'install-headers'
require_text "$recipe" ': > bootstrap-stubs.h'
require_text "$recipe" 'install -m 0644 bootstrap-stubs.h "$PKG_DESTDIR/usr/include/gnu/stubs.h"'
require_text "$recipe" 'csu/subdir_lib'
for object in crt1.o crti.o crtn.o; do
    require_text "$recipe" "csu/$object"
done
require_text "$recipe" 'cc -nostdlib -nostartfiles -shared -x c'
require_text "$recipe" '-o "$PKG_DESTDIR/usr/lib/libc.so"'
require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/include/gnu/stubs.h"'
require_text "$recipe" 'test -f "$PKG_DESTDIR/usr/include/linux/types.h"'

# A full libc build/install here would collapse bootstrap and final runtime
# authority and reintroduce the glibc <-> libgcc construction cycle.
if grep -E -- 'make( -j "\$PKG_JOBS")?([[:space:]]+[^#]*)?[[:space:]]install_root="\$PKG_DESTDIR"[[:space:]]+install$' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot performs a full glibc install'
fi
if grep -F -- 'test -e "$PKG_DESTDIR/usr/lib/ld-linux-x86-64.so.2"' "$recipe" >/dev/null; then
    fail 'bootstrap sysroot is claiming final dynamic-loader authority'
fi
for path in '/etc' '/var' '/usr/share/locale'; do
    if grep -F -- "PKG_DESTDIR$path" "$recipe" >/dev/null; then
        fail "bootstrap sysroot carries final runtime/policy tree: $path"
    fi
done

require_text "$recipe" 'build: [x86_64]'
require_text "$recipe" 'target: [x86_64]'
require_text "$root/DESIGN.md" '`glibc-bootstrap` is a construction-only bootstrap sysroot authority.'
require_text "$root/DESIGN.md" 'an alternate libc runtime package'
require_text "$root/DESIGN.md" 'one pre-libgcc sysroot: Linux UAPI headers, glibc bootstrap headers, the startup'
require_text "$root/DESIGN.md" 'future `libgcc` recipe must consume this package as an exact build input'

printf '%s\n' 'glibc-bootstrap boundary contract: ok'
