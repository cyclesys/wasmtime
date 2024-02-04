const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");

/// Compilation environment and configuration.
///
/// An engine is typically global in a program and contains all the configuration
/// necessary for compiling wasm code. From an engine you'll typically create a
/// `Store`. Engines are created with `Engine.new` or `Engine.newWithConfig`.
///
/// An engine is safe to share between threads. Multiple stores can be created
/// within the same engine with each store living on a separate thread. Typically
/// you'll create one `Engine` for the lifetime of your program.
///
/// Engines are reference counted internally so `Engine.delete` can be called
/// at any time after a `Store` has been created from one.
pub const Engine = opaque {
    /// Creates a new engine with the default configuration.
    ///
    /// The object returned is owned by the caller and will need to be deleted with
    /// `Engine.delete`. This may return `null` if the engine could not be
    /// allocated.
    pub fn new() ?*Engine {
        return @ptrCast(c.wasm_engine_new());
    }

    /// Creates a new engine with the specified configuration.
    ///
    /// This function will take ownership of the configuration specified regardless
    /// of the outcome of this function. You do not need to call `Config.delete`
    /// on the argument. The object returned is owned by the caller and will need to
    /// be deleted with `Engine.delete`. This may return `null` if the engine
    /// could not be allocated.
    pub fn newWithConfig(config: *lib.Config) ?*Engine {
        return @ptrCast(c.wasm_engine_new_with_config(@ptrCast(config)));
    }

    /// Deletes the `Engine` object
    pub fn delete(e: *Engine) void {
        c.wasm_engine_delete(@ptrCast(e));
    }

    /// Increments the engine-local epoch variable.
    ///
    /// This function will increment the engine's current epoch which can be used to
    /// force WebAssembly code to trap if the current epoch goes beyond the
    /// `Store` configured epoch deadline.
    ///
    /// This function is safe to call from any thread, and it is also
    /// async-signal-safe.
    ///
    /// See also `Config.epochInterruption`.
    pub fn incrementEpoch(e: *Engine) void {
        c.wasmtime_engine_increment_epoch(@ptrCast(e));
    }

    /// Validate a WebAssembly binary.
    ///
    /// This function will validate the provided byte sequence to determine if it is
    /// a valid WebAssembly binary within the context of the engine provided.
    ///
    /// If the binary is not valid, an error is returned.
    pub fn validate(e: *Engine, wasm: []const u8) !void {
        try err.result(c.wasmtime_module_validate(
            @ptrCast(e),
            @ptrCast(wasm.ptr),
            wasm.len,
        ));
    }

    /// Build a module from serialized data.
    ///
    /// This function does not take ownership of any of its arguments, but the
    /// returned error and module are owned by the caller.
    ///
    /// This function is not safe to receive arbitrary user input. See the Rust
    /// documentation for more information on what inputs are safe to pass in here
    /// (e.g. only that of `Module.serialize`)
    pub fn deserialize(e: *Engine, bytes: []const u8) !*lib.Module {
        var mod: *lib.Module = undefined;
        try err.result(c.wasmtime_module_deserialize(
            @ptrCast(e),
            @ptrCast(bytes.ptr),
            bytes.len,
            @ptrCast(&mod),
        ));
        return mod;
    }

    /// Deserialize a module from an on-disk file.
    ///
    /// This function is the same as `Engine.deserialize` except that it
    /// reads the data for the serialized module from the path on disk. This can be
    /// faster than the alternative which may require copying the data around.
    ///
    /// This function does not take ownership of any of its arguments, but the
    /// returned error and module are owned by the caller.
    ///
    /// This function is not safe to receive arbitrary user input. See the Rust
    /// documentation for more information on what inputs are safe to pass in here
    /// (e.g. only that of `Module.serialize`)
    pub fn deserializeFile(e: *Engine, path: [:0]const u8) !*lib.Module {
        var mod: *lib.Module = undefined;
        try err.result(c.wasmtime_module_deserialize_file(
            @ptrCast(e),
            @ptrCast(path.ptr),
            @ptrCast(&mod),
        ));
        return mod;
    }
};
