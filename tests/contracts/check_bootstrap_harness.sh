#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
makefile=$root/Makefile
harness=$root/tools/bootstrap_campaign.sh
fail() { printf 'bootstrap-harness-contract: %s\n' "$*" >&2; exit 1; }

[ -x "$harness" ] || fail 'bootstrap campaign harness is absent or non-executable'
for target in bootstrap-init bootstrap-qualify bootstrap bootstrap-resume bootstrap-check bootstrap-clean; do
  grep -F "$target:" "$makefile" >/dev/null || fail "Makefile lacks $target"
done

grep -F 'set -- build libgcc --check ' "$harness" >/dev/null || \
  fail 'bootstrap start is not one checked pkgctl build libgcc campaign'
grep -F -- '--collection "core-native=$collection_projection"' "$harness" >/dev/null || \
  fail 'bootstrap does not bind the committed collection projection'
grep -F 'stage_collection_projection "$recorded_collection_commit"' "$harness" >/dev/null || \
  fail 'bootstrap start does not regenerate collection authority from the admitted commit'
grep -F 'archive --format=tar "$commit" -- "$@"' "$harness" >/dev/null || \
  fail 'collection projection is not derived from committed Git bytes'
grep -F 'cat-file -e "$commit:$entry/recipe.yml"' "$harness" >/dev/null || \
  fail 'collection projection does not select package entries by recipe authority'
grep -F -- '--build-architecture x86_64' "$harness" >/dev/null || \
  fail 'bootstrap build architecture is not explicit'
grep -F -- '--target-architecture x86_64' "$harness" >/dev/null || \
  fail 'bootstrap target architecture is not explicit'
grep -F -- '--source-date-epoch "$source_date_epoch"' "$harness" >/dev/null || \
  fail 'bootstrap construction epoch is not explicit'
grep -F -- '--max-steps "$max_steps"' "$harness" >/dev/null || \
  fail 'bootstrap execution bound is not explicit'
grep -F 'pkgstate_init_bin' "$harness" >/dev/null || \
  fail 'bootstrap does not use provider-owned empty-state initialization'
grep -F 'BOOTSTRAP_TOOLCHAIN_PREFIX' "$makefile" >/dev/null || \
  fail 'Makefile does not expose private toolchain authority'
if grep -E 'BOOTSTRAP_BUILD_(UID|GID|GROUPS)' "$makefile" >/dev/null; then
  fail 'Makefile exposes caller-selected native supervisor credentials'
fi
grep -F 'resolve_supervisor_credentials' "$harness" >/dev/null || \
  fail 'bootstrap does not derive native supervisor credentials'
grep -F 'supervisor-user-id=$supervisor_uid' "$harness" >/dev/null || \
  fail 'bootstrap workspace does not bind native supervisor credentials'
grep -F 'require_recorded_supervisor' "$harness" >/dev/null || \
  fail 'bootstrap start/resume do not reject supervisor credential drift'
grep -F 'toolchain_prefix/bin/$requested' "$harness" >/dev/null || \
  fail 'controller tools are not resolved inside the private toolchain prefix'
grep -F '"LD_LIBRARY_PATH=$toolchain_ld_library_path"' "$harness" >/dev/null || \
  fail 'private toolchain library path is not carried into controller execution'
grep -F '"$privilege_bin" "$env_bin"' "$harness" >/dev/null || \
  fail 'privileged controller execution does not establish environment after privilege entry'
grep -F 'set BOOTSTRAP_PRIVILEGE' "$harness" >/dev/null || \
  fail 'root-owned seed mountpoints cannot request narrow provisioning authority'
grep -F '    dev \' "$harness" >/dev/null || \
  fail 'bootstrap root-view preflight does not provision the /dev overlay mountpoint'
grep -F '    build/inputs \' "$harness" >/dev/null || \
  fail 'bootstrap root-view preflight does not provision the phase-local build input root'
if grep -F '    build/inputs/build \' "$harness" >/dev/null || \
   grep -F '    build/inputs/check \' "$harness" >/dev/null; then
  fail 'bootstrap root-view preflight retains obsolete construction scope children'
fi
grep -F 'require_empty_seed_input_namespace build/inputs' "$harness" >/dev/null || \
  fail 'bootstrap preflight does not reject a polluted build input namespace'
grep -F 'require_empty_seed_input_namespace check/inputs' "$harness" >/dev/null || \
  fail 'bootstrap preflight does not reject a polluted check input namespace'
awk '/^resume_campaign\(\)/,/^}/' "$harness" | \
  grep -F 'preflight_seed_root' >/dev/null || \
  fail 'bootstrap resume does not requalify the seed root before execution'
grep -F '    check/package \' "$harness" >/dev/null || \
  fail 'bootstrap root-view preflight does not provision the checked-package mountpoint'
grep -F 'require_seed_executable /bin/sh' "$harness" >/dev/null || \
  fail 'bootstrap preflight does not require the absolute configure/make shell'
for tool in awk flex m4 sha256sum; do
  grep -E "^[[:space:]].*\b$tool\b" "$harness" >/dev/null || \
    fail "bootstrap preflight does not name required late-build tool: $tool"
done
grep -F 'set -- build seed-probe --check ' "$harness" >/dev/null || \
  fail 'bootstrap does not run the native seed qualification transaction'
grep -F 'qualify_seed_runtime' "$harness" >/dev/null || \
  fail 'bootstrap start does not gate the expensive campaign on seed qualification'
grep -F 'tests/fixtures/collections/bootstrap-seed-probe' "$harness" >/dev/null || \
  fail 'bootstrap seed qualification is not staged from committed fixture bytes'
if grep -F '"$privilege_bin" "$pkgctl_bin"' "$harness" >/dev/null; then
  fail 'privileged pkgctl bypasses private toolchain environment reconstruction'
fi
grep -F 'BOOTSTRAP_SEED_SHA256 is required' "$harness" >/dev/null || \
  fail 'bootstrap root-view provenance is not caller-bound'
grep -F "BOOTSTRAP_BUILD_ROOT must be a disposable root view, not the live /" "$harness" >/dev/null || \
  fail 'bootstrap permits the live host root as qualification authority'
grep -F 'expected exactly 3' "$harness" >/dev/null || \
  fail 'bootstrap result does not require the exact three-artifact construction closure'
grep -F "'goal=build=libgcc,check=libgcc'" "$harness" >/dev/null || \
  fail 'bootstrap workspace does not report its explicit libgcc check goal'

if grep -E '(^|[[:space:]])(\./)?(linux-api-headers|glibc-bootstrap|libgcc)/recipe\.yml' "$harness" >/dev/null; then
  fail 'bootstrap harness reaches into recipe bodies instead of pkgctl authority'
fi
grep -F 'ls-tree -d --name-only "$commit"' "$harness" >/dev/null || \
  fail 'collection projection does not enumerate committed top-level directories'
start_count=$(grep -Fc 'set -- build libgcc --check ' "$harness")
[ "$start_count" -eq 1 ] || \
  fail 'bootstrap harness must contain exactly one package-build start'
if grep -F 'pkgctl run' "$harness" >/dev/null; then
  fail 'bootstrap construction harness enters target-operation authority'
fi

printf '%s\n' 'bootstrap-harness: ok'
