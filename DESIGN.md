# pkgsrc-core-native design

## Authority boundary

`pkgsrc-core-native` publishes native package-source declarations and optional
named profile policy. It does not define historical `Pkgfile` semantics,
package-manager configuration, build-root discovery, target discovery, or
transaction orchestration.

```text
recipe.yml / profiles.yml
          |
          v
strict native acquisition and sealing
          |
          v
catalog / profile authority
```

Repository paths and directory names are discovery coordinates and diagnostic
provenance. Sealed recipe and profile values are semantic authority.

## Dependency planes

Recipe requirements are package relations. They are not a list of commands
that happen to be available while a recipe runs.

### Build and check inputs

A direct build or check requirement names package input authority. The native
build boundary exposes each admitted direct package input beneath
`PKG_BUILD_INPUT_ROOT/<package>`; recipes must consume that package tree
explicitly.

For example, a library input may be admitted with paths such as:

```text
$PKG_BUILD_INPUT_ROOT/example/usr/include
$PKG_BUILD_INPUT_ROOT/example/usr/lib
```

A bare invocation such as `make`, `tar`, `cc`, `cmake`, `ninja`, or `sed` does
not prove a package requirement on a package of the same name. Those commands
currently come from the caller-supplied construction root view.

The repository must not manufacture declarative-looking toolchain requirements
until the corresponding package trees are actually consumed by the execution
request. A future self-hosted toolchain may replace this bootstrap seam, but it
must do so by changing the real construction authority rather than by adding
unused recipe edges.

### Run requirements

Run requirements describe target runtime closure. They are also transaction
ordering authority and therefore must not be used as generic installation
ordering hints.

In particular, packages are not required to name `filesystem` merely because
their payload uses `/usr`. `filesystem` owns the baseline namespace package;
empty-target bootstrap order belongs to rootfs composition. A package may name
`filesystem` only if it genuinely consumes filesystem-owned target semantics.

### Lifecycle requirements

Lifecycle requirements remain action-bound package relations. This collection
does not use them as a substitute for run dependencies, build dependencies, or
rootfs sequencing.

## Bootstrap construction root

The initial native core is bootstrapped with an explicitly provisioned
construction root view. That root is execution authority selected by the caller,
not package-source authority owned by this repository.

Current recipes may therefore invoke ordinary construction tools supplied by
that root view while separately consuming declared package inputs through
`PKG_BUILD_INPUT_ROOT`.

This is a visible bootstrap seam, not ambient permission. Root-view composition,
interpreter selection, credentials, isolation, and execution evidence belong to
the native execution/orchestration stack.

## Bootstrap foundation

The first package-owned bootstrap input is `linux-api-headers`. It publishes the
sanitized Linux userspace API header tree for the selected target architecture.
The package does not claim that the construction toolchain is already
self-hosted: its source extraction, Kbuild invocation, header sanitization host
tool, and output-tree copy still execute through the explicitly provisioned
construction root.

`linux-api-headers` is nevertheless semantic package authority rather than a
copy of the seed root's `/usr/include/linux`. A future libc recipe must consume
it as an explicit build input through:

```text
$PKG_BUILD_INPUT_ROOT/linux-api-headers/usr/include
```

That establishes the kernel-userspace ABI input independently from whichever
headers happen to be installed in the bootstrap root. It is a build input to
libc, not a fabricated runtime requirement. Whether the package is selected
into a finished base system belongs to rootfs profile policy.

### C library foundation

`glibc` is the first consumer of that package-owned kernel ABI authority. Its
one direct package build input is `linux-api-headers`, consumed through the
native package-input namespace and passed to glibc configure with
`--with-headers`. The compiler, GNU binutils, GNU make, Python and the ordinary
source-generation utilities remain explicit construction-root seed capabilities
at this stage; the recipe does not relabel them as package requirements.

The initial libc package owns the GNU C Library ABI, development headers,
linker/runtime objects and glibc static data. It does not absorb host
configuration, timezone policy, locale policy, or nscd service state. In
particular, historical `/etc/hosts`, resolver/NSS configuration, `ld.so.conf`,
`localtime`, pre-generated locales and nscd configuration are not libc source
authority.

The x86_64 ABI still names `/lib64/ld-linux-x86-64.so.2` as the ELF interpreter.
That pathname is ABI, not a request to revive a split hierarchy: `filesystem`
owns `/lib64 -> usr/lib64 -> lib`, while the glibc package stores the loader
bytes under `/usr/lib`. Shell/Perl helper scripts installed by upstream are
kept outside this first libc package until their interpreter runtime closure is
represented explicitly.

Upstream glibc requires the shared `libgcc_s` runtime for correct pthread
unwinding/cancellation behavior. `glibc` therefore records an explicit
`run -> libgcc` edge now. That target-runtime authority is intentionally
unresolved until the native `libgcc` recipe exists: build-scoped construction
of glibc may proceed from the seed compiler, but target admission of glibc must
fail closed rather than borrowing `libgcc_s.so.1` from the construction root.

The current recipe is intentionally x86_64-only. Adding another target
architecture requires an explicit recipe/protocol review of the corresponding
Kbuild `ARCH` mapping rather than inferring it from the host.

## Self-hosting direction

Self-hosting should shrink the provisioned construction root only after native
packages and composition machinery can provide the same capabilities as
explicit execution resources. At that point a named toolchain profile may be
useful policy, but the profile must select package inputs that are actually
consumed by builds. It must not become a ceremonial list beside an unchanged
ambient root view.

## Rootfs composition

Collection membership is not rootfs membership. A future `@rootfs` profile
will state direct distribution policy. The rootfs composer will establish the
empty target substrate, select that sealed profile, drive convergence through
the package controller, and audit the result.

The collection itself does not infer rootfs policy from visible package
directories and individual recipes do not encode rootfs sequencing through fake
runtime edges.
