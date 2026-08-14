# pkgsrc-core-native

`pkgsrc-core-native` is the native core package-source collection for
Zeppe-Lin 2.x. It contains package declarations and package-local source
material used to construct the foundational system with the native package
toolchain.

This repository is not a compatibility view of the historical `pkgsrc-core`
collection. `Pkgfile`, CRUX ports semantics, and legacy collection policy are
not source authority here. Native package declarations are authored directly in
the native protocols.

## Collection authority

Each immediate visible package directory is one collection entry and contains a
mandatory `recipe.yml` using the `zeppe-lin.recipe/1` protocol. The package name
inside the sealed recipe is semantic package identity; the directory name is
repository organization and diagnostic provenance.

Directory enumeration discovers package entries. It is not package-selection or
deployment policy. Named selections belong in the native profile protocol when
such policy is declared; a package does not become part of a root filesystem
merely because its directory exists in this collection.

Recipes in this collection may require packages or profiles admitted by the
explicit native catalog. Higher collections may require `pkgsrc-core-native`;
core recipes must not depend on higher collection authority.

## Filesystem policy

Zeppe-Lin 2.x uses a merged `/usr` hierarchy. Package payloads use the canonical
`/usr/bin`, `/usr/sbin`, and `/usr/lib` paths. The `filesystem` package owns the
top-level `/bin`, `/sbin`, `/lib`, and related aliases; other package images do
not recreate split-hierarchy payload paths.

## Dependency authority

Recipe requirements name package authority, not ambient construction commands.
Direct build/check package inputs are consumed explicitly through
`PKG_BUILD_INPUT_ROOT`; ordinary bootstrap tools invoked as bare commands come
from the caller-supplied construction root view. Run requirements describe
target runtime closure and are not generic sequencing hints.

See `DESIGN.md` for the dependency planes, bootstrap seam, and self-hosting
direction.

## Bootstrap foundation

`linux-api-headers` is the first package-owned bootstrap foundation. It exports
the Linux userspace API header tree instead of allowing future libc construction
to consume whatever kernel headers happen to exist in the provisioned build
root. The package is still seed-built; it does not claim a self-hosted compiler
or construction toolchain.

`glibc` is the next bootstrap foundation. It consumes `linux-api-headers` as an
exact native build input instead of rebuilding or observing kernel headers from
the seed root. This first libc package intentionally excludes machine `/etc`
policy, timezone selection, pre-generated locale policy and nscd service state.
Its pthread runtime requirement on native `libgcc` is declared immediately; target
resolution remains deliberately incomplete until that package authority exists.

`glibc-bootstrap` is the bounded construction sysroot used to break the bootstrap
cycle before native `libgcc` exists. It consumes the exact `linux-api-headers`
input, builds glibc into a private stage, then publishes only the real libc
compile/link surface needed by GCC target-runtime construction: UAPI and glibc
headers, startup objects, the libc linker surface, and the x86_64 loader. It is
construction authority only, not an alternate deployable libc and not rootfs
policy.

`libgcc` consumes that exact sysroot and publishes only `libgcc_s.so.1`. Its
runtime requirement on final `glibc` closes the reciprocal dependency already
declared by glibc. The pair is therefore the first native runtime cohort while
the construction graph stays acyclic.

## License

Collection metadata and Zeppe-Lin-authored recipe files are licensed under
GPL-3.0-or-later. `package.licenses` records the license of the software
specified by a recipe. Package-local material derived from third-party sources
retains its own copyright and license terms.

### Filesystem package boundary

The `filesystem` package owns only the persistent namespace skeleton required to
admit package payloads: fundamental directories, merged-`/usr` aliases, and
stable compatibility topology such as `/var/run -> /run` and
`/etc/mtab -> /proc/self/mounts`.

It does not own host configuration, mutable account databases, login policy,
service-specific state directories, runtime device nodes, or rootfs composition
policy. Those authorities must be supplied by the component that actually owns
them. In particular, `filesystem` carries no `fstab`, `passwd`, `group`,
`shadow`, `securetty`, `issue`, `motd`, `shells`, or MIME database bytes.

## Bootstrap qualification

The first native construction closure can be exercised through the repository
Makefile without bypassing `pkgctl`:

```text
linux-api-headers -> glibc-bootstrap -> libgcc
```

Prepare a **disposable extraction** of a known construction root. For
the first cross-host qualification, use the same Zeppe-Lin 1.x rootfs archive
on both machines and use that archive's SHA-256 as the seed identity. Do not use
the live `/` hierarchy.

For example:

```sh
seed_archive=/path/to/zeppe-lin-1.x-rootfs.tar.xz
seed_root=/var/tmp/zeppe-lin-native-seed
seed_sha256=$(sha256sum "$seed_archive" | awk '{print $1}')

rm -rf "$seed_root"
mkdir -p "$seed_root"
tar -xpf "$seed_archive" -C "$seed_root"

make bootstrap-init \
  BOOTSTRAP_PRIVILEGE=sudo \
  BOOTSTRAP_BUILD_ROOT="$seed_root" \
  BOOTSTRAP_SEED_SHA256="$seed_sha256"
```

The extracted root may remain root-owned. `BOOTSTRAP_PRIVILEGE=sudo` is used only
when the empty build/check/target mountpoint topology must be created; do not
`chown -R` the seed root.

Catalog acquisition does not point at the repository root. `bootstrap-init` and
`bootstrap` derive `.bootstrap/collection` from the admitted Git commit, including
only immediate committed package directories that contain `recipe.yml` and the
committed `profiles.yml` when one exists. Repository machinery such as `tests/`,
`tools/`, `Makefile`, and design documentation therefore never enters collection
discovery authority. The projection is regenerated from the recorded commit
before a new command is admitted.

The harness also consumes the private native-toolchain prefix built by the
zoo-level `build-new-toolchain.sh`. With the normal sibling layout it discovers
`../.toolchain` automatically. If `source ../.toolchain-env` has already exported
`NEW_TOOLCHAIN_PREFIX`, that prefix wins. A custom prefix can be explicit:

```sh
make bootstrap-init \
  BOOTSTRAP_TOOLCHAIN_PREFIX=/path/to/.toolchain \
  BOOTSTRAP_PRIVILEGE=sudo \
  BOOTSTRAP_BUILD_ROOT="$seed_root" \
  BOOTSTRAP_SEED_SHA256="$seed_sha256"
```

`pkgctl` and `pkgstate-init` are required to come from that prefix. The harness
reconstructs its `PATH`, `PKG_CONFIG_PATH`, `LD_LIBRARY_PATH`, and
`CMAKE_PREFIX_PATH` for every controller invocation. For privileged `pkgctl`,
that environment is established through `sudo env ...` after privilege entry,
so loader paths are not lost to sudo filtering.

`bootstrap-init` chooses a regular bash/dash interpreter inside the seed root
when one is available. An exact path can instead be supplied explicitly:

```sh
make bootstrap-init \
  BOOTSTRAP_BUILD_ROOT="$seed_root" \
  BOOTSTRAP_SEED_SHA256="$seed_sha256" \
  BOOTSTRAP_INTERPRETER="$seed_root/usr/bin/bash"
```

Native Linux isolation normally needs privilege. Keep `make` itself under the
calling user and let the harness elevate only the `pkgctl` process:

```sh
make bootstrap BOOTSTRAP_PRIVILEGE=sudo
```

This preserves the calling user's numeric build credentials while granting the
controller the mount/namespace authority it needs. The command is bounded;
when the report says `complete no`, continue the same retained command with:

```sh
make bootstrap-resume BOOTSTRAP_PRIVILEGE=sudo
```

After a terminal result:

```sh
make bootstrap-check
cat .bootstrap/bootstrap.manifest
```

`bootstrap-check` requires exactly the three expected artifacts and independently
checks their retained hashes plus the final `libgcc_s.so.1` ELF runtime closure.
For the first reproducibility experiment, run the same collection commit and
same seed rootfs archive once on the current Zeppe-Lin machine and once on the
Ubuntu machine, then compare the two `bootstrap.manifest` files byte for byte.
The host userspace is thereby held constant; the host kernel is the principal
remaining machine-level difference.

The workspace is intentionally local and ignored by Git. Remove it explicitly
with:

```sh
make bootstrap-clean BOOTSTRAP_PRIVILEGE=sudo
```

The bootstrap harness is qualification machinery, not rootfs composition and
not a replacement package manager. It never runs recipe bodies directly.
