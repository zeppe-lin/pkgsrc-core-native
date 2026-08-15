#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/libgcc/recipe.yml

fail()
{
    printf '%s\n' "pkgsrc-core-native: libgcc contract: $*" >&2
    exit 1
}

require_text()
{
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null ||
        fail "$file lacks required text: $text"
}

[ -f "$recipe" ] || fail 'missing libgcc/recipe.yml'

require_text "$recipe" 'format: zeppe-lin.recipe/1'
require_text "$recipe" 'name: libgcc'
require_text "$recipe" 'version: 16.1.0'
require_text "$recipe" 'release: 1'
require_text "$recipe" 'summary: GCC low-level runtime library'
require_text "$recipe" 'GPL-3.0-or-later WITH GCC-exception-3.1'
require_text "$recipe" 'url: https://ftp.gnu.org/gnu/gcc/gcc-16.1.0/gcc-16.1.0.tar.xz'
require_text "$recipe" 'sha256: 50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79'

count=$(grep -E -- '^    - package: glibc-bootstrap$' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'libgcc must have exactly one glibc-bootstrap build edge'
count=$(grep -E -- '^    - package: glibc$' "$recipe" | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail 'libgcc must have exactly one final glibc runtime edge'
if grep -F -- '- package: linux-api-headers' "$recipe" >/dev/null; then
    fail 'libgcc bypasses its sealed bootstrap sysroot with a second header input'
fi

require_text "$recipe" 'sysroot="$PKG_BUILD_INPUT_ROOT/glibc-bootstrap"'
require_text "$recipe" '--with-sysroot="$sysroot"'
require_text "$recipe" '--with-native-system-header-dir=/usr/include'
require_text "$recipe" '--with-slibdir=/usr/lib'
require_text "$recipe" '--disable-multilib'
require_text "$recipe" '--enable-languages=c'
require_text "$recipe" '--enable-shared'
require_text "$recipe" 'all-gcc'
require_text "$recipe" 'all-target-libgcc'
require_text "$recipe" 'install-target-libgcc'

# This package publishes the shared low-level runtime only. Compiler drivers,
# libstdc++, GCC private static runtime objects, and other target libraries stay
# outside its artifact.
require_text "$recipe" 'find "$stage" -name libgcc_s.so.1 -print'
require_text "$recipe" 'install -m 0755 "$runtime" "$PKG_DESTDIR/usr/lib/libgcc_s.so.1"'
if grep -E -- 'make([^#]*)[[:space:]]install([[:space:]]|$)' "$recipe" | grep -v -- 'install-target-libgcc' >/dev/null; then
    fail 'libgcc recipe performs an unbounded GCC install'
fi
for payload in '/usr/bin/gcc' '/usr/bin/g++' 'libstdc++' 'libasan' 'libatomic'; do
    if grep -F -- "PKG_DESTDIR$payload" "$recipe" >/dev/null; then
        fail "libgcc claims non-libgcc payload: $payload"
    fi
done

require_text "$recipe" 'Library soname: [libgcc_s.so.1]'
require_text "$recipe" 'Shared library: [libc.so.6]'
require_text "$recipe" 'Shared library: [ld-linux-x86-64.so.2]'
require_text "$recipe" '\((RPATH|RUNPATH)\)'
require_text "$recipe" 'check:'
require_text "$recipe" 'ZEPPE_LIN_CHECK_SOURCE/gcc-16.1.0.tar.xz'
require_text "$recipe" 'ZEPPE_LIN_CHECK_ROOT/usr/lib/libgcc_s.so.1'
require_text "$recipe" 'retained GCC source archive digest differs from admitted source'
require_text "$recipe" 'sealed libgcc runtime is absent'
require_text "$recipe" 'sealed libgcc runtime lacks libgcc_s.so.1 SONAME'
require_text "$recipe" 'sealed libgcc runtime carries a build-time search path'
require_text "$recipe" 'build: [x86_64]'
require_text "$recipe" 'target: [x86_64]'

require_text "$root/DESIGN.md" '`glibc` and `libgcc` form the first native runtime cohort.'
require_text "$root/DESIGN.md" '`libgcc build -> glibc-bootstrap`'
require_text "$root/DESIGN.md" '`libgcc run -> glibc`'
require_text "$root/DESIGN.md" '`glibc run -> libgcc`'

printf '%s\n' 'libgcc boundary contract: ok'
