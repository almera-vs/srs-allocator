setup:
	bash scripts/setup_toolchain.sh

fetch-redis:
	bash scripts/fetch_redis.sh

build-allocator:
	bash scripts/build_secure_allocator.sh

prove:
	bash scripts/prove_secure_pool.sh

build-redis:
	bash scripts/build_secure_redis.sh

verify:
	bash scripts/verify_zeroization.sh
