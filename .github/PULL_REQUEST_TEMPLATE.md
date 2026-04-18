## Summary

-

## Why this change

-

## Verification

- [ ] `make build-allocator`
- [ ] `PROFILE=strict scripts/prove_secure_pool.sh`
- [ ] No `pragma Assume` / `pragma Trusted` introduced
- [ ] (If applicable) `make build-redis`
- [ ] (If applicable) `make verify`

## Security and proof impact

- Contracts/invariants touched:
- Any expected change to proof obligations:
- Any behavior changes to allocation/free/reallocation:

## Notes

-
