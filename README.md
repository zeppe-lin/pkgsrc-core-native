# pkgsrc-foundation

`pkgsrc-foundation` owns the one bounded transition from admitted historical
seed authority to native target authority. It contains the package recipes
needed to establish the target ABI/runtime substrate and the temporary
construction authority required to cross that boundary.

The collection is package metadata, not a system-construction product. It owns
recipes and named package-selection profiles. It does not own bootstrap
workspaces, seed roots, controller discovery, transaction orchestration, rootfs
composition, installation media, or qualification campaigns. Those are product
concerns above the package-source boundary.

This collection is not a compatibility view of historical `pkgsrc-core` and is
not a renamed CRUX ports bucket. Package placement follows native dependency and
bootstrap-authority boundaries.

## Collection authority

Each immediate visible package directory contains one mandatory `recipe.yml`
using the `zeppe-lin.recipe/1` protocol. The sealed recipe's package name is
semantic package identity; directory names are repository organization and
provenance.

The root `profiles.yml` uses `zeppe-lin.profiles/1`. Profiles are named desired
membership, not transaction ordering. Recipe requirement edges determine
package dependency authority; the resolver and transaction engine derive
closure, strongly connected runtime cohorts, and executable order.

Higher collections may depend on foundation package/profile authority.
Foundation recipes must not depend on higher collection authority.

## Seed-retirement boundary

Only the foundation construction campaign may consume explicitly admitted
historical seed tooling. "Seed tooling" does not mean ambient host `/usr`: the
product controller admits one exact seed root, interpreter/tool coordinates,
target architecture, foundation source revision, and build policy.

The foundation campaign has two different outputs:

```text
historical seed authority
        |
        v
foundation construction closure
        |
        +-- temporary/bootstrap package artifacts
        |
        `-- stable deployable ABI/runtime packages
                        |
                        v
                  @foundation
```

Temporary/bootstrap packages are first-class transaction nodes with exact
source, build, artifact, and evidence authority. They are not desired installed
state and are never promoted into `@foundation` merely because their recipes
live in this collection.

The foundation boundary is closed only when the resulting construction root can
continue package construction after the historical seed root is inaccessible.
Higher collections must therefore make no assumption that a command, header,
library, or pkg-config record exists because it happened to be present in the
seed.

## Foundation profile

`@foundation` names only the stable deployable substrate currently established
by this collection:

```text
filesystem
glibc
libgcc
```

`linux-api-headers` and `glibc-bootstrap` remain collection recipes because they
are exact construction authority required to realize the final runtime. They
are intentionally absent from `@foundation`: collection membership is not
installation membership, and build-only authority is not promoted into target
state by directory presence.

The reciprocal final `glibc <-> libgcc` runtime requirement is a package-level
runtime cohort. It does not create collection ordering policy and is not encoded
in profile member order.

The final glibc payload installs exactly `C.UTF-8` because the native build
policy admits that locale as an execution invariant. Message-catalog/NLS policy
is separate from libc locale authority; the foundation must not depend on the
historical seed to supply a locale named by its own build contract.

Future target C++ runtime authority such as `libstdc++` belongs on the stable
foundation side when its ownership is split cleanly from the compiler package.

## Construction authority

Recipe requirements name admitted package/profile authority, not ambient
construction commands. Direct build and check inputs are consumed through the
native execution namespaces. Run requirements describe target runtime closure
and are not generic sequencing hints.

The collection currently retains the bounded construction seam needed to break
the first libc/compiler-runtime cycle:

```text
linux-api-headers -> glibc-bootstrap -> libgcc
linux-api-headers -> glibc
                    glibc <-> libgcc   (run)
```

`glibc-bootstrap` is construction authority only. It is not an alternate libc,
a deployable root member, or a system-product profile.

As the bootstrap graph grows, any additional `*-bootstrap` recipes must exist
because the seed-retirement proof requires them, not because historical core or
Linux From Scratch happened to install the corresponding final package. Optional
compiler/linker features likewise do not justify moving support libraries below
the boundary until an exact required construction edge proves they belong there.

## Filesystem policy

Zeppe-Lin uses a merged `/usr` hierarchy. Package payloads use canonical
`/usr/bin`, `/usr/sbin`, and `/usr/lib` paths. The `filesystem` package owns the
persistent namespace skeleton and merged-`/usr` aliases. It does not own host
configuration, mutable account databases, runtime device nodes, service state,
or rootfs composition policy.

## Scope exclusions

`acl`, `attr`, `lz4`, `xz`, `zlib`, and `zstd` are ordinary system/runtime or
optional toolchain-support packages rather than currently proven seed-retirement
substrate and do not belong to this collection. Source archive compression does
not imply an installed compression-tool dependency: archive realization is owned
by the native source adapter.

Product qualification packages such as historical bootstrap seed/runtime probes
are not distribution packages and do not belong here. Build/documentation tools
that are not dependencies of the foundation closure likewise belong in higher
package-source domains rather than being retained for convenience.

## License

Collection metadata and Zeppe-Lin-authored recipe files are licensed under
GPL-3.0-or-later. `package.licenses` records the license of the software
specified by a recipe. Package-local material derived from third-party sources
retains its own copyright and license terms.
