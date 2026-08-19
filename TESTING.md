# Testing pkgsrc-foundation

`pkgsrc-foundation` is metadata, but its metadata closes a bootstrap authority
boundary and therefore has source-level contracts worth testing before any
multi-hour product bootstrap is started.

Run:

```sh
python3 .tests/contracts/foundation_boundary_test.py
```

The contract first requires every visible top-level directory to be a package
recipe directory. Repository-only qualification material lives below hidden
`.tests/` so catalog acquisition never has to special-case repository metadata.
It then requires `@foundation` to contain only the stable deployable
`filesystem`, `glibc`, and `libgcc` cohort, and rejects promotion of any
construction-only package into that profile.

The first Stage-B seed-retirement substrate is also source-qualified. Exact
GMP/MPFR/MPC/Binutils/GCC coordinates and source digests are pinned; the
GMP -> MPFR -> MPC direct build/check/runtime edges are checked independently;
and Binutils must remain a narrow construction payload without zlib, zstd,
libelf, Jansson, libstdc++, gprofng, or persistent build-path authority. The
multiprecision packages must retain the ABI SONAME and static construction
surfaces consumed by `gcc-bootstrap`. The compiler-bootstrap contract then
requires an explicitly composed final-glibc + Linux-UAPI build sysroot, direct Linux-header authority in BUILD/CHECK/RUN, explicit execution-root
assembler/linker coordinates, C/C++ plus static target support, no LTO/shared bootstrap runtime,
no retained build/seed search coordinates, and direct check witnesses compiled
with the exact admitted glibc and Binutils inputs. This still does not create a
complete shell/userspace execution universe, so the contract deliberately
rejects an `@construction` profile while this closure remains incomplete.

Final glibc is still required to fail closed while installing the exact
`C.UTF-8` locale named by the native build policy. Its runtime authority remains
`filesystem` plus `libgcc`: the first edge binds the merged-/usr interpreter
topology and the second retains the reciprocal compiler-runtime cohort.

This source test does not prove that the new recipes actually build, and it does
not prove seed retirement. The product controller must first construct and check
these artifacts under admitted S0 authority. Once the complete construction
profile exists, the product must compose a separate managed construction root,
make the historical seed physically inaccessible, and execute a **new**
construction transaction with the new root and interpreter. A later
construction-root rebuild is the stronger test for tools that escaped the
explicit capability probe.
