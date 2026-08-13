#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/filesystem/recipe.yml

fail()
{
    printf '%s\n' "pkgsrc-core-native: filesystem boundary: $*" >&2
    exit 1
}

[ -f "$recipe" ] || fail 'missing filesystem/recipe.yml'

extra=$(find "$root/filesystem" -mindepth 1 -maxdepth 1 -type f ! -name recipe.yml -print)
[ -z "$extra" ] || fail 'filesystem carries package-local configuration/source files'

for required in \
    'sources: []' \
    'ln -s usr/bin "$PKG_DESTDIR/bin"' \
    'ln -s usr/sbin "$PKG_DESTDIR/sbin"' \
    'ln -s usr/lib "$PKG_DESTDIR/lib"' \
    'ln -s ../run "$PKG_DESTDIR/var/run"' \
    'ln -s ../proc/self/mounts "$PKG_DESTDIR/etc/mtab"'
do
    grep -Fq "$required" "$recipe" || fail "missing required native hierarchy line: $required"
done

for forbidden in \
    'PKG_SOURCE_ROOT' \
    'mknod ' \
    '/usr/var' \
    'var/ftp' \
    'var/www' \
    'var/empty' \
    'var/log/old' \
    'var/spool/mail' \
    'var/mail' \
    'passwd' \
    'shadow' \
    'securetty' \
    'fstab' \
    'mime.types'
do
    if grep -Fq "$forbidden" "$recipe"; then
        fail "forbidden configuration/service/device authority: $forbidden"
    fi
done
