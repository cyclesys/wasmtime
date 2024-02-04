const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const UserData = @import("UserData.zig");

/// A reference type: either a funcref or an externref.
pub const Ref = opaque {
    /// Delete a reference.
    pub fn delete(r: *Ref) void {
        c.wasm_ref_delete(@ptrCast(r));
    }

    /// Copy a reference.
    pub fn copy(r: *const Ref) *Ref {
        return @ptrCast(c.wasm_ref_copy(@ptrCast(r)));
    }

    /// Are the given references pointing to the same externref?
    ///
    /// Note: Wasmtime does not support checking funcrefs for equality, and this
    /// function will always return false for funcrefs.
    pub fn same(l: *const Ref, r: *const Ref) bool {
        return c.wasm_ref_same(@ptrCast(l), @ptrCast(r));
    }
};
