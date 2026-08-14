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

### C library bootstrap sysroot

`glibc-bootstrap` is a construction-only bootstrap sysroot authority. It is not
an alternate libc runtime package and must not be selected as rootfs policy.
Its purpose is to break the genuine bootstrap cycle between final glibc runtime
authority and the shared GCC runtime required by glibc pthread unwinding.

The package has one direct build requirement, `linux-api-headers`, and no run,
check, or lifecycle package requirements. It builds glibc with the provisioned
seed compiler into a private staging tree, then projects one bounded GCC
sysroot from that result. The published sysroot contains the admitted Linux
UAPI headers, real glibc public headers, startup objects, `libc.so` linker
script, `libc.so.6`, `libc_nonshared.a`, and the real x86_64 dynamic loader.
The Linux UAPI bytes are copied from the exact admitted package input so later
GCC target-runtime construction receives one coherent sysroot.

This is a real glibc compile/link surface, but it is not target runtime
authority. The package does not carry `/etc` policy, mutable `/var` state,
locales, service state, compiler tools, or a runtime dependency closure. It
does not create synthetic libc or loader ABI bytes. Final `glibc` remains the
separate deployable C-library authority and declares its own runtime closure.

A `libgcc` recipe must consume `glibc-bootstrap` through `--with-sysroot` as its
single libc/kernel construction view. It must not add final `glibc` as a build
input, because build inputs contribute their runtime closure and final glibc
already requires libgcc. Keeping the construction-only sysroot separate lets
libgcc link against the real target libc ABI without creating a forbidden build
cycle.

### GCC low-level runtime

`libgcc` is the first package whose final runtime closure intentionally closes a
cycle. Its build input is `glibc-bootstrap`; its target runtime requirement is
final `glibc`. The existing final glibc recipe already records the reciprocal
runtime requirement. In authority notation:

- `libgcc build -> glibc-bootstrap`;
- `libgcc run -> glibc`;
- `glibc run -> libgcc`.

`glibc` and `libgcc` form the first native runtime cohort. The resolver may
retain the finite runtime cycle and the transaction layer may collapse that
cycle into one cohort without inventing cyclic execution precedence. The build
plane remains acyclic because `glibc-bootstrap` has no `run -> libgcc` edge.

The libgcc package is intentionally narrower than GCC. GCC 16.1.0 source is
used only to build the compiler machinery required for `all-target-libgcc`.
Only `libgcc_s.so.1` is projected into the package artifact. Compiler drivers,
GCC-private static runtime objects, libstdc++, sanitizer runtimes, libatomic,
and other target libraries remain future authorities. The produced shared
runtime is checked for the final x86_64 ABI names `libc.so.6` and
`ld-linux-x86-64.so.2` and must not retain an RPATH or RUNPATH into its
construction environment.

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

## Bootstrap qualification campaign

The repository carries a thin qualification harness for the first native
construction closure. It is not another recipe executor or dependency solver.
`make bootstrap` admits exactly one `pkgctl build libgcc` command; the native
resolver discovers the build closure:

```text
linux-api-headers -> glibc-bootstrap -> libgcc
```

The harness never runs recipe programs directly and never loops over package
names to construct them independently. Source acquisition, package-input
projection, isolated execution, package-image creation, durable evidence,
resume, and artifact publication remain `pkgctl` and library authority.

### Seed-root authority

The initial campaign still needs an external construction root because the
native compiler/tool packages do not yet exist. That root must be a disposable
root view supplied explicitly with `BOOTSTRAP_BUILD_ROOT`; the harness refuses
the live `/` hierarchy. The root view may retain normal root ownership. When
mount-point topology is absent, `bootstrap-init` may use the explicitly supplied
`BOOTSTRAP_PRIVILEGE` command only to create the empty directories required by
the native build adapter. Repository-side workspace creation remains unprivileged.

`BOOTSTRAP_SEED_SHA256` names the seed-root authority. For reproducibility
qualification it should be the SHA-256 of the exact rootfs archive used to
materialize the root view. The harness domain-separates that caller-supplied
seed identity into the empty construction campaign's state-target binding and
command nonce. These are qualification identities only. They are not installed
system truth and must not be reused as future rootfs deployment identities.

The harness preflights the current external seed capabilities required by the
three recipes, including the shell, compiler/C++ compiler, binutils inspection,
GNU make, Python, ordinary POSIX/GNU build utilities, and GMP/MPFR/MPC
headers. This inventory is intentionally visible: later native package
authority should make entries disappear from the seed requirement rather than
silently inheriting them forever.

The build interpreter is an exact regular executable inside the supplied root
view. `pkgctl` inspects and binds its bytes before execution; the interpreter's
loader and shared-library paths then resolve inside the isolated construction
root.

### Private controller toolchain

The bootstrap controller itself is not a host `/usr` tool. `BOOTSTRAP_TOOLCHAIN_PREFIX`
binds the private prefix produced by the native zoo build harness. When omitted,
the campaign uses `NEW_TOOLCHAIN_PREFIX` if already exported by `.toolchain-env`;
otherwise it uses the sibling `../.toolchain` prefix expected by the default
repository layout.

`pkgctl` and `pkgstate-init` must resolve beneath that exact prefix. Their host
execution environment mirrors the native zoo harness: the prefix `bin` leads
`PATH`, the prefix pkg-config directories lead `PKG_CONFIG_PATH`, the prefix
`lib` leads `LD_LIBRARY_PATH`, and the prefix leads `CMAKE_PREFIX_PATH`. A
privileged controller invocation executes `PRIVILEGE env ... pkgctl`; the
private dynamic-library path is therefore established after privilege entry
rather than relying on `sudo` to preserve loader-sensitive environment names.
The harness never falls back to a same-named system `pkgctl`.

### Native supervisor credentials

Construction and check credentials are controller authority, not a bootstrap
configuration knob. The native executor requires those credentials to equal the
credentials of the supervising `pkgctl` process before transaction execution.
`bootstrap-init` therefore observes UID, primary GID, and supplementary groups
through the same optional `BOOTSTRAP_PRIVILEGE` boundary used to launch `pkgctl`
and retains that exact tuple in the workspace marker. Start and resume
re-observe the tuple and fail closed on drift. The Makefile exposes no arbitrary
`BOOTSTRAP_BUILD_UID`, `BOOTSTRAP_BUILD_GID`, or supplementary-group override.

### Start and resume

`bootstrap-init` creates one empty provider-owned canonical state store using
`pkgstate-init`, the private runtime hierarchy, and the public artifact root.
It records the exact seed identity, build-root coordinate, interpreter, clean
collection commit, and deterministic qualification nonce in the local
workspace marker.

`bootstrap` starts one bounded command. `bootstrap-resume` carries no catalog,
goal, architecture, or binding restatement; it uses `pkgctl build --resume`
and the command evidence admitted at start. `BOOTSTRAP_MAX_STEPS` is a positive
per-invocation execution bound and may be increased for a later resume without
turning the harness into an implicit retry loop.

### Artifact qualification

`bootstrap-check` requires a terminal successful build frontend result and
exactly three published artifacts: `linux-api-headers`, `glibc-bootstrap`, and
`libgcc`. It independently verifies the retained artifact SHA-256 values and
key archive members, then checks the extracted `libgcc_s.so.1` SONAME, final
`libc.so.6` and `ld-linux-x86-64.so.2` dependencies, and absence of
RPATH/RUNPATH.

The command emits `BOOTSTRAP_WORK/bootstrap.manifest`, a path-independent
manifest containing the seed digest, admitted collection commit, and each
artifact's SHA-256, binding identity, and image identity. Two builds using the
same collection commit and exact seed-root archive on different execution hosts
should be compared by this manifest. A difference is evidence to investigate;
the harness does not normalize divergent results into agreement.
