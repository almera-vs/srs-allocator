# Contributing to SRS Allocator

Thanks for contributing.

## Development setup

From the repository root:

```bash
make setup
```

This bootstraps a local Alire toolchain under `.tools/` and selects the pinned compiler/prover versions from `alire.toml`.

## Build and proof workflow

Run these before opening a pull request:

```bash
make build-allocator
PROFILE=strict scripts/prove_secure_pool.sh
if grep -RIn --include='*.adb' --include='*.ads' --include='*.gpr' -E 'pragma[[:space:]]+(Assume|Trusted)' src config secure_allocator.gpr; then
  exit 1
fi
```

If your change affects Redis integration paths, also run:

```bash
make build-redis
make verify
```

## Pull request expectations

- Explain the change and why it is needed.
- Call out any contract/invariant changes in `src/spark/secure_pool.ads`.
- Keep proofs non-vacuous: do not introduce `pragma Assume` or `pragma Trusted`.
- Keep behavior stable unless the PR explicitly proposes a behavior change.
- Update documentation when security properties or workflows change.

## Commit style

This repository currently uses concise conventional prefixes such as:

- `feat:`
- `fix:`
- `chore:`
- `ci:`

## Security reports

Please follow `SECURITY.md` for vulnerability reporting.
