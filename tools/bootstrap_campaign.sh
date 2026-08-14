#!/bin/sh
# SPDX-FileCopyrightText: 2026 Alexandr Savca <alexandr.savca89@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

command_name=${1:-}
[ -n "$command_name" ] || {
  printf '%s\n' 'usage: bootstrap_campaign.sh {init|start|resume|check|clean}' >&2
  exit 2
}
shift
[ "$#" -eq 0 ] || {
  printf '%s\n' 'bootstrap-campaign: unexpected positional arguments' >&2
  exit 2
}

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=${BOOTSTRAP_WORK:-$repo/.bootstrap}
build_root=${BOOTSTRAP_BUILD_ROOT:-}
seed_sha256=${BOOTSTRAP_SEED_SHA256:-}
interpreter_requested=${BOOTSTRAP_INTERPRETER:-}
toolchain_prefix_requested=${BOOTSTRAP_TOOLCHAIN_PREFIX:-${NEW_TOOLCHAIN_PREFIX:-}}
pkgctl_requested=${PKGCTL:-pkgctl}
pkgstate_init_requested=${PKGSTATE_INIT:-pkgstate-init}
privilege_requested=${BOOTSTRAP_PRIVILEGE:-}
max_steps=${BOOTSTRAP_MAX_STEPS:-8}
source_date_epoch=${BOOTSTRAP_SOURCE_DATE_EPOCH:-0}

fail()
{
  printf 'bootstrap-campaign: %s\n' "$*" >&2
  exit 1
}

require_command()
{
  requested=$1
  resolved=$(command -v -- "$requested" 2>/dev/null || :)
  [ -n "$resolved" ] || fail "required command is unavailable: $requested"
  case $resolved in
    /*)
      ;;
    *)
      resolved=$(CDPATH= cd -- "$(dirname -- "$resolved")" && pwd)/$(basename -- "$resolved")
      ;;
  esac
  printf '%s\n' "$resolved"
}

require_uint()
{
  value=$1
  label=$2
  case $value in
    *[!0-9]*|'')
      fail "$label must be an unsigned decimal integer"
      ;;
  esac
}

require_sha256()
{
  value=$1
  label=$2
  case $value in
    *[!0-9a-f]*|'')
      fail "$label must be exactly 64 lowercase hexadecimal digits"
      ;;
  esac
  [ "${#value}" -eq 64 ] || \
    fail "$label must be exactly 64 lowercase hexadecimal digits"
}

hash_material()
{
  material=$1
  printf '%s' "$material" | sha256sum | awk '{print $1}'
}

identity_for()
{
  domain=$1
  digest=$(hash_material "zeppe-lin/pkgsrc-core-native/bootstrap-qualification/1:$domain:$seed_sha256")
  printf 'v1:sha256:%s\n' "$digest"
}

command_nonce()
{
  hash_material "zeppe-lin/pkgsrc-core-native/bootstrap-qualification/1:build-libgcc:$seed_sha256"
}

collection_commit()
{
  git_bin=$(require_command git)
  "$git_bin" -C "$repo" rev-parse HEAD
}

require_clean_collection()
{
  git_bin=$(require_command git)
  [ -z "$("$git_bin" -C "$repo" status --porcelain --untracked-files=all)" ] || \
    fail 'pkgsrc-core-native worktree must be clean for bootstrap admission'
}

canonical_directory()
{
  path=$1
  label=$2
  [ -n "$path" ] || fail "$label is required"
  case $path in
    /*)
      ;;
    *)
      fail "$label must be an absolute path: $path"
      ;;
  esac
  [ -d "$path" ] || fail "$label is not an existing directory: $path"
  realpath "$path"
}

require_build_root()
{
  [ -n "$build_root" ] || fail 'BOOTSTRAP_BUILD_ROOT is required'
  build_root=$(canonical_directory "$build_root" BOOTSTRAP_BUILD_ROOT)
  [ "$build_root" != / ] || \
    fail 'BOOTSTRAP_BUILD_ROOT must be a disposable root view, not the live /'
}

require_seed()
{
  [ -n "$seed_sha256" ] || fail 'BOOTSTRAP_SEED_SHA256 is required'
  require_sha256 "$seed_sha256" BOOTSTRAP_SEED_SHA256
}

resolve_interpreter()
{
  require_build_root
  requested=$interpreter_requested
  if [ -z "$requested" ]; then
    for candidate in \
      "$build_root/usr/bin/bash" \
      "$build_root/bin/bash" \
      "$build_root/usr/bin/dash" \
      "$build_root/bin/dash"; do
      if [ -x "$candidate" ]; then
        requested=$candidate
        break
      fi
    done
  fi
  [ -n "$requested" ] || \
    fail 'BOOTSTRAP_INTERPRETER is required; no bash/dash candidate exists in the seed root'
  case $requested in
    /*)
      ;;
    *)
      fail "BOOTSTRAP_INTERPRETER must be an absolute host path inside the seed root: $requested"
      ;;
  esac
  [ -x "$requested" ] || fail "bootstrap interpreter is not executable: $requested"
  interpreter=$(realpath "$requested")
  case $interpreter in
    "$build_root"/*)
      ;;
    *)
      fail "bootstrap interpreter escapes BOOTSTRAP_BUILD_ROOT: $interpreter"
      ;;
  esac
  printf '%s\n' "$interpreter"
}

find_seed_tool()
{
  name=$1
  for candidate in "$build_root/usr/bin/$name" "$build_root/bin/$name"; do
    if [ -x "$candidate" ] || [ -L "$candidate" ]; then
      return 0
    fi
  done
  fail "seed root lacks required construction tool in /usr/bin or /bin: $name"
}

ensure_seed_directory()
{
  relative=$1
  mode=$2
  path=$build_root/$relative
  if [ -d "$path" ]; then
    return 0
  fi
  if mkdir -p "$path" 2>/dev/null; then
    chmod "$mode" "$path" || \
      fail "cannot set seed-root mountpoint mode: $path"
    return 0
  fi
  [ -n "$privilege_bin" ] || \
    fail "cannot provision seed-root mountpoint $path; set BOOTSTRAP_PRIVILEGE"
  "$privilege_bin" install -d -m "$mode" -- "$path" || \
    fail "cannot provision seed-root mountpoint with privilege: $path"
}

preflight_seed_root()
{
  require_build_root
  for directory in \
    build/source \
    build/work \
    build/package \
    build/inputs/build \
    build/inputs/check \
    check/source \
    check/package \
    check/inputs \
    target; do
    ensure_seed_directory "$directory" 0755
  done
  ensure_seed_directory tmp 1777

  for tool in \
    tar xz make find cc gcc g++ python3 install grep sed gawk bison \
    as ld ar nm ranlib objcopy objdump readelf strip wc tr mkdir rm mv ln; do
    find_seed_tool "$tool"
  done
  for header in gmp.h mpfr.h mpc.h; do
    [ -f "$build_root/usr/include/$header" ] || \
      fail "seed root lacks GCC host prerequisite header: /usr/include/$header"
  done
  resolve_interpreter >/dev/null
  require_uint "$max_steps" BOOTSTRAP_MAX_STEPS
  [ "$max_steps" -gt 0 ] || fail 'BOOTSTRAP_MAX_STEPS must be positive'
  require_uint "$source_date_epoch" BOOTSTRAP_SOURCE_DATE_EPOCH
}

marker=$work/.pkgsrc-core-native-bootstrap-v1
state=$work/state
runtime=$work/runtime
artifacts=$work/artifacts
reports=$work/reports
latest=$work/latest.out
latest_error=$work/latest.err
manifest=$work/bootstrap.manifest
collection_projection=$work/collection

runtime_directories='command-evidence run evidence effects content construction-sessions package-outputs check-temporary'

stage_collection_projection()
{
  commit=$1
  git_bin=$(require_command git)
  tar_bin=$(require_command tar)
  entries=$work/.collection-entries.$$
  temporary=$work/.collection.$$
  rm -rf -- "$temporary"
  mkdir -p -- "$temporary"
  : >"$entries"

  "$git_bin" -C "$repo" ls-tree -d --name-only "$commit" |
    while IFS= read -r entry; do
      if "$git_bin" -C "$repo" cat-file -e "$commit:$entry/recipe.yml" 2>/dev/null; then
        printf '%s\n' "$entry"
      fi
    done >"$entries"

  [ -s "$entries" ] || fail 'admitted collection commit contains no package entries'

  set --
  while IFS= read -r entry; do
    set -- "$@" "$entry"
  done <"$entries"
  if "$git_bin" -C "$repo" cat-file -e "$commit:profiles.yml" 2>/dev/null; then
    set -- "$@" profiles.yml
  fi

  "$git_bin" -C "$repo" archive --format=tar "$commit" -- "$@" |
    "$tar_bin" -xf - -C "$temporary"
  rm -f -- "$entries"

  for entry in "$temporary"/*; do
    [ -e "$entry" ] || continue
    if [ -d "$entry" ]; then
      [ -f "$entry/recipe.yml" ] ||
        fail "collection projection admitted non-package directory: $entry"
    fi
  done

  rm -rf -- "$collection_projection"
  mv -- "$temporary" "$collection_projection"
}

load_marker_authority()
{
  [ -f "$marker" ] || fail "bootstrap workspace is not initialized: $work"
  recorded_seed=$(sed -n 's/^seed-sha256=//p' "$marker")
  recorded_root=$(sed -n 's/^build-root=//p' "$marker")
  recorded_interpreter=$(sed -n 's/^interpreter=//p' "$marker")
  recorded_collection_commit=$(sed -n 's/^collection-commit=//p' "$marker")
  recorded_toolchain_prefix=$(sed -n 's/^toolchain-prefix=//p' "$marker")
  recorded_supervisor_uid=$(sed -n 's/^supervisor-user-id=//p' "$marker")
  recorded_supervisor_gid=$(sed -n 's/^supervisor-group-id=//p' "$marker")
  recorded_supervisor_groups=$(sed -n 's/^supervisor-groups=//p' "$marker")
  [ -n "$recorded_toolchain_prefix" ] || \
    fail 'bootstrap workspace lacks private toolchain authority; clean and reinitialize'
  [ -n "$recorded_supervisor_uid" ] && [ -n "$recorded_supervisor_gid" ] && \
    [ -n "$recorded_supervisor_groups" ] || \
    fail 'bootstrap workspace lacks native supervisor credential authority; clean and reinitialize'
  if [ -n "$toolchain_prefix" ]; then
    [ "$recorded_toolchain_prefix" = "$toolchain_prefix" ] || \
      fail 'BOOTSTRAP_TOOLCHAIN_PREFIX differs from initialized workspace authority'
  fi

  if [ -z "$seed_sha256" ]; then
    seed_sha256=$recorded_seed
  else
    [ "$recorded_seed" = "$seed_sha256" ] || \
      fail 'BOOTSTRAP_SEED_SHA256 differs from initialized workspace authority'
  fi
  if [ -z "$build_root" ]; then
    build_root=$recorded_root
  else
    current_root=$(canonical_directory "$build_root" BOOTSTRAP_BUILD_ROOT)
    [ "$recorded_root" = "$current_root" ] || \
      fail 'BOOTSTRAP_BUILD_ROOT differs from initialized workspace authority'
    build_root=$current_root
  fi
  if [ -z "$interpreter_requested" ]; then
    interpreter_requested=$recorded_interpreter
  fi
  current_interpreter=$(resolve_interpreter)
  [ "$recorded_interpreter" = "$current_interpreter" ] || \
    fail 'BOOTSTRAP_INTERPRETER differs from initialized workspace authority'
}

binding_arguments()
{
  printf '%s\n' \
    --managed-target "$(identity_for managed-target)" \
    --state-store "$(identity_for state-store)" \
    --root-view "$(identity_for root-view)" \
    --state-backend "$(identity_for state-backend)" \
    --publication-domain "$(identity_for publication-domain)"
}


toolchain_prefix=
toolchain_path=
toolchain_pkg_config_path=
toolchain_ld_library_path=
toolchain_cmake_prefix_path=
pkgctl_bin=
pkgstate_init_bin=
privilege_bin=
env_bin=
id_bin=
supervisor_uid=
supervisor_gid=
supervisor_groups=

resolve_privilege()
{
  if [ -n "$privilege_requested" ] && [ -z "$privilege_bin" ]; then
    privilege_bin=$(require_command "$privilege_requested")
  fi
}

resolve_supervisor_credentials()
{
  resolve_privilege
  id_bin=$(require_command id)
  if [ -n "$privilege_bin" ]; then
    supervisor_uid=$("$privilege_bin" "$id_bin" -u)
    supervisor_gid=$("$privilege_bin" "$id_bin" -g)
    supervisor_groups=$("$privilege_bin" "$id_bin" -G)
  else
    supervisor_uid=$("$id_bin" -u)
    supervisor_gid=$("$id_bin" -g)
    supervisor_groups=$("$id_bin" -G)
  fi
  require_uint "$supervisor_uid" supervisor-user-id
  require_uint "$supervisor_gid" supervisor-group-id
  for group in $supervisor_groups; do
    require_uint "$group" supervisor-supplementary-groups
  done
}

require_recorded_supervisor()
{
  resolve_supervisor_credentials
  [ "$recorded_supervisor_uid" = "$supervisor_uid" ] || \
    fail 'native supervisor user id differs from initialized bootstrap authority'
  [ "$recorded_supervisor_gid" = "$supervisor_gid" ] || \
    fail 'native supervisor group id differs from initialized bootstrap authority'
  [ "$recorded_supervisor_groups" = "$supervisor_groups" ] || \
    fail 'native supervisor supplementary groups differ from initialized bootstrap authority'
}

resolve_private_tool()
{
  requested=$1
  label=$2
  case $requested in
    /*)
      candidate=$requested
      ;;
    */*)
      fail "$label must be a basename or absolute path inside BOOTSTRAP_TOOLCHAIN_PREFIX"
      ;;
    *)
      candidate=$toolchain_prefix/bin/$requested
      ;;
  esac
  [ -x "$candidate" ] || fail "$label is not executable in private toolchain: $candidate"
  candidate=$(realpath "$candidate")
  case $candidate in
    "$toolchain_prefix"/*)
      ;;
    *)
      fail "$label escapes BOOTSTRAP_TOOLCHAIN_PREFIX: $candidate"
      ;;
  esac
  printf '%s\n' "$candidate"
}

resolve_toolchain_prefix()
{
  requested=$toolchain_prefix_requested
  if [ -z "$requested" ]; then
    requested=$(CDPATH= cd -- "$repo/.." && pwd)/.toolchain
  fi
  toolchain_prefix=$(canonical_directory "$requested" BOOTSTRAP_TOOLCHAIN_PREFIX)
  [ -d "$toolchain_prefix/lib" ] || \
    fail "private toolchain lacks lib directory: $toolchain_prefix/lib"

  toolchain_path=$toolchain_prefix/bin${PATH:+:$PATH}
  toolchain_pkg_config_path=$toolchain_prefix/lib/pkgconfig:$toolchain_prefix/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
  toolchain_ld_library_path=$toolchain_prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  toolchain_cmake_prefix_path=$toolchain_prefix${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}

  pkgctl_bin=$(resolve_private_tool "$pkgctl_requested" PKGCTL)
  pkgstate_init_bin=$(resolve_private_tool "$pkgstate_init_requested" PKGSTATE_INIT)
  env_bin=$(require_command env)
}

resolve_controller_tools()
{
  resolve_privilege
  resolve_toolchain_prefix
}

run_private_tool()
{
  "$env_bin" \
    "PATH=$toolchain_path" \
    "PKG_CONFIG_PATH=$toolchain_pkg_config_path" \
    "LD_LIBRARY_PATH=$toolchain_ld_library_path" \
    "CMAKE_PREFIX_PATH=$toolchain_cmake_prefix_path" \
    "$@"
}

run_pkgctl()
{
  if [ -n "$privilege_bin" ]; then
    "$privilege_bin" "$env_bin" \
      "PATH=$toolchain_path" \
      "PKG_CONFIG_PATH=$toolchain_pkg_config_path" \
      "LD_LIBRARY_PATH=$toolchain_ld_library_path" \
      "CMAKE_PREFIX_PATH=$toolchain_cmake_prefix_path" \
      "$pkgctl_bin" "$@"
  else
    run_private_tool "$pkgctl_bin" "$@"
  fi
}

append_groups_and_run()
{
  report=$1
  error=$2
  shift 2
  set -- "$@"
  for group in $supervisor_groups; do
    [ "$group" = "$supervisor_gid" ] || \
      set -- "$@" --build-supplementary-group "$group"
  done

  set +e
  run_pkgctl "$@" >"$report" 2>"$error"
  status=$?
  set -e
  cat "$report"
  if [ -s "$error" ]; then
    cat "$error" >&2
  fi
  cp "$report" "$latest"
  cp "$error" "$latest_error"
  [ "$status" -eq 0 ] || fail "pkgctl build returned status $status"
}

start_campaign()
{
  resolve_controller_tools
  load_marker_authority
  require_recorded_supervisor
  require_seed
  require_build_root
  require_clean_collection
  [ "$(collection_commit)" = "$recorded_collection_commit" ] || \
    fail 'pkgsrc-core-native HEAD differs from initialized bootstrap authority'
  stage_collection_projection "$recorded_collection_commit"
  [ ! -e "$runtime/command-evidence/command-$(command_nonce).pce" ] || \
    fail 'bootstrap command authority already exists; use make bootstrap-resume'

  report=$reports/start.out
  error=$reports/start.err
  interpreter=$(resolve_interpreter)

  set -- build libgcc \
    --canonical-store "$state" \
    --collection "core-native=$collection_projection" \
    --build-architecture x86_64 \
    --target-architecture x86_64 \
    --start "$(command_nonce)" \
    --runtime-root "$runtime" \
    --build-root "$build_root" \
    --artifact-root "$artifacts" \
    --interpreter "$interpreter" \
    --build-user-id "$supervisor_uid" \
    --build-group-id "$supervisor_gid" \
    --source-date-epoch "$source_date_epoch" \
    --max-steps "$max_steps"
  # shellcheck disable=SC2046
  set -- "$@" $(binding_arguments)
  append_groups_and_run "$report" "$error" "$@"
}

resume_campaign()
{
  resolve_controller_tools
  load_marker_authority
  require_recorded_supervisor
  require_seed
  require_build_root

  report=$reports/resume.out
  error=$reports/resume.err
  interpreter=$(resolve_interpreter)

  set -- build \
    --canonical-store "$state" \
    --resume "$(command_nonce)" \
    --runtime-root "$runtime" \
    --build-root "$build_root" \
    --artifact-root "$artifacts" \
    --interpreter "$interpreter" \
    --build-user-id "$supervisor_uid" \
    --build-group-id "$supervisor_gid" \
    --source-date-epoch "$source_date_epoch" \
    --max-steps "$max_steps"
  append_groups_and_run "$report" "$error" "$@"
}

artifact_index()
{
  package=$1
  awk -v package="$package" '
    $1 ~ /^artifact\.[0-9]+\.package$/ && $2 == package {
      split($1, parts, ".")
      print parts[2]
    }
  ' "$latest"
}

artifact_field()
{
  index=$1
  field=$2
  sed -n "s/^artifact\.$index\.$field //p" "$latest"
}

check_archive_member()
{
  archive=$1
  member=$2
  tar -tf "$archive" | grep -Fx -- "$member" >/dev/null || \
    fail "artifact lacks required member $member: $archive"
}

check_campaign()
{
  require_command sha256sum >/dev/null
  require_command awk >/dev/null
  require_command sed >/dev/null
  require_command grep >/dev/null
  require_command tar >/dev/null
  readelf_bin=$(require_command readelf)
  git_bin=$(require_command git)
  load_marker_authority
  require_seed
  require_build_root
  [ -f "$latest" ] || fail 'bootstrap campaign has no retained report'

  grep -Fx 'complete yes' "$latest" >/dev/null || \
    fail 'bootstrap campaign is not terminal; use make bootstrap-resume'
  grep -Fx 'failed no' "$latest" >/dev/null || \
    fail 'bootstrap campaign reports failure'
  grep -Fx 'frontend build' "$latest" >/dev/null || \
    fail 'retained report does not belong to the build frontend'

  artifact_count=$(grep -Ec '^artifact\.[0-9]+\.package ' "$latest")
  [ "$artifact_count" -eq 3 ] || \
    fail "bootstrap retained $artifact_count artifacts, expected exactly 3"

  : >"$manifest.tmp"
  printf '%s\n' 'format zeppe-lin.bootstrap-manifest/1' >>"$manifest.tmp"
  printf 'seed-sha256 %s\n' "$seed_sha256" >>"$manifest.tmp"
  printf 'collection-commit %s\n' \
    "$recorded_collection_commit" >>"$manifest.tmp"

  for package in linux-api-headers glibc-bootstrap libgcc; do
    index=$(artifact_index "$package")
    [ -n "$index" ] || fail "retained report lacks $package artifact"
    [ "$(printf '%s\n' "$index" | wc -l | tr -d ' ')" -eq 1 ] || \
      fail "retained report names $package more than once"
    path=$(artifact_field "$index" path)
    reported_sha=$(artifact_field "$index" sha256)
    binding=$(artifact_field "$index" binding-identity)
    image=$(artifact_field "$index" image-identity)
    [ -f "$path" ] || fail "$package artifact path is absent: $path"
    case $path in
      "$artifacts"/*)
        ;;
      *)
        fail "$package artifact escaped BOOTSTRAP_WORK artifact authority: $path"
        ;;
    esac
    observed_sha=$(sha256sum "$path" | awk '{print $1}')
    [ "$observed_sha" = "$reported_sha" ] || \
      fail "$package artifact SHA-256 differs from retained result"
    printf 'package %s sha256 %s binding %s image %s\n' \
      "$package" "$observed_sha" "$binding" "$image" >>"$manifest.tmp"

    case $package in
      linux-api-headers)
        check_archive_member "$path" usr/include/linux/types.h
        ;;
      glibc-bootstrap)
        check_archive_member "$path" usr/include/gnu/stubs.h
        check_archive_member "$path" usr/lib/crt1.o
        check_archive_member "$path" usr/lib/libc.so.6
        check_archive_member "$path" usr/lib/ld-linux-x86-64.so.2
        ;;
      libgcc)
        check_archive_member "$path" usr/lib/libgcc_s.so.1
        temporary=$(mktemp -d "${TMPDIR:-/tmp}/pkgsrc-core-native-libgcc.XXXXXX")
        trap 'rm -rf "$temporary"' EXIT HUP INT TERM
        tar -xf "$path" -C "$temporary" usr/lib/libgcc_s.so.1
        dynamic=$("$readelf_bin" -d "$temporary/usr/lib/libgcc_s.so.1")
        printf '%s\n' "$dynamic" | \
          grep -F 'Library soname: [libgcc_s.so.1]' >/dev/null || \
          fail 'libgcc artifact has the wrong SONAME'
        printf '%s\n' "$dynamic" | \
          grep -F 'Shared library: [libc.so.6]' >/dev/null || \
          fail 'libgcc artifact does not name final libc ABI'
        printf '%s\n' "$dynamic" | \
          grep -F 'Shared library: [ld-linux-x86-64.so.2]' >/dev/null || \
          fail 'libgcc artifact does not name final loader ABI'
        if printf '%s\n' "$dynamic" | grep -E '\((RPATH|RUNPATH)\)' >/dev/null; then
          fail 'libgcc artifact carries RPATH/RUNPATH'
        fi
        rm -rf "$temporary"
        trap - EXIT HUP INT TERM
        ;;
    esac
  done

  mv "$manifest.tmp" "$manifest"
  cat "$manifest"
}

init_campaign()
{
  require_command sha256sum >/dev/null
  require_command awk >/dev/null
  require_command realpath >/dev/null
  require_seed
  require_build_root
  require_clean_collection
  admitted_collection_commit=$(collection_commit)
  resolve_controller_tools
  resolve_supervisor_credentials
  preflight_seed_root
  interpreter=$(resolve_interpreter)

  if [ -e "$marker" ]; then
    fail "bootstrap workspace already exists: $work"
  fi
  mkdir -p "$work" "$runtime" "$artifacts" "$reports"
  for directory in $runtime_directories; do
    mkdir -p "$runtime/$directory"
  done
  stage_collection_projection "$admitted_collection_commit"

  # shellcheck disable=SC2046
  run_private_tool "$pkgstate_init_bin" --canonical-store "$state" $(binding_arguments)

  cat >"$marker" <<MARKER
format=zeppe-lin.bootstrap-workspace/1
seed-sha256=$seed_sha256
build-root=$build_root
interpreter=$interpreter
collection=$repo
collection-commit=$admitted_collection_commit
toolchain-prefix=$toolchain_prefix
supervisor-user-id=$supervisor_uid
supervisor-group-id=$supervisor_gid
supervisor-groups=$supervisor_groups
nonce=$(command_nonce)
MARKER

  printf '%s\n' \
    "bootstrap-work=$work" \
    "seed-sha256=$seed_sha256" \
    "build-root=$build_root" \
    "interpreter=$interpreter" \
    "collection-commit=$admitted_collection_commit" \
    "collection-projection=$collection_projection" \
    "toolchain-prefix=$toolchain_prefix" \
    "supervisor-user-id=$supervisor_uid" \
    "supervisor-group-id=$supervisor_gid" \
    "supervisor-groups=$supervisor_groups" \
    "nonce=$(command_nonce)" \
    'goal=build=libgcc'
}

clean_campaign()
{
  case $work in
    ''|/)
      fail 'refusing unsafe bootstrap workspace cleanup'
      ;;
  esac
  if [ ! -e "$work" ]; then
    exit 0
  fi
  [ -f "$marker" ] || \
    fail "refusing to remove unmarked bootstrap workspace: $work"
  if rm -rf "$work" 2>/dev/null; then
    exit 0
  fi
  if [ -n "$privilege_requested" ]; then
    privilege_bin=$(require_command "$privilege_requested")
    "$privilege_bin" rm -rf -- "$work"
    exit 0
  fi
  fail 'bootstrap workspace contains privileged files; set BOOTSTRAP_PRIVILEGE for cleanup'
}

case $command_name in
  init)
    init_campaign
    ;;
  start)
    start_campaign
    ;;
  resume)
    resume_campaign
    ;;
  check)
    check_campaign
    ;;
  clean)
    clean_campaign
    ;;
  *)
    printf 'bootstrap-campaign: unknown command: %s\n' "$command_name" >&2
    exit 2
    ;;
esac
