//! Rust wrapper for Equi-X and HashX
//!
//! This is a Rust wrapper for the original C implementation of Equi-X and
//! HashX, as used by the C implementation of Tor. For cross-compatibility
//! testing conducted by Arti.
//!
//! The wrapper statically links with a modified version of the original
//! implementation by tevador, covered by the LGPL version 3. This modified
//! codebase is maintained as an ext module within the tor source distribution.
//!
//! Equi-X and HashX are `Copyright (c) 2020 tevador <tevador@gmail.com>`.
//! See `LICENSE` for licensing information.
//!

use core::ffi::c_void;
use core::mem;
use core::ptr::null_mut;

pub mod ffi {
    //! Low-level access to the C API

    #![allow(non_upper_case_globals)]
    #![allow(non_camel_case_types)]
    #![allow(non_snake_case)]

    include!(concat!(env!("OUT_DIR"), "/bindings.rs"));
}

/// Type parameter for [`HashX::new()`]
pub type HashXType = ffi::hashx_type;

/// Result codes for HashX
pub type HashXResult = ffi::hashx_result;

/// Configured size of the HashX output. Always 8 in this implementation.
pub const HASHX_SIZE: usize = ffi::HASHX_SIZE as usize;

/// Output value obtained by executing a HashX hash function
pub type HashXOutput = [u8; HASHX_SIZE];

/// Type for callback functions that inspect or replace the pseudorandom stream
pub type RngCallback = Box<dyn FnMut(u64) -> u64>;

/// Safe wrapper around a HashX context
pub struct HashX {
    ctx: *mut ffi::hashx_ctx,
    rng_callback: Option<RngCallback>,
}

impl HashX {
    /// Allocate a new HashX context
    pub fn new(ht: HashXType) -> Self {
        let ctx = unsafe { ffi::hashx_alloc(ht) };
        if ctx.is_null() {
            panic!("out of memory in hashx_alloc");
        }
        Self {
            ctx,
            rng_callback: None,
        }
    }

    /// Create a new hash function within this context, using the given seed
    ///
    /// May fail if the seed is unusable or if a runtime compiler
    /// error occurs while the interpreter is disabled.
    #[inline(always)]
    pub fn make(&mut self, seed: &[u8]) -> HashXResult {
        unsafe { ffi::hashx_make(self.ctx, seed.as_ptr() as *const c_void, seed.len()) }
    }

    /// Check which implementation was selected by `make`
    #[inline(always)]
    pub fn query_type(&mut self) -> Result<HashXType, HashXResult> {
        let mut buffer = HashXType::HASHX_TYPE_INTERPRETED; // Arbitrary default
        let result =
            unsafe { ffi::hashx_query_type(self.ctx, &mut buffer as *mut ffi::hashx_type) };
        match result {
            HashXResult::HASHX_OK => Ok(buffer),
            e => Err(e),
        }
    }

    /// Execute the hash function for a given input
    #[inline(always)]
    pub fn exec(&mut self, input: u64) -> Result<HashXOutput, HashXResult> {
        let mut buffer: HashXOutput = Default::default();
        let result =
            unsafe { ffi::hashx_exec(self.ctx, input, &mut buffer as *mut u8 as *mut c_void) };
        match result {
            HashXResult::HASHX_OK => Ok(buffer),
            e => Err(e),
        }
    }

    /// Set a callback function that may inspect and/or modify the internal
    /// pseudorandom number stream used by this context.
    ///
    /// The function will be owned by this context, and it replaces any
    /// previous function that may have been set. Returns the previous callback
    /// if any.
    pub fn rng_callback(&mut self, callback: Option<RngCallback>) -> Option<RngCallback> {
        // Keep ownership of our Rust value in the context wrapper, to match
        // the lifetime of the mutable pointer that the C API saves.
        let result = mem::replace(&mut self.rng_callback, callback);
        match &mut self.rng_callback {
            None => unsafe { ffi::hashx_rng_callback(self.ctx, None, null_mut()) },
            Some(callback) => unsafe {
                ffi::hashx_rng_callback(
                    self.ctx,
                    Some(wrapper),
                    callback as *mut RngCallback as *mut c_void,
                );
            },
        }
        unsafe extern "C" fn wrapper(buffer: *mut u64, callback: *mut c_void) {
            let callback: &mut RngCallback = unsafe { mem::transmute(callback) };
            buffer.write(callback(buffer.read()));
        }
        result
    }
}

impl Drop for HashX {
    fn drop(&mut self) {
        let ctx = mem::replace(&mut self.ctx, null_mut());
        unsafe {
            ffi::hashx_free(ctx);
        }
    }
}

/// Option flags for [`EquiX::new()`]
pub type EquiXFlags = ffi::equix_ctx_flags;

/// A single Equi-X solution
pub type EquiXSolution = ffi::equix_solution;

/// Flags with additional information about solutions
pub type EquiXSolutionFlags = ffi::equix_solution_flags;

/// A buffer with space for several Equi-X solutions
pub type EquiXSolutionsBuffer = ffi::equix_solutions_buffer;

/// Number of indices in a single Equi-X solution
pub const EQUIX_NUM_IDX: usize = ffi::EQUIX_NUM_IDX as usize;

/// Maximum number of Equi-X solutions we will return at once
pub const EQUIX_MAX_SOLS: usize = ffi::EQUIX_MAX_SOLS as usize;

impl Default for EquiXSolutionsBuffer {
    fn default() -> Self {
        Self {
            count: 0,
            flags: ffi::equix_solution_flags(0),
            sols: [EquiXSolution {
                idx: [0; EQUIX_NUM_IDX],
            }; EQUIX_MAX_SOLS],
        }
    }
}

/// Result codes for Equi-X
pub type EquiXResult = ffi::equix_result;

/// Safe wrapper around an Equi-X context
pub struct EquiX(*mut ffi::equix_ctx);

impl EquiX {
    /// Allocate a new Equi-X context
    pub fn new(flags: EquiXFlags) -> Self {
        let ctx = unsafe { ffi::equix_alloc(flags) };
        if ctx.is_null() {
            panic!("out of memory in equix_alloc");
        }
        Self(ctx)
    }

    /// Verify an Equi-X solution against a particular challenge
    #[inline(always)]
    pub fn verify(&mut self, challenge: &[u8], solution: &EquiXSolution) -> EquiXResult {
        unsafe {
            ffi::equix_verify(
                self.0,
                challenge.as_ptr() as *const c_void,
                challenge.len(),
                solution as *const ffi::equix_solution,
            )
        }
    }

    /// Run the solver, returning a variable number of solutions for a challenge
    #[inline(always)]
    pub fn solve(&mut self, challenge: &[u8], buffer: &mut EquiXSolutionsBuffer) -> EquiXResult {
        unsafe {
            ffi::equix_solve(
                self.0,
                challenge.as_ptr() as *const c_void,
                challenge.len(),
                buffer as *mut ffi::equix_solutions_buffer,
            )
        }
    }
}

impl Drop for EquiX {
    fn drop(&mut self) {
        let ctx = mem::replace(&mut self.0, null_mut());
        unsafe {
            ffi::equix_free(ctx);
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::*;
    use hex_literal::hex;
    use std::cell::RefCell;
    use std::sync::Arc;

    #[test]
    fn equix_context() {
        let _ = EquiX::new(EquiXFlags::EQUIX_CTX_TRY_COMPILE | EquiXFlags::EQUIX_CTX_SOLVE);
        let _ = EquiX::new(EquiXFlags::EQUIX_CTX_SOLVE);
        let _ = EquiX::new(EquiXFlags::EQUIX_CTX_VERIFY);
    }

    #[test]
    fn equix_verify_only() {
        let mut ctx = EquiX::new(EquiXFlags::EQUIX_CTX_TRY_COMPILE | EquiXFlags::EQUIX_CTX_VERIFY);

        assert_eq!(
            ctx.verify(
                b"a",
                &EquiXSolution {
                    idx: [0x2227, 0xa173, 0x365a, 0xb47d, 0x1bb2, 0xa077, 0x0d5e, 0xf25f]
                }
            ),
            EquiXResult::EQUIX_OK
        );
        assert_eq!(
            ctx.verify(
                b"a",
                &EquiXSolution {
                    idx: [0x1bb2, 0xa077, 0x0d5e, 0xf25f, 0x2220, 0xa173, 0x365a, 0xb47d]
                }
            ),
            EquiXResult::EQUIX_FAIL_ORDER
        );
        assert_eq!(
            ctx.verify(
                b"a",
                &EquiXSolution {
                    idx: [0x2220, 0xa173, 0x365a, 0xb47d, 0x1bb2, 0xa077, 0x0d5e, 0xf25f]
                }
            ),
            EquiXResult::EQUIX_FAIL_PARTIAL_SUM
        );
    }

    #[test]
    fn equix_solve_only() {
        let mut ctx = EquiX::new(EquiXFlags::EQUIX_CTX_TRY_COMPILE | EquiXFlags::EQUIX_CTX_SOLVE);
        let mut buffer = Default::default();
        assert_eq!(
            ctx.solve(b"01234567890123456789", &mut buffer),
            EquiXResult::EQUIX_OK
        );
        assert_eq!(buffer.count, 5);
        assert_eq!(
            buffer.sols[0].idx,
            [0x4803, 0x6775, 0xc5c9, 0xd1b0, 0x1bc3, 0xe4f6, 0x4027, 0xf5ad,]
        );
        assert_eq!(
            buffer.sols[1].idx,
            [0x5a8a, 0x9542, 0xef99, 0xf0b9, 0x4905, 0x4e29, 0x2da5, 0xfbd5,]
        );
        assert_eq!(
            buffer.sols[2].idx,
            [0x4c79, 0xc935, 0x2bcb, 0xcd0f, 0x0362, 0x9fa9, 0xa62e, 0xf83a,]
        );
        assert_eq!(
            buffer.sols[3].idx,
            [0x5878, 0x6edf, 0x1e00, 0xf5e3, 0x43de, 0x9212, 0xd01e, 0xfd11,]
        );
        assert_eq!(
            buffer.sols[4].idx,
            [0x0b69, 0x2d17, 0x01be, 0x6cb4, 0x0fba, 0x4a9e, 0x8d75, 0xa50f,]
        );
    }

    #[test]
    fn hashx_context() {
        // Context creation should always succeed
        let _ = HashX::new(HashXType::HASHX_TYPE_INTERPRETED);
        let _ = HashX::new(HashXType::HASHX_TYPE_COMPILED);
        let _ = HashX::new(HashXType::HASHX_TRY_COMPILE);
    }

    #[test]
    fn bad_seeds() {
        // Some seed values we expect to fail (and one control).
        // Also tests query_type while we're here.
        let mut ctx = HashX::new(HashXType::HASHX_TYPE_INTERPRETED);
        assert_eq!(ctx.query_type(), Err(HashXResult::HASHX_FAIL_UNPREPARED));
        assert_eq!(ctx.make(b"qfjsfv"), HashXResult::HASHX_FAIL_SEED);
        assert_eq!(ctx.query_type(), Err(HashXResult::HASHX_FAIL_UNPREPARED));
        assert_eq!(ctx.make(b"llompmb"), HashXResult::HASHX_OK);
        assert_eq!(ctx.query_type(), Ok(HashXType::HASHX_TYPE_INTERPRETED));
        assert_eq!(ctx.make(b"mhelht"), HashXResult::HASHX_FAIL_SEED);
        assert_eq!(ctx.query_type(), Err(HashXResult::HASHX_FAIL_UNPREPARED));
    }

    #[test]
    fn hash_values() {
        // Some sample hash values
        let mut ctx = HashX::new(HashXType::HASHX_TRY_COMPILE);
        assert_eq!(ctx.make(b"ebrazua"), HashXResult::HASHX_OK);
        assert_eq!(ctx.exec(0xebc19ba9cafb0863), Ok(hex!("41cb0b4b24551d26")));
        assert_eq!(ctx.make(b"This is a test\0"), HashXResult::HASHX_OK);
        assert_eq!(ctx.exec(0), Ok(hex!("2b2f54567dcbea98")));
        assert_eq!(ctx.exec(123456), Ok(hex!("aebdd50aa67c93af")));
        assert_eq!(
            ctx.make(b"Lorem ipsum dolor sit amet\0"),
            HashXResult::HASHX_OK
        );
        assert_eq!(ctx.exec(123456), Ok(hex!("ab3d155bf4bbb0aa")));
        assert_eq!(ctx.exec(987654321123456789), Ok(hex!("8dfef0497c323274")));
    }

    #[test]
    fn rng_callback_read() {
        // Use a Rng callback to read the sequence of pseudorandom numbers
        // without changing them, and spot check the list we get back.
        let mut ctx = HashX::new(HashXType::HASHX_TRY_COMPILE);
        let seq = Arc::new(RefCell::new(Vec::new()));
        {
            let seq = seq.clone();
            ctx.rng_callback(Some(Box::new(move |value| {
                seq.borrow_mut().push(value);
                value
            })));
        }
        assert_eq!(seq.borrow().len(), 0);
        assert_eq!(ctx.make(b"abc"), HashXResult::HASHX_OK);
        assert_eq!(ctx.exec(12345).unwrap(), hex!("c0bc95da7cc30f37"));
        assert_eq!(seq.borrow().len(), 563);
        assert_eq!(
            seq.borrow()[..4],
            [
                0xf695edd02205449d,
                0x51c1ac51cd19a7d1,
                0xadf4cb303b9814cf,
                0x79793a52d965083d
            ]
        );
    }

    #[test]
    fn rng_callback_replace() {
        // Use a Rng callback to replace the random number stream.
        // We have to choose the replacement somewhat carefully since
        // many stationary replacement values will cause infinite loops.
        let mut ctx = HashX::new(HashXType::HASHX_TYPE_INTERPRETED);
        let counter = Arc::new(RefCell::new(0u32));
        {
            let counter = counter.clone();
            ctx.rng_callback(Some(Box::new(move |_value| {
                *counter.borrow_mut() += 1;
                0x0807060504030201
            })));
        }
        assert_eq!(*counter.borrow(), 0);
        assert_eq!(ctx.make(b"abc"), HashXResult::HASHX_OK);
        assert_eq!(ctx.exec(12345).unwrap(), hex!("825a9b6dd5d074af"));
        assert_eq!(*counter.borrow(), 575);
    }
}