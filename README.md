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

## License

Collection metadata and Zeppe-Lin-authored recipe files are licensed under
GPL-3.0-or-later. `package.licenses` records the license of the software
specified by a recipe. Package-local material derived from third-party sources
retains its own copyright and license terms.
