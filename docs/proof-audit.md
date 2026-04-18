# Proof Audit

This document captures the strict-profile proof snapshot and non-vacuity checks used in this repository.

## Strict profile snapshot

From `build/obj/gnatprove/gnatprove.out`:

- Total checks: 237
- Flow checks: 83
- Prover checks: 154
- Unproved checks: 0
- Max steps used for successful proof: 6759
- No proved check exceeded 1 second.

## Non-vacuity evidence

- Detailed GNATprove report entries state `0 pragma Assume statements` for analyzed entities.
- Repository source scan contains no `pragma Assume` and no `pragma Trusted`.
- Core security predicates are explicit quantified definitions in `src/spark/secure_pool.ads`:
  - `Range_Zeroed_Bounds`: `(for all I in First .. Last => Pool (I) = Byte'(0))`
  - `Active_Disjointness`: nested `for all` quantification over descriptor slots.

## Reproduction

```bash
PROFILE=strict scripts/prove_secure_pool.sh
if grep -RIn --include='*.adb' --include='*.ads' --include='*.gpr' -E 'pragma[[:space:]]+(Assume|Trusted)' src config secure_allocator.gpr; then
  exit 1
fi
```

## Evidence files

- `build/obj/gnatprove/gnatprove.out`
- `scripts/prove_secure_pool.sh`
- `scripts/generate_proof_badge.py`
- `.github/workflows/ci.yml`

## Scope note

The audit covers analyzed SPARK entities and contracts in this repository snapshot. It does not by itself prove properties outside those units (for example, all Redis deployment configurations).
