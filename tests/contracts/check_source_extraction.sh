#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

fail()
{
    printf '%s\n' "pkgsrc-core-native: source extraction contract: $*" >&2
    exit 1
}

# Source archive ownership and privileged permission restoration are not
# construction authority. Every tar extraction must state the invariant
# explicitly so execution as uid 0 cannot silently change semantics.
for recipe in "$root"/*/recipe.yml; do
    awk -v recipe="$recipe" '
        index($0, "tar ") && index($0, " -xf ") {
            if (!index($0, "--no-same-owner") ||
                !index($0, "--no-same-permissions")) {
                printf "%s:%d: unbounded tar extraction: %s\n", recipe, NR, $0 > "/dev/stderr"
                bad = 1
            }
        }
        END { exit bad ? 1 : 0 }
    ' "$recipe" || fail 'tar extraction may restore archive owner or privileged permissions'
done

grep -F -- 'archive ownership is not construction authority' "$root/DESIGN.md" >/dev/null ||
    fail 'design does not state source archive ownership boundary'
grep -F -- '--no-same-owner --no-same-permissions' "$root/DESIGN.md" >/dev/null ||
    fail 'design does not state explicit tar extraction policy'

printf '%s\n' 'source extraction contract: ok'
