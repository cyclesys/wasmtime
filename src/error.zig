const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");

// NOTE: Is TLS the best solution here? If https://github.com/ziglang/zig/issues/2647 is
// implemented this 'global' API becomes unnecessary.
threadlocal var err: ?*c.wasmtime_error_t = null;

// internal api
pub fn result(opt_err: ?*c.wasmtime_error_t) !void {
    if (opt_err) |new_err| {
        if (err) |e| {
            c.wasmtime_error_delete(e);
        }
        err = new_err;
        return error.WasmtimeError;
    }
}

// internal api
pub fn new(msg: [:0]const u8) *c.wasmtime_error_t {
    return c.wasmtime_error_new(msg);
}

/// Returns the string description of this error.
///
/// This will "render" the error to a string and then return the string
/// representation of the error to the caller.
///
/// Caller must call `delete` to free the message.
///
/// Safety: This assumes an error has occurred. No error will result in a panic.
pub fn message() lib.Name {
    var m = lib.Name.newEmpty();
    c.wasmtime_error_message(err.?, &m.inner);
    return m;
}

/// Attempts to extract a WASI-specific exit status from the latest error.
///
/// If the error is a WASI "exit" trap and has a return status, then it is returned.
/// Otherwise returns `null` to indicate that this is not a wasi exit trap.
///
/// Safety: This assumes an error has occurred. No error will result in a panic.
pub fn status() ?u32 {
    var code: c_int = undefined;
    c.wasmtime_error_exit_status(err.?, &code);
}

/// Attempts to extract a WebAssembly trace from the latest error.
///
/// If no trace is available it will return `null`.
///
/// If not null, the caller must call `delete` to free the trace.
///
/// Safety: This assumes an error has occurred. No error will result in a panic.
pub fn trace() ?lib.FrameVec {
    var t = lib.FrameVec.newEmpty();
    c.wasmtime_error_wasm_trace(err.?, &t.inner);

    if (t.inner.size > 0) {
        return t;
    }

    t.delete();
    return null;
}
