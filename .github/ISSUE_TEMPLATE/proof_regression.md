---
name: Proof regression
about: Report a GNATprove failure or contract regression
title: "[proof] "
labels: proof
assignees: ""
---

## Failing check

- File and line:
- Check class (flow/runtime/assertion/contract):
- Prover output snippet:

## Last known good

- Commit/tag:
- Proof profile (`strict` or `passed`):

## Reproduction

```bash
PROFILE=strict scripts/prove_secure_pool.sh
```

## Suspected change

Which contract/invariant or implementation change likely triggered this?
