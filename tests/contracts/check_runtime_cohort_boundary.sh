#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
recipe=$root/tests/fixtures/collections/bootstrap-runtime-cohort/runtime-cohort-probe/recipe.yml
harness=$root/tools/bootstrap_campaign.sh
fail() { printf 'runtime-cohort-boundary-contract: %s\n' "$*" >&2; exit 1; }
require_text()
{
  grep -F -- "$2" "$1" >/dev/null || fail "$1 lacks required text: $2"
}

[ -f "$recipe" ] || fail 'private runtime-cohort probe fixture is absent'
[ ! -e "$root/runtime-cohort-probe" ] || fail 'bootstrap probe leaked into public collection membership'
require_text "$recipe" 'name: runtime-cohort-probe'
require_text "$recipe" 'sources: []'
for package in filesystem glibc libgcc; do
  count=$(grep -F -- "- package: $package" "$recipe" | wc -l | tr -d ' ')
  [ "$count" = 2 ] || fail "probe must consume $package exactly once in build and once in check"
done
require_text "$recipe" 'build input vocabulary cardinality differs from cohort authority'
require_text "$recipe" 'build input vocabulary omits cohort authority'
require_text "$recipe" 'filesystem="$PKG_BUILD_INPUT_ROOT/filesystem"'
require_text "$recipe" 'libc="$PKG_BUILD_INPUT_ROOT/glibc"'
require_text "$recipe" 'libgcc="$PKG_BUILD_INPUT_ROOT/libgcc"'
require_text "$recipe" 'gcc cohort.c -Wl,--no-as-needed -lgcc_s -Wl,--as-needed -Wl,-z,nodefaultlib -o cohort-probe'
require_text "$recipe" 'Shared library: [libgcc_s.so.1]'
require_text "$recipe" 'Shared library: [libc.so.6]'
require_text "$recipe" 'Flags:.*NODEFLIB'
require_text "$recipe" '--inhibit-cache'
require_text "$recipe" '/lib64/ld-linux-x86-64.so.2'
require_text "$recipe" '--library-path "$libc/usr/lib:$libgcc/usr/lib" ./cohort-probe'
require_text "$recipe" 'probe="$PKG_PACKAGE_ROOT/usr/libexec/runtime-cohort-probe"'
require_text "$recipe" 'check input vocabulary cardinality differs from cohort authority'
require_text "$recipe" 'check input vocabulary omits cohort authority'
require_text "$recipe" '--library-path "$libc/usr/lib:$libgcc/usr/lib" "$probe"'
require_text "$recipe" 'checked probe package is writable'
require_text "$recipe" 'reconstructed libgcc input is writable'
if grep -E -- '(^|[[:space:]])(curl|wget|git|ssh)([[:space:]]|$)' "$recipe" >/dev/null; then
  fail 'runtime-cohort probe reaches network/acquisition tooling'
fi

require_text "$harness" 'tests/fixtures/collections/bootstrap-runtime-cohort/runtime-cohort-probe'
require_text "$harness" "set -- build runtime-cohort-probe --check"
require_text "$harness" "'goal=build=runtime-cohort-probe,check=runtime-cohort-probe'"
require_text "$harness" 'expected exactly 6'
require_text "$harness" 'for package in filesystem glibc glibc-bootstrap libgcc linux-api-headers runtime-cohort-probe'
require_text "$harness" 'published final glibc/libgcc runtime cohort did not execute'
require_text "$harness" 'published probe permits default runtime library search'
require_text "$root/README.md" 'private `runtime-cohort-probe`'
require_text "$root/DESIGN.md" 'runtime-cohort probe is qualification machinery'

printf '%s\n' 'runtime cohort boundary contract: ok'
