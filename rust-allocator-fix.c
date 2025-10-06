// Fix for undefined symbol: __rust_no_alloc_shim_is_unstable
// This file provides the missing symbols for Rust allocator

// v1 symbol (used by older Rust code)
__attribute__((weak))
void __rust_no_alloc_shim_is_unstable(void) {}

// v2 symbol (used by newer Rust code)
__attribute__((weak))
void __rust_no_alloc_shim_is_unstable_v2(void) {}