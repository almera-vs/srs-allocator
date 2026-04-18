# Secure Redis SPARK Allocator

[![Build](https://github.com/almera-vs/srs-allocator/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/almera-vs/srs-allocator/actions/workflows/ci.yml)
[![Proof Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/almera-vs/srs-allocator/gh-pages/proof-badge.json)](https://github.com/almera-vs/srs-allocator/actions/workflows/ci.yml)

This project adds an Ada/SPARK allocator for Redis 7.4.2. It is built as a static library and linked into a patched Redis build so that freed blocks are cleared before they are reused. The repository also keeps proof logs, a zeroization check, and a benchmark snapshot as release evidence.

## Project Documentation

- Architecture: `docs/architecture.md`
- Proof audit: `docs/proof-audit.md`
- Threat model: `docs/threat-model.md`
- Contributing guide: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`

## Zeroization on Free

“Zeroization on free” means the allocator overwrites a block with zeroes before returning it to the free pool. This matters because data such as passwords, tokens, or request payloads can otherwise remain in memory after the application is done with them. Clearing the bytes reduces the chance that later code, diagnostics, or memory reuse exposes stale secrets.

## Formal Verification

In this allocator, formal verification means using SPARK and GNATprove to check the code against stated contracts and safety rules. The proof run can confirm things like initialization, flow dependencies, range checks, and contract conditions for the analyzed units. It is evidence about the checked code, not a guarantee about every Redis configuration or external caller.

## Proof Audit (Strict Profile)

GNATprove strict-profile summary (`build/obj/gnatprove/gnatprove.out`):

- Total checks: 237
- Flow checks: 83
- Prover checks: 154
- Unproved checks: 0
- Max steps used: 6759
- Most difficult proved checks: no check exceeded 1 second

### Non-Vacuity Checks

- Detailed report states `0 pragma Assume statements` for analyzed entities.
- Source scan found no `pragma Assume` or `pragma Trusted` pragmas.

### Reproduce the Audit

```bash
make prove
if grep -RIn --include='*.adb' --include='*.ads' --include='*.gpr' -E 'pragma[[:space:]]+(Assume|Trusted)' src config secure_allocator.gpr; then
  exit 1
fi
```

### Evidence Files

- `build/obj/gnatprove/gnatprove.out`
- `scripts/prove_secure_pool.sh`
- `gnatprove.conf`

Scope: this audit covers the analyzed SPARK entities and contracts in this repository snapshot.

## Security / Performance Trade-off

Clearing memory on free costs time. That extra work can reduce throughput or increase latency compared with a plain allocator, especially under allocation-heavy workloads. In return, it lowers the chance that sensitive data stays in memory after free. The current benchmark snapshot is in `build/bench-secure.csv`.

## How to use it

From the project root:

```bash
make setup
make build-allocator
make prove
make build-redis
make verify
```

- `make setup` prepares the Ada toolchain.
- `make build-allocator` builds the allocator library.
- `make prove` runs GNATprove on the SPARK allocator code.
- `make build-redis` builds Redis with the secure allocator enabled.
- `make verify` runs the zeroization check against the built Redis server.

Release evidence is copied to `build/artifacts/release-evidence/`.
