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
It then requires the current foundation recipe set to remain limited to
the stable ABI/runtime substrate plus the two admitted construction-only cycle
breakers. It also requires `@foundation` to contain only deployable members and
requires final glibc to fail closed while installing the exact `C.UTF-8` locale
named by the native build policy. It also freezes glibc's runtime authority on
`filesystem` plus `libgcc`: the first edge binds the merged-/usr interpreter
topology and the second retains the reciprocal compiler-runtime cohort.

This test does not prove seed retirement. That proof belongs to the product
controller: after composing the foundation construction root it must make the
historical seed inaccessible and successfully execute a new construction
session without host/seed path leakage.
