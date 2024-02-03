const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");
const vec = @import("vec.zig");

/// Opaque struct representing a frame of a wasm stack trace.
pub const Frame = opaque {
    /// Deletes the frame
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

    /// Returns a human-readable name for this frame's function.
    ///
    /// This function will attempt to load a human-readable name for function this
    /// frame points to. This function may return `null`.
    ///
    /// The lifetime of the returned name is the same as the `Frame` itself.
    pub fn funcName(f: *const Frame) ?*const lib.Name {
        return @ptrCast(c.wasmtime_frame_func_name(@ptrCast(f)));
    }

    /// Returns the byte offset from the beginning of the original wasm file
    /// to the instruction this frame points to.
    pub fn moduleOffset(f: *const Frame) usize {
        return c.wasm_frame_module_offset(@ptrCast(f));
    }

    /// Returns a human-readable name for this frame's module.
    ///
    /// This function will attempt to load a human-readable name for module this
    /// frame points to. This function may return `null`.
    ///
    /// The lifetime of the returned name is the same as the `Frame` itself.
    pub fn moduleName(f: *const Frame) ?*const lib.Name {
        return @ptrCast(c.wasmtime_frame_module_name(@ptrCast(f)));
    }
};

pub const FrameVec = vec.Vec(*lib.Frame, "frame");

/// Opaque struct representing a wasm trap.
pub const Trap = opaque {
    /// Code of an instruction trap.
    pub const Code = enum {
        /// The current stack space was exhausted.
        stack_overflow,

        /// An out-of-bounds memory access.
        memory_out_of_bounds,

        /// A wasm atomic operation was presented with a not-naturally-aligned
        /// linear-memory address.
        heap_misaligned,

        /// An out-of-bounds access to a table.
        table_out_of_bounds,

        /// Indirect call to a null table entry.
        indirect_call_to_null,

        /// Signature mismatch on indirect call.
        bad_signature,

        /// An integer arithmetic operation caused an overflow.
        integer_overflow,

        /// An integer division by zero.
        integer_division_by_zero,

        /// Failed float-to-int conversion.
        bad_conversion_to_integer,

        /// Code that was supposed to have been unreachable was reached.
        unreachable_code_reached,

        /// Execution has potentially run too long and may be interrupted.
        interrupt,

        /// Execution has run out of the configured fuel amount.
        out_of_fuel,
    };

    /// Creates a new trap.
    ///
    /// The `Trap` returned is owned by the caller.
    pub fn new(msg: []const u8) *Trap {
        return @ptrCast(c.wasmtime_trap_new(@ptrCast(msg.ptr), msg.len));
    }

    /// Deletes the trap
    pub fn delete(t: *Trap) void {
        c.wasm_trap_delete(@ptrCast(t));
    }

    /// Copies a trap to a new one.
    ///
    /// The caller is responsible for deleting the returned trap.
    pub fn copy(t: *const Trap) *Trap {
        return @ptrCast(c.wasm_trap_copy(@ptrCast(t)));
    }

    /// Attempts to extract the trap code from this trap.
    ///
    /// Returns a `Code` if the trap is an instruction trap triggered while
    /// executing Wasm. If `null` is returned then this is not
    /// an instruction trap -- traps can also be created using `Trap.new`,
    /// or occur with WASI modules exiting with a certain exit code.
    pub fn code(t: *const Trap) ?Code {
        var out: c.wasmtime_trap_code_t = undefined;
        if (c.wasmtime_trap_code(@ptrCast(t), &out)) {
            return @enumFromInt(out);
        }
        return null;
    }

    /// Retrieves the message associated with this trap.
    ///
    /// The caller takes ownership of the returned `Message` value and is responsible for
    /// calling `Message.delete` on it.
    pub fn message(t: *const Trap) lib.Message {
        var msg: lib.Message = undefined;
        c.wasm_trap_message(@ptrCast(t), @ptrCast(&msg));
        return msg;
    }

    /// Returns the top frame of the wasm stack responsible for this trap.
    ///
    /// The caller is responsible for deallocating the returned frame. This function
    /// may return `null`, for example, for traps created when there wasn't anything
    /// on the wasm stack.
    pub fn origin(t: *const Trap) ?*Frame {
        return @ptrCast(c.wasm_trap_origin(@ptrCast(t)));
    }

    /// Returns the trace of wasm frames for this trap.
    ///
    /// The caller is responsible for deallocating the returned list of frames.
    /// Frames are listed in order of increasing depth, with the most recently called
    /// function at the front of the list and the base function on the stack at the
    /// end.
    pub fn trace(t: *const Trap) lib.FrameVec {
        var fv: lib.FrameVec = undefined;
        c.wasm_trap_trace(@ptrCast(t), @ptrCast(&fv));
        return fv;
    }
};
