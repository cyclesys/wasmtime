const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");

/// An interior pointer into a `Store` which is used as
/// "context" for many functions.
///
/// This context pointer is used pervasively throught Wasmtime's API. This can be
/// acquired from `Store.context` or `Caller.context`. The
/// context pointer for a store is the same for the entire lifetime of a store,
/// so it can safely be stored adjacent to a `Store` itself.
///
/// Usage of a `Context` must not outlive the original
/// `Store`. Additionally `Context` can only be used in
/// situations where it has explicitly been granted access to doing so. For
/// example finalizers cannot use `Context` because they are not given
/// access to it.
pub const Context = opaque {
    /// Returns the user-specified data associated with the specified store
    pub fn getData(ctx: *Context) *anyopaque {
        return c.wasmtime_context_get_data(@ptrCast(ctx));
    }

    /// Overwrites the user-specified data associated with this store.
    ///
    /// Note that this does not execute the original finalizer for the provided data,
    /// and the original finalizer will be executed for the provided data when the
    /// store is deleted.
    pub fn setData(ctx: *Context, data: *anyopaque) void {
        c.wasmtime_context_set_data(@ptrCast(ctx), data);
    }

    /// Perform garbage collection within the given context.
    ///
    /// Garbage collects `externref`s that are used within this store. Any
    /// `externref`s that are discovered to be unreachable by other code or objects
    /// will have their finalizers run.
    pub fn gc(ctx: *Context) void {
        c.wasmtime_context_gc(@ptrCast(ctx));
    }
    /// Set fuel to this context's store for wasm to consume while executing.
    ///
    /// For this method to work fuel consumption must be enabled via
    /// `Config.consumeFuel`. By default a store starts with 0 fuel
    /// for wasm to execute with (meaning it will immediately trap).
    /// This function must be called for the store to have
    /// some fuel to allow WebAssembly to execute.
    ///
    /// Note that when fuel is entirely consumed it will cause wasm to trap.
    ///
    /// If fuel is not enabled within this store then an error is returned.
    pub fn setFuel(ctx: *Context, fuel: u64) !void {
        try err.result(c.wasmtime_context_set_fuel(@ptrCast(ctx), fuel));
    }

    /// Returns the amount of fuel remaining in this context's store.
    ///
    /// If fuel consumption is not enabled via `Config.consumeFuel`
    /// then this function will return an error.
    ///
    /// Also note that fuel, if enabled, must be originally configured via
    /// `Context.setFuel`.
    pub fn getFuel(ctx: *Context) !u64 {
        var fuel: u64 = undefined;
        try err.result(c.wasmtime_context_get_fuel(@ptrCast(ctx), &fuel));
        return fuel;
    }

    /// Configures WASI state within the specified store.
    ///
    /// This function is required if `Linker.defineWasi` is called. This
    /// will configure the WASI state for instances defined within this store to the
    /// configuration specified.
    ///
    /// This function does not take ownership of `ctx` but it does take ownership
    /// of `wasi_cfg`. The caller should no longer use `wasi_cfg` after calling this function
    /// (even if an error is returned).
    pub fn setWasi(ctx: *Context, wasi_cfg: *lib.WasiConfig) !void {
        try err.result(c.wasmtime_context_set_wasi(@ptrCast(ctx), @ptrCast(wasi_cfg)));
    }

    pub fn setEpochDeadline(ctx: *Context, ticks_beyond_current: u64) void {
        c.wasmtime_context_set_epoch_deadline(@ptrCast(ctx), ticks_beyond_current);
    }
};

/// An enum for the behavior before extending the epoch deadline.
pub const EpochDeadlineUpdateBehavior = enum {
    /// Directly continue to updating the deadline and executing WebAssembly.
    continues,

    /// Yield control (via async support) then update the deadline.
    yields,
};

/// Describes how to update the deadline
pub const EpochDeadlineUpdate = struct {
    /// The delta to update the deadline by.
    delta: u64,

    /// The behavior of the udpate.
    behavior: EpochDeadlineUpdateBehavior,
};

/// This function will be called when the running WebAssembly function has exceeded its epoch deadline. This
/// function can return an error to terminate the function.
pub const EpochDeadlineCallback = fn (ctx: *Context, data: *anyopaque) anyerror!EpochDeadlineUpdate;

/// Storage of WebAssembly objects
///
/// A store is the unit of isolation between WebAssembly instances in an
/// embedding of Wasmtime. Values in one `Store` cannot flow into
/// another `Store`. Stores are cheap to create and cheap to dispose.
/// It's expected that one-off stores are common in embeddings.
///
/// Objects stored within a `Store` are referenced with integer handles
/// rather than interior pointers. This means that most APIs require that the
/// store be explicitly passed in, which is done via `Context`. It is
/// safe to move a `Store` to any thread at any time. A store generally
/// cannot be concurrently used, however.
pub const Store = opaque {
    /// Creates a new store within the specified engine, and additional user-provided data attached to the
    /// `Context`, which can later be acquired with `Context.getData`.
    ///
    /// `finalizer`: an optional finalizer for `data`.
    ///
    /// The returned store must be deleted with `Store.delete`.
    pub fn new(engine: *lib.Engine, data: *anyopaque, finalizer: ?*const fn (*anyopaque) void) *Store {
        return @ptrCast(c.wasmtime_store_new(@ptrCast(engine), data, finalizer));
    }

    /// Deletes the store.
    pub fn delete(s: *Store) void {
        c.wasmtime_store_delete(@ptrCast(s));
    }

    /// Returns the interior `Context` pointer to this store
    pub fn context(s: *Store) *Context {
        return @ptrCast(c.wasmtime_store_context(@ptrCast(s)));
    }

    /// Provides limits for a store. Used by hosts to limit resource
    /// consumption of instances. Use negative value to keep the default value
    /// for the limit.
    ///
    /// `memory_size`: the maximum number of bytes a linear memory can grow to.
    /// Growing a linear memory beyond this limit will fail. By default,
    /// linear memory will not be limited.
    ///
    /// `table_elements`: the maximum number of elements in a table.
    /// Growing a table beyond this limit will fail. By default, table elements
    /// will not be limited.
    ///
    /// `instances`: the maximum number of instances that can be created
    /// for a Store. Module instantiation will fail if this limit is exceeded.
    /// This value defaults to 10,000.
    ///
    /// `tables`: the maximum number of tables that can be created for a Store.
    /// Module instantiation will fail if this limit is exceeded. This value
    /// defaults to 10,000.
    ///
    /// `memories`: the maximum number of linear memories that can be created
    /// for a Store. Instantiation will fail with an error if this limit is exceeded.
    /// This value defaults to 10,000.
    ///
    /// Use any negative value for the parameters that should be kept on
    /// the default values.
    ///
    /// Note that the limits are only used to limit the creation/growth of
    /// resources in the future, this does not retroactively attempt to apply
    /// limits to the store.
    pub fn limiter(s: *Store, memory_size: i64, table_elements: i64, instances: i64, tables: i64, memories: i64) void {
        c.wasmtime_store_limiter(@ptrCast(s), memory_size, table_elements, instances, tables, memories);
    }

    /// This function configures a store-local callback interface that will be
    /// called when the running WebAssembly function has exceeded its epoch
    /// deadline.
    /// ```zig
    /// const EpochDeadlingInterface = struct {
    ///
    ///     /// See `EpochDeadlineUpdate` for more info.
    ///     ///
    ///     /// Returning an error will result in the WebAssembly function terminating.
    ///     pub fn update(self: *EpochDeadlineInterface, ctx: *Context) !EpochDeadlineUpdate {
    ///     }
    ///
    ///     /// Finalizer function to clean up any resources
    ///     pub fn finalize(self: *EpochDeadlineInterface) void {
    ///     }
    /// };
    /// ```
    /// To return `EpochDeadlingUpdateBehavior.yeilds` from the `update` function, async support must be enabled
    /// for this store.
    ///
    /// See also `Config.epochInterruption` and `Context.setEpochDeadline`.
    pub fn epochDeadlineCallback(s: *Store, impl: anytype) void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Ptr.child;

        const ImplExtern = EpochDeadlineExtern(Impl);
        c.wasmtime_store_epoch_deadline_callback(@ptrCast(s), ImplExtern.update, impl, ImplExtern.finalize);
    }
};

fn EpochDeadlineExtern(comptime Impl: type) type {
    return struct {
        fn update(
            ctx: *c.wasmtime_context_t,
            data: *anyopaque,
            out_delta: *u64,
            out_kind: *c.wasmtime_update_deadline_kind_t,
        ) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(data);
            const context: *Context = @ptrCast(ctx);
            const result = Impl.update(impl, context) catch |e| {
                return err.new(@tagName(e));
            };

            switch (result) {
                .continues => |delta| {
                    out_delta.* = delta;
                    out_kind.* = c.WASMTIME_UPDATE_DEADLINE_CONTINUE;
                },
                .yields => |delta| {
                    out_delta.* = delta;
                    out_kind.* = c.WASMTIME_UPDATE_DEADLINE_YIELD;
                },
            }
            return null;
        }

        fn finalize(data: *anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(data);
            Impl.finalize(impl);
        }
    };
}
