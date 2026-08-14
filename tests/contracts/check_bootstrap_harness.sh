#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
makefile=$root/Makefile
harness=$root/tools/bootstrap_campaign.sh
fail() { printf 'bootstrap-harness-contract: %s\n' "$*" >&2; exit 1; }

[ -x "$harness" ] || fail 'bootstrap campaign harness is absent or non-executable'
for target in bootstrap-init bootstrap bootstrap-resume bootstrap-check bootstrap-clean; do
  grep -F "$target:" "$makefile" >/dev/null || fail "Makefile lacks $target"
done

grep -F 'set -- build libgcc ' "$harness" >/dev/null || \
  fail 'bootstrap start is not one pkgctl build libgcc campaign'
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
if grep -F '"$privilege_bin" "$pkgctl_bin"' "$harness" >/dev/null; then
  fail 'privileged pkgctl bypasses private toolchain environment reconstruction'
fi
grep -F 'BOOTSTRAP_SEED_SHA256 is required' "$harness" >/dev/null || \
  fail 'bootstrap root-view provenance is not caller-bound'
grep -F "BOOTSTRAP_BUILD_ROOT must be a disposable root view, not the live /" "$harness" >/dev/null || \
  fail 'bootstrap permits the live host root as qualification authority'
grep -F 'expected exactly 3' "$harness" >/dev/null || \
  fail 'bootstrap result does not require the exact three-artifact construction closure'

if grep -E '(^|[[:space:]])(\./)?(linux-api-headers|glibc-bootstrap|libgcc)/recipe\.yml' "$harness" >/dev/null; then
  fail 'bootstrap harness reaches into recipe bodies instead of pkgctl authority'
fi
grep -F 'ls-tree -d --name-only "$commit"' "$harness" >/dev/null || \
  fail 'collection projection does not enumerate committed top-level directories'
start_count=$(grep -Fc 'set -- build libgcc ' "$harness")
[ "$start_count" -eq 1 ] || \
  fail 'bootstrap harness must contain exactly one package-build start'
if grep -F 'pkgctl run' "$harness" >/dev/null; then
  fail 'bootstrap construction harness enters target-operation authority'
fi

printf '%s\n' 'bootstrap-harness: ok'
