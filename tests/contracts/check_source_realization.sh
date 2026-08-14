#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

fail()
{
    printf '%s\n' "pkgsrc-core-native: source realization contract: $*" >&2
    exit 1
}

# Recipe programs do not interpret raw fetched archive bytes. Archive
# realization is explicit source authority and is performed before execution.
if grep -R -n -E 'tar .*-[^ ]*x[^ ]* .*\$PKG_SOURCE_ROOT|tar .*\$PKG_SOURCE_ROOT.*-[^ ]*x' \
    "$root"/*/recipe.yml >/dev/null 2>&1; then
    grep -R -n -E 'tar .*-[^ ]*x[^ ]* .*\$PKG_SOURCE_ROOT|tar .*\$PKG_SOURCE_ROOT.*-[^ ]*x' \
        "$root"/*/recipe.yml >&2 || true
    fail 'recipe-local source archive extraction remains'
fi

for package in \
    acl attr glibc-bootstrap glibc libgcc linux-api-headers lz4 scdoc xz zlib zstd
do
    recipe=$root/$package/recipe.yml
    grep -F '    unpack: archive' "$recipe" >/dev/null ||
        fail "$package does not declare archive realization authority"
done

# Empty/raw source declarations remain valid and do not need negative ceremony.
! grep -R -n -E 'unpack:[[:space:]]*(false|none)' "$root"/*/recipe.yml >/dev/null 2>&1 ||
    fail 'raw source semantics are encoded as negative unpack ceremony'

grep -F 'archive realization is explicit source authority' "$root/DESIGN.md" >/dev/null ||
    fail 'design does not state explicit source realization authority'
grep -F 'filename extension, locator, MIME type, or local name' "$root/DESIGN.md" >/dev/null ||
    fail 'design does not reject filename-derived source semantics'

printf '%s\n' 'source realization contract: ok'
