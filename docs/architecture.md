# Architecture

## Components

- `src/spark/secure_pool.ads` + `src/spark/secure_pool.adb`: core allocator model and proofs.
- `src/ffi/secure_alloc_c.ads` + `src/ffi/secure_alloc_c.adb`: C ABI bridge used by Redis integration.
- `src/runtime/secure_allocator_runtime.adb`: lazy initialization wrapper for runtime calls.

## Allocator model

- The pool is a fixed-size byte array (`Pool_Size = 268_435_456`) managed by descriptor slots.
- A descriptor tracks `Start`, `Length`, `In_Use`, and `Active`.
- Allocation requests are aligned (`Alignment_Bytes = 16`) and serviced by best-fit search.
- Freeing zeroizes the allocation interval before descriptor reuse.

## Key invariants

- `Range_Within_Pool`: active ranges remain in bounds.
- `Descriptors_Disjoint`: active descriptors do not overlap.
- `Active_Disjointness`: pairwise disjointness over active descriptor set.
- `State_Consistent`: currently defined as `Active_Disjointness`.

## Security-relevant behavior

- `Allocate`: postconditions include allocation integrity and zeroized returned range.
- `Zero_Allocation`: postcondition requires full interval zeroization.
- `Free`: outputs exact cleared bounds and proves zeroization on that interval.
- `Reallocate`: preserves allocation integrity contracts for the returned block.

## Verification boundary

SPARK proofs cover analyzed Ada units and declared contracts. External C/Redis integration behavior is outside SPARK proof scope and is handled via build/run verification steps.
