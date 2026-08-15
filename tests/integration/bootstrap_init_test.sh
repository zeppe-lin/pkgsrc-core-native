#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
harness=$root/tools/bootstrap_campaign.sh
fail() { printf 'bootstrap-init-test: %s\n' "$*" >&2; exit 1; }

temporary=$(mktemp -d "${TMPDIR:-/tmp}/pkgsrc-core-native-bootstrap-init.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
seed=$temporary/seed
work=$temporary/work
toolchain=$temporary/toolchain
mkdir -p "$seed/bin" "$seed/usr/bin" "$seed/usr/include" "$toolchain/bin" "$toolchain/lib"

# Init only admits these paths; construction tools must not execute before
# pkgctl owns construction.
printf '#!/bin/sh\nexit 0\n' >"$seed/bin/bootstrap-tool"
chmod 0755 "$seed/bin/bootstrap-tool"
ln -s bootstrap-tool "$seed/bin/bash"
ln -s bootstrap-tool "$seed/bin/sh"
for tool in \
  ar as awk basename bison cat cc chmod cp dirname expr find flex g++ gawk gcc \
  grep install ld ln ls m4 make mkdir mv nm objcopy objdump python3 ranlib \
  readelf rm sed sha256sum sort strip tar touch tr uname wc xz; do
  ln -s ../../bin/bootstrap-tool "$seed/usr/bin/$tool"
done
for header in gmp.h mpfr.h mpc.h; do
  : >"$seed/usr/include/$header"
done

cat >"$toolchain/bin/pkgctl" <<'SCRIPT'
#!/bin/sh
exit 97
SCRIPT
chmod 0755 "$toolchain/bin/pkgctl"
cat >"$toolchain/bin/pkgstate-init" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
chmod 0755 "$toolchain/bin/pkgstate-init"

seed_sha=$(printf 'bootstrap-init-fixture' | sha256sum | awk '{print $1}')
BOOTSTRAP_WORK=$work \
BOOTSTRAP_BUILD_ROOT=$seed \
BOOTSTRAP_SEED_SHA256=$seed_sha \
BOOTSTRAP_INTERPRETER=$seed/bin/bash \
BOOTSTRAP_TOOLCHAIN_PREFIX=$toolchain \
PKGCTL=pkgctl \
PKGSTATE_INIT=pkgstate-init \
  "$harness" init >"$temporary/init.out"

for required in \
  dev \
  build/source build/work build/package build/inputs \
  check/source check/package check/inputs target tmp; do
  [ -d "$seed/$required" ] || fail "init did not provision root-view mountpoint: /$required"
done

[ ! -e "$seed/dev/null" ] || \
  fail 'bootstrap harness fabricated /dev/null instead of leaving device realization to libpkgexec-linux'
[ ! -e "$seed/build/inputs/build" ] || \
  fail 'bootstrap harness retained obsolete /build/inputs/build mountpoint'
[ ! -e "$seed/build/inputs/check" ] || \
  fail 'bootstrap harness retained obsolete /build/inputs/check mountpoint'
[ -d "$seed/check/package" ] || \
  fail 'bootstrap harness did not provision /check/package mountpoint'
[ -z "$(find "$seed/check/package" -mindepth 1 -maxdepth 1 -print -quit)" ] || \
  fail 'bootstrap harness populated the checked-package structural mountpoint'
[ -f "$work/.pkgsrc-core-native-bootstrap-v1" ] || \
  fail 'bootstrap init did not seal workspace authority'

grep -Fx "build-root=$seed" "$work/.pkgsrc-core-native-bootstrap-v1" >/dev/null || \
  fail 'bootstrap workspace did not retain exact hostile-minimal root authority'

cat >"$toolchain/bin/pkgctl" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$@" >"$QUALIFY_CAPTURE"
printf '%s\n' \
  'complete yes' \
  'failed no' \
  'frontend build'
SCRIPT
chmod 0755 "$toolchain/bin/pkgctl"
QUALIFY_CAPTURE=$temporary/qualify.args \
BOOTSTRAP_WORK=$work \
BOOTSTRAP_BUILD_ROOT=$seed \
BOOTSTRAP_SEED_SHA256=$seed_sha \
BOOTSTRAP_INTERPRETER=$seed/bin/bash \
BOOTSTRAP_TOOLCHAIN_PREFIX=$toolchain \
PKGCTL=pkgctl \
PKGSTATE_INIT=pkgstate-init \
  "$harness" qualify >"$temporary/qualify.out"
grep -Fx 'build' "$temporary/qualify.args" >/dev/null || \
  fail 'qualification did not invoke build frontend'
grep -Fx 'seed-probe' "$temporary/qualify.args" >/dev/null || \
  fail 'qualification did not select seed-probe subject'
grep -Fx -- '--check' "$temporary/qualify.args" >/dev/null || \
  fail 'qualification did not request seed-probe check'
grep -F 'bootstrap-seed-probe=' "$temporary/qualify.args" >/dev/null || \
  fail 'qualification did not bind committed seed-probe collection'
grep -Fx 'bootstrap seed runtime qualification: ok' "$temporary/qualify.out" >/dev/null || \
  fail 'qualification did not report terminal success'
[ ! -e "$work/qualification" ] || \
  fail 'successful qualification retained private probe workspace'

rm -rf "$work"
rmdir "$seed/dev"
mkdir "$temporary/outside-dev"
ln -s "$temporary/outside-dev" "$seed/dev"
set +e
BOOTSTRAP_WORK=$temporary/symlink-work \
BOOTSTRAP_BUILD_ROOT=$seed \
BOOTSTRAP_SEED_SHA256=$seed_sha \
BOOTSTRAP_INTERPRETER=$seed/bin/bash \
BOOTSTRAP_TOOLCHAIN_PREFIX=$toolchain \
PKGCTL=pkgctl \
PKGSTATE_INIT=pkgstate-init \
  "$harness" init >"$temporary/symlink.out" 2>"$temporary/symlink.err"
status=$?
set -e
[ "$status" -ne 0 ] || fail 'symlinked /dev mountpoint was admitted'
grep -F 'seed-root mountpoint is not an exact symlink-free directory:' \
  "$temporary/symlink.err" >/dev/null || \
  fail 'symlinked /dev failed outside exact mountpoint admission'
[ ! -e "$temporary/symlink-work/.pkgsrc-core-native-bootstrap-v1" ] || \
  fail 'symlinked root view created durable bootstrap authority'

printf '%s\n' 'bootstrap-init: ok'
