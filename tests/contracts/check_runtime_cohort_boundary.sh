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
require_text "$recipe" 'gcc_include=$(gcc -print-file-name=include)'
require_text "$recipe" '-nostdinc'
require_text "$recipe" '-isystem "$libc/usr/include"'
require_text "$recipe" '-c cohort.c'
require_text "$recipe" 'ld \'
require_text "$recipe" '--dynamic-linker /lib64/ld-linux-x86-64.so.2'
require_text "$recipe" '-z nodefaultlib'
for member in crt1.o crti.o crtn.o libc.so.6 libc_nonshared.a; do
  require_text "$recipe" "\$libc/usr/lib/$member"
done
require_text "$recipe" '"$libgcc/usr/lib/libgcc_s.so.1"'
require_text "$recipe" '--as-needed'
require_text "$recipe" '"$libc/usr/lib/ld-linux-x86-64.so.2"'
require_text "$recipe" '--no-as-needed'
require_text "$recipe" 'probe NEEDED cardinality differs from exact runtime cohort'
require_text "$recipe" 'probe directly requires loader DSO instead of naming only PT_INTERP'
gcc_driver_count=$(grep -Fc -- '    gcc \' "$recipe")
[ "$gcc_driver_count" -eq 1 ] ||
  fail 'runtime-cohort probe must invoke the seed GCC driver exactly once for compilation'
ld_driver_count=$(grep -Fc -- '    ld \' "$recipe")
[ "$ld_driver_count" -eq 1 ] ||
  fail 'runtime-cohort probe must invoke direct ld exactly once for final link'
loader_link_count=$(grep -Fc -- '      "$libc/usr/lib/ld-linux-x86-64.so.2" \' "$recipe")
[ "$loader_link_count" -eq 1 ] ||
  fail 'runtime-cohort probe must admit the package-owned loader exactly once at link time'
if grep -F -- 'gcc cohort.c -Wl,' "$recipe" >/dev/null; then
  fail 'runtime-cohort probe still delegates final link authority to the seed GCC driver'
fi
if grep -E -- '^[[:space:]]+(-L[^[:space:]]*|-l(c|gcc_s))([[:space:]\\]|$)' "$recipe" >/dev/null; then
  fail 'runtime-cohort probe resolves final libraries through linker search instead of exact package paths'
fi
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
require_text "$recipe" 'sealed probe NEEDED cardinality differs from exact runtime cohort'
require_text "$recipe" 'sealed probe directly requires loader DSO instead of naming only PT_INTERP'
require_text "$recipe" 'sealed probe names the wrong interpreter ABI'
require_text "$recipe" 'sealed probe carries RPATH/RUNPATH'
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
require_text "$harness" 'check_archive_member "$path" usr/lib/crt1.o'
require_text "$harness" 'check_archive_member "$path" usr/lib/crti.o'
require_text "$harness" 'check_archive_member "$path" usr/lib/crtn.o'
require_text "$harness" 'check_archive_member "$path" usr/lib/libc_nonshared.a'
require_text "$harness" 'published probe NEEDED cardinality differs from exact runtime cohort'
require_text "$harness" 'published probe directly requires loader DSO instead of naming only PT_INTERP'
require_text "$harness" 'published probe permits default runtime library search'
require_text "$root/README.md" 'private `runtime-cohort-probe`'
require_text "$root/README.md" 'compilation suppresses seed system headers'
require_text "$root/DESIGN.md" 'runtime-cohort probe is qualification machinery'
require_text "$root/DESIGN.md" '`-nostdinc` suppresses its system'
require_text "$root/DESIGN.md" 'exactly the final libc/libgcc'
require_text "$root/DESIGN.md" 'NEEDED set, `NODEFLIB`'

printf '%s\n' 'runtime cohort boundary contract: ok'
