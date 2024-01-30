const lib = @import("lib.zig");
const c = @cImport(@cInclude("wasmtime.h"));

/// Opaque struct representing a frame of a wasm stack trace.
pub const Frame = opaque {
    /// Destroys the frame
    pub fn delete(f: *Frame) void {
        c.wasm_frame_delete(@ptrCast(f));
    }

    /// Returns a copy of the provided frame.
    ///
    /// The caller is expected to call `delete` on the returned frame.
    pub fn copy(f: *const Frame) *Frame {
        return @ptrCast(c.wasm_frame_copy(@ptrCast(f)));
    }

    /// Unimplemented in Wasmtime, aborts the process if called.
    pub fn instance(f: *const Frame) *lib.Instance {
        return @ptrCast(c.wasm_frame_instance(@ptrCast(f)));
    }

    /// Returns the function index in the original wasm module that this frame
    /// corresponds to.
    pub fn funcIndex(f: *const Frame) u32 {
        return c.wasm_frame_func_index(@ptrCast(f));
    }

    /// Returns the byte offset from the beginning of the function in the
    /// original wasm file to the instruction this frame points to.
    pub fn funcOffset(f: *const Frame) usize {
        return c.wasm_frame_func_offset(@ptrCast(f));
    }

    /// Returns the byte offset from the beginning of the original wasm file
    /// to the instruction this frame points to.
    pub fn moduleOffset(f: *const Frame) usize {
        return c.wasm_frame_module_offset(@ptrCast(f));
    }
};

pub const Trap = opaque {
    pub fn delete(t: *Trap) void {
        c.wasm_trap_delete(@ptrCast(t));
    }

    pub fn copy(t: *const Trap) *Trap {
        return c.wasm_trap_copy(@ptrCast(t));
    }

    pub fn same(left: *const Trap, right: *const Trap) bool {
        return c.wasm_trap_same(@ptrCast(left), @ptrCast(right));
    }

    pub fn getHostInfo(t: *const Trap) *anyopaque {
        return c.wasm_trap_get_host_info(@ptrCast(t));
    }

    pub fn setHostInfo(t: *Trap, ptr: *anyopaque) void {
        c.wasm_trap_set_host_info(@ptrCast(t), ptr);
    }

    pub fn setHostInfoWithFinalizer(t: *Trap, ptr: *anyopaque, f: *const fn (*anyopaque) callconv(.C) void) void {
        c.wasm_trap_set_host_info_with_finalizer(@ptrCast(t), ptr, f);
    }
};
