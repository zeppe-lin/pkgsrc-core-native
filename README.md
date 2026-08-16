# pkgsrc-foundation

`pkgsrc-foundation` is the lowest package-source authority layer of the native
Zeppe-Lin package graph. It contains recipes for the ABI/runtime substrate and
other packages that higher package-source collections may depend on.

The repository is package metadata, not a system-construction product. It owns
recipes and named package-selection profiles. It does not own bootstrap
workspaces, seed roots, controller discovery, transaction orchestration, rootfs
composition, installation media, or qualification campaigns. Those are product
concerns above the package-source boundary.

This collection is not a compatibility view of historical `pkgsrc-core` and is
not a renamed CRUX ports bucket. Package placement follows native dependency and
maintenance boundaries.

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

## Foundation profile

`@foundation` names the deployable members of this collection:

```text
acl
attr
filesystem
glibc
libgcc
lz4
xz
zlib
zstd
```

`linux-api-headers` and `glibc-bootstrap` remain collection recipes because they
are exact construction authority required to realize the final runtime. They
are intentionally absent from `@foundation`: collection membership is not
installation membership, and build-only authority is not promoted into target
state by directory presence.

The reciprocal final `glibc <-> libgcc` runtime requirement is a package-level
runtime cohort. It does not create collection ordering policy and is not encoded
in profile member order.

## Filesystem policy

Zeppe-Lin uses a merged `/usr` hierarchy. Package payloads use canonical
`/usr/bin`, `/usr/sbin`, and `/usr/lib` paths. The `filesystem` package owns the
persistent namespace skeleton and merged-`/usr` aliases. It does not own host
configuration, mutable account databases, runtime device nodes, service state,
or rootfs composition policy.

## Dependency authority

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

## Scope exclusions

Product qualification packages such as historical bootstrap seed/runtime probes
are not distribution packages and do not belong here. Build/documentation tools
that are not dependencies of the foundation graph likewise belong in higher
package-source domains rather than being retained for convenience.

## License

Collection metadata and Zeppe-Lin-authored recipe files are licensed under
GPL-3.0-or-later. `package.licenses` records the license of the software
specified by a recipe. Package-local material derived from third-party sources
retains its own copyright and license terms.
