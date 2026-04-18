# Threat Model

## Goals

- Reduce residual secret exposure in allocator-managed memory by deterministic zeroization.
- Maintain allocation integrity properties under formal contracts (bounds, non-overlap, state consistency).

## Assets

- In-memory request data and application payload fragments.
- Allocator metadata (descriptor table state).

## Adversary capabilities (in scope)

- Reads stale bytes from reused allocator memory if zeroization is absent or incomplete.
- Triggers allocation/free/reallocation sequences to exploit allocator state bugs.

## Mitigations in this project

- Zeroization contracts and implementation paths (`Allocate`, `Zero_Allocation`, `Free`).
- Descriptor disjointness/state invariants proven by GNATprove.
- CI gate for strict proof pass and assumption/trust pragma absence.

## Out of scope

- Side-channel resistance (timing, cache, microarchitectural channels).
- Full system compromise where attacker can inspect process memory directly.
- Properties outside analyzed Ada/SPARK units (for example all Redis integration/runtime contexts).

## Assumptions

- The proven contracts reflect intended security semantics.
- Toolchain and CI environment execute configured proof profile consistently.
