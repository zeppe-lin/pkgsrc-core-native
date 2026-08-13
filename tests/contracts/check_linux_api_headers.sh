#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/linux-api-headers/recipe.yml

fail()
{
    printf '%s\n' "pkgsrc-core-native: linux-api-headers contract: $*" >&2
    exit 1
}

require_text()
{
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null ||
        fail "$file lacks required text: $text"
}

[ -f "$recipe" ] || fail 'missing linux-api-headers/recipe.yml'

require_text "$recipe" 'format: zeppe-lin.recipe/1'
require_text "$recipe" 'name: linux-api-headers'
require_text "$recipe" 'version: 7.1.8'
require_text "$recipe" 'release: 1'
require_text "$recipe" 'GPL-2.0 WITH Linux-syscall-note'
require_text "$recipe" 'requirements: {}'
require_text "$recipe" 'url: https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.8.tar.xz'
require_text "$recipe" 'name: linux-7.1.8.tar.xz'
require_text "$recipe" 'sha256: ff01dcb449279d5b4cfccdb01fee639cf5ff1803f1749a77844dd33915422c49'
require_text "$recipe" 'make -j "$PKG_JOBS" ARCH=x86_64 headers'
require_text "$recipe" 'mkdir -p "$PKG_DESTDIR/usr/include"'
require_text "$recipe" "find . \\( -type f -o -type l \\) -name '*.h' -print"
require_text "$recipe" 'tar -cf - -T -'
require_text "$recipe" 'build: [x86_64]'
require_text "$recipe" 'target: [x86_64]'

# Upstream headers_install adds an rsync copy phase. The native recipe consumes
# the already-sanitized output of `make headers` instead so this first package
# does not silently enlarge the bootstrap seed with an otherwise-unused rsync.
if grep -F -- 'headers_install' "$recipe" >/dev/null; then
    fail 'recipe uses headers_install and therefore adds rsync to the seed surface'
fi
if grep -F -- 'PKG_BUILD_INPUT_ROOT' "$recipe" >/dev/null; then
    fail 'foundation recipe invents package inputs before they exist'
fi

require_text "$root/DESIGN.md" 'first package-owned bootstrap input is `linux-api-headers`'
require_text "$root/DESIGN.md" '$PKG_BUILD_INPUT_ROOT/linux-api-headers/usr/include'
require_text "$root/DESIGN.md" 'not a fabricated runtime requirement'

printf '%s\n' 'linux-api-headers contract: ok'
