const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");
const ref = @import("ref.zig");
const vec = @import("vec.zig");

/// An opaque object representing the type of a function.
pub const FuncType = opaque {
    /// Creates a new function type with the provided parameter and result
    /// types.
    ///
    /// The caller is responsible for deleting the returned type.
    pub fn new(param: []const lib.ValKind, result: []const lib.ValKind) *FuncType {
        var params_vec = valTypeVecFromValKind(param);
        var results_vec = valTypeVecFromValKind(result);
        return @ptrCast(c.wasm_functype_new(@ptrCast(&params_vec), @ptrCast(&results_vec)));
    }

    fn valTypeVecFromValKind(kinds: []const lib.ValKind) lib.ValTypeVec {
        var t_vec = lib.ValTypeVec.newUninitialized(kinds.len);
        var elems = t_vec.elems();
        for (kinds, 0..) |k, i| {
            elems[i] = lib.ValType.new(k);
        }
        return t_vec;
    }

    /// Delete the `FuncType`.
    pub fn delete(t: *FuncType) void {
        c.wasm_functype_delete(@ptrCast(t));
    }

    /// Returns the list of parameters of this function type.
    ///
    /// The returned value is owned by the `FuncType` argument and should not
    /// be deleted.
    pub fn params(t: *const FuncType) *const lib.ValTypeVec {
        return @ptrCast(c.wasm_functype_params(@ptrCast(t)));
    }

    /// Returns the list of results of this function type.
    ///
    /// The returned value is owned by the `FuncType` argument and should not
    /// be deleted.
    pub fn results(t: *const FuncType) *const lib.ValTypeVec {
        return @ptrCast(c.wasm_functype_results(@ptrCast(t)));
    }

    /// Converts a `FuncType` to an `ExternType`.
    ///
    /// The returned value is owned by the `FuncType` argument and should not
    /// be deleted.
    pub fn asExternType(t: *FuncType) *lib.ExternType {
        return @ptrCast(c.wasm_functype_as_externtype(@ptrCast(t)));
    }

    /// Converts a `FuncType` to an `ExternType`.
    ///
    /// The returned value is owned by the `FuncType` argument and should not
    /// be deleted.
    pub fn asExternTypeConst(t: *const FuncType) *const lib.ExternType {
        return @ptrCast(c.wasm_functype_as_externtype_const(@ptrCast(t)));
    }
};

/// This structure is an argument to `Func.new` or `Func.newUnchecked` implementations.
///
/// The purpose of this structure is to acquire a `Context` pointer to interact with
/// objects, but it can also be used for inspect the state of the caller (such as
/// getting memories and functions) with `Caller.exportGet`.
///
/// This object is never owned and does not need to be deleted.
pub const Caller = opaque {
    /// Loads an `Extern` from the caller's context.
    ///
    /// This function will attempt to look up the export named `name` on the caller
    /// instance provided. If it is found then the `Extern` for that is
    /// returned, otherwise `null` is returned.
    ///
    /// Note that this only works for exported memories right now for WASI
    /// compatibility.
    ///
    /// Returns an `*Extern` value if the export was found, or `null` if the export wasn't
    /// found.
    pub fn exportGet(cal: *Caller, name: []const u8) ?*lib.Extern {
        var ret: c.wasmtime_extern_t = undefined;
        if (c.wasmtime_caller_export_get(@ptrCast(cal), @ptrCast(name.ptr), name.len, &ret)) {
            return @ptrCast(ret);
        }
        return null;
    }

    /// Returns the store context of the caller object.
    pub fn context(cal: *Caller) *lib.Context {
        return @ptrCast(c.wasmtime_caller_context(@ptrCast(cal)));
    }
};

/// Return type of `Func.new` implementations.
pub const FuncResult = union(enum) {
    /// Indicates that the function invocation was successful.
    ///
    /// Must contain the correct number and types of values that are expected of
    /// this `Func`s `FuncType`.
    values: []const lib.Val,
    /// Indicates that a trap should be raised. It's expected that in this case the
    /// implementation reqlinquishes ownership of the trap and it is passed back to the engine.
    trap: *lib.Trap,
};

/// Return type of `Func.newUnchecked` implementations.
pub const UncheckedFuncResult = union(enum) {
    /// Indicates that the function invocation was successful.
    ///
    /// Must contain the correct number and types of values that are expected of
    /// this `Func`s `FuncType`.
    values: []const lib.RawVal,
    /// Indicates that a trap should be raised. It's expected that in this case the
    /// implementation reqlinquishes ownership of the trap and it is passed back to the engine.
    trap: *lib.Trap,
};

/// The structure representing an asynchronously running function.
///
/// This structure is always owned by the caller and must be deleted using
/// `Future.delete`.
///
/// Functions that return this type require that the parameters to the function
/// are unmodified until this future is destroyed.
pub const Future = opaque {
    /// Frees the underlying memory for a future.
    ///
    /// All futures are owned by the caller and should be deleted
    /// using this function.
    pub fn delete(f: *Future) void {
        c.wasmtime_call_future_delete(@ptrCast(f));
    }

    /// Executes WebAssembly in the function.
    ///
    /// Returns `true` if the function call has completed. After this function returns
    /// `true`, it should *not* be called again for the given future.
    ///
    /// This function returns false if execution has yielded either due to being out
    /// of fuel (see `Context.setFuelAsyncYieldInterval`), or the epoch has been
    /// incremented enough (see `Context.setEpochDeadlineAsyncYieldAndUpdate`).
    /// The function may also return false if asynchronous host functions have been called,
    /// which then calling this function will call the continuation from the async host
    /// function.
    ///
    /// For more see the information at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#asynchronous-wasm
    pub fn poll(f: *Future) bool {
        c.wasmtime_call_future_poll(@ptrCast(f));
    }
};

/// Container for the potential trap or error that is generated by `Func.callAsync`
/// function call.
pub const AsyncErrorTrapReturn = struct {
    /// The trap return value.
    ///
    /// If not `null` then `err` must be `null`.
    trap: ?*lib.Trap = null,
    /// The error return value.
    ///
    /// If not `null` then `trap` must be `null`.
    err: ?*lib.Error = null,
};

/// Representation of a function in Wasmtime.
///
/// Functions are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Functions cannot
/// interoperate between `Store` instances and if the wrong function is passed
/// to the wrong store then it may trigger an assertion to abort the process.
pub const Func = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,
    /// Internal index within the store.
    index: usize,

    /// Creates a new host-defined function.
    ///
    /// Inserts a host-defined function into the `ctx` provided which can be used
    /// to then instantiate a module with or define within a `Linker`.
    ///
    /// The returned `Func` can only be used with the specified `ctx`.
    ///
    /// `impl` must be a pointer to a type that implements the following:
    /// ```zig
    /// const FuncImpl = struct {
    ///     // Required
    ///     //
    ///     // This is the function signature for host functions that can be made accessible
    ///     // to WebAssembly. The arguments to this function are:
    ///     //
    ///     // `impl`: pointer to user-defined implementation.
    ///     // `caller`: a temporary object that can only be used during this function
    ///     //           call. Used to acquire `Context` or caller's state.
    ///     // `args`: the arguments provided to this function invocation.
    ///     //
    ///     // This function is guaranteed to get called with the correct number and types of arguments,
    ///     // but it must produce the correct number and types of results. Failure to do so will cause
    ///     // traps to get raised on the wasm side.
    ///     //
    ///     // See `FuncResult` for more info on what this function should return.
    ///     pub fn call(impl: *FuncImpl, caller: *Caller, args: []const Val) FuncResult {
    ///     }
    ///
    ///     // Optional
    ///     //
    ///     // Destructor for `FuncImpl`.
    ///     pub fn finalize(impl: *FuncImpl) void {
    ///     }
    /// };
    /// ```
    pub fn new(ctx: *lib.Context, ty: *const FuncType, impl: anytype) Func {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Pointer.child;
        const ImplExtern = FuncExtern(Impl);

        var ret: Func = undefined;
        c.wasmtime_func_new(
            @ptrCast(ctx),
            @ptrCast(ty),
            ImplExtern.call,
            @ptrCast(impl),
            if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
            @ptrCast(&ret),
        );
        return ret;
    }

    /// Creates a new host function in the same manner of `Func.new`, but the
    /// function-to-call has no type information available at runtime.
    ///
    /// This function is very similar to `Func.new`. The difference is that
    /// this version is "more unsafe" in that when the host callback is invoked there
    /// is no type information and no checks that the right types of values are
    /// produced. The onus is on the consumer of this API to ensure that all
    /// invariants are upheld such as:
    ///
    /// * The host callback reads parameters correctly and interprets their types
    ///   correctly.
    /// * If a trap doesn't happen then all results must be returned.
    /// * All results must have the correct type.
    /// * Types such as `funcref` cannot cross stores.
    /// * Types such as `externref` have valid reference counts.
    ///
    /// It's generally only recommended to use this if your application can wrap
    /// this in a safe embedding. This should not be frequently used due to the
    /// number of invariants that must be upheld on the wasm<->host boundary. On the
    /// upside, though, this flavor of host function will be faster to call than
    /// those created by `Func.new` (hence the reason for this function's existence).
    ///
    /// `impl` must be a pointer to a type that implements the following:
    /// ```zig
    /// const UncheckedFuncImpl = struct {
    ///     // Required
    ///     //
    ///     // This is the function signature for host functions that can be made accessible
    ///     // to WebAssembly. The arguments to this function are:
    ///     //
    ///     // `impl`: pointer to user-defined implementation.
    ///     // `caller`: a temporary object that can only be used during this function
    ///     //           call. Used to acquire `Context` or caller's state.
    ///     // `args`: the arguments provided to this function invocation.
    ///     //
    ///     // This function is guaranteed to get called with the correct number and types of arguments,
    ///     // but it must produce the correct number and types of results. Failure to do so will cause
    ///     // traps to get raised on the wasm side.
    ///     //
    ///     // See `UncheckedFuncResult` for more info on what this function should return.
    ///     pub fn call(impl: *UncheckedFuncImpl, caller: *Caller, args: []const RawVal) UncheckedFuncResult {
    ///     }
    ///
    ///     // Optional
    ///     //
    ///     // Destructor for `UncheckedFuncImpl`.
    ///     pub fn finalize(impl: *UncheckedFuncImpl) void {
    ///     }
    /// };
    /// ```
    pub fn newUnchecked(ctx: *lib.Context, ty: *const FuncType, impl: anytype) Func {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Pointer.child;
        const ImplExtern = FuncUncheckedExtern(Impl);

        var ret: Func = undefined;
        c.wasmtime_func_new_unchecked(
            @ptrCast(ctx),
            @ptrCast(ty),
            ImplExtern.call,
            @ptrCast(impl),
            if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
            @ptrCast(&ret),
        );
        return ret;
    }

    /// Call a WebAssembly function.
    ///
    /// This function is used to invoke a function defined within a store. For
    /// example this might be used after extracting a function from a
    /// `Instance`.
    ///
    /// There are three possible return states from this function:
    ///
    /// 1. An error is returned. This means `ret_vals` wasn't written to, and that programmer error
    ///    happened when calling the function. For example, when the size of the `args` or
    ///    `ret_vals` is wrong, the types of `args` are wrong, or `args` come from the wrong store.
    /// 2. A `Trap` is returned. This means `ret_vals` wasn't written to, and that the function was
    ///    executing but hit a wasm trap while executing.
    /// 3. No `Trap` or error is returned. This means `ret_vals` was written to, and that the
    ///    function call succeeded.
    ///
    /// Does not take ownership of the vals in `args`.
    /// Gives ownership of the vals in `ret_vals`.
    pub fn call(f: *const Func, ctx: *lib.Context, args: ?[]const lib.Val, ret_vals: ?[]lib.Val) !?*lib.Trap {
        var t: ?*lib.Trap = null;
        try err.result(c.wasmtime_func_call(
            @ptrCast(ctx),
            @ptrCast(f),
            if (args) |a| @ptrCast(a.ptr) else null,
            if (args) |a| a.len else 0,
            if (ret_vals) |rv| @ptrCast(rv.ptr) else null,
            if (ret_vals) |rv| rv.len else 0,
            @ptrCast(&t),
        ));
        return t;
    }

    /// Call a WebAssembly function in an "unchecked" fashion.
    ///
    /// This function is similar to `Func.call` except that there is no type
    /// information provided with the arguments (or sizing information). Consequently
    /// this is less safe to call since it's up to the caller to ensure that `args_and_ret_vals`
    /// has an appropriate size and all the parameters are configured with their
    /// appropriate values/types. Additionally all the return values must be interpreted
    /// correctly if this function returns successfully.
    ///
    /// Parameters must be specified starting at index 0 in the `args_and_ret_vals`
    /// array. Return values are written starting at index 0, which will overwrite
    /// the arguments.
    ///
    /// Callers must ensure that various correctness variants are upheld when this
    /// API is called such as:
    ///
    /// * The `args_and_ret_vals` slice has enough space to hold all the parameters
    ///   and all the return values (but not at the same time).
    /// * Parameters must all be configured as if they were the correct type.
    /// * Values such as `RawVal.extern_ref` and `RawVal.func_ref` are valid within the store being
    ///   called.
    ///
    /// When in doubt it's much safer to call `Func.call`. This function is
    /// faster than that function, but the tradeoff is that embeddings must uphold
    /// more invariants rather than relying on Wasmtime to check them for you.
    ///
    /// There are three possible return states from this function (`args` and `ret_vals` refer to `args_and_ret_vals`):
    ///
    /// 1. An error is returned. This means `ret_vals` wasn't written to, and that programmer error
    ///    happened when calling the function. For example, when the size of the `args` or
    ///    `ret_vals` is wrong, the types of `args` are wrong, or `args` come from the wrong store.
    /// 2. A `Trap` is returned. This means `ret_vals` wasn't written to, and that the function was
    ///    executing but hit a wasm trap while executing.
    /// 3. No `Trap` or error is returned. This means `ret_vals` was written to, and that the
    ///    function call succeeded.
    ///
    /// Does not take ownership of the vals in `args`.
    /// Gives ownership of the vals in `ret_vals`.
    pub fn callUnchecked(f: *const Func, ctx: *lib.Context, args_and_ret_vals: []lib.RawVal) !?*lib.Trap {
        var t: ?*lib.Trap = null;
        try err.result(c.wasmtime_func_call_unchecked(
            @ptrCast(ctx),
            @ptrCast(f),
            @ptrCast(args_and_ret_vals.ptr),
            args_and_ret_vals.len,
            @ptrCast(&t),
        ));
        return t;
    }

    /// Invokes this function with the params given, returning the results
    /// asynchronously.
    ///
    /// This function is the same as `Func.call` except that it is
    /// asynchronous. This is only compatible with stores associated with an
    /// asynchronous config.
    ///
    /// The result is a future that is owned by the caller and must be deleted via
    /// `Future.delete`.
    ///
    /// All parameters to this function must be kept alive and not modified until the
    /// returned `Future` is deleted.
    ///
    /// Only a single future can be alive for a given store at a single time
    /// (meaning only call this function after the previous call's future was deleted).
    ///
    /// Does not take ownership of the vals in `args`.
    /// Gives ownership of the vals in `ret_vals`.
    ///
    /// `err_trap_ret` must be checked by the caller after running the async function
    /// to see if Wasmtime generated a trap or error. If a trap or error is present,
    /// then `ret_vals` will not contain the return values.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Func.html#method.call_async
    pub fn callAsync(
        f: *const Func,
        ctx: *lib.Context,
        args: ?[]const lib.Val,
        ret_vals: ?[]lib.Val,
        err_trap_ret: *AsyncErrorTrapReturn,
    ) *Future {
        return @ptrCast(c.wasmtime_func_call_async(
            @ptrCast(ctx),
            @ptrCast(f),
            if (args) |a| @ptrCast(a.ptr) else null,
            if (args) |a| a.len else 0,
            if (ret_vals) |rv| @ptrCast(rv.ptr) else null,
            if (ret_vals) |rv| rv.len else 0,
            @ptrCast(&err_trap_ret.trap),
            @ptrCast(&err_trap_ret.err),
        ));
    }

    /// Returns the type of the function specified.
    ///
    /// The returned `FuncType` is owned by the caller.
    pub fn typ(f: *Func, ctx: *lib.Context) *FuncType {
        return @ptrCast(c.wasmtime_func_type(@ptrCast(ctx), @ptrCast(f)));
    }

    /// Converts a non-null `RawVal.func_ref` into a `Func`.
    ///
    /// It is assumed that `raw.func_ref` is not `null`, otherwise the program
    /// will abort.
    ///
    /// Note that this function is unchecked and unsafe. It's only safe to pass
    /// values learned from `RawVal` with the same corresponding `Context` that
    /// they were produced from. Providing arbitrary values to `raw` here or
    /// cross-context values with `ctx` is UB.
    pub fn fromRaw(ctx: *lib.Context, raw: lib.RawVal) Func {
        var ret: Func = undefined;
        c.wasmtime_func_from_raw(@ptrCast(ctx), raw.func_ref, @ptrCast(&ret));
        return ret;
    }

    /// Converts a `Func`  which belongs to `ctx` into a `RawVal.func_ref`.
    pub fn toRaw(f: *const Func, ctx: *lib.Context) lib.RawVal {
        const func_ref = c.wasmtime_func_to_raw(@ptrCast(ctx), @ptrCast(f));
        return lib.RawVal{ .func_ref = func_ref };
    }
};

pub fn FuncExtern(comptime Impl: type) type {
    return struct {
        fn call(
            ptr: ?*anyopaque,
            c_caller: *c.wasmtime_caller_t,
            c_args: [*]const c.wasmtime_val_t,
            args_len: usize,
            c_ret: [*]c.wasmtime_val_t,
            ret_len: usize,
        ) callconv(.C) ?*c.wasm_trap_t {
            const impl: *Impl = @ptrCast(ptr.?);
            const caller: *Caller = @ptrCast(c_caller);
            const args: []const lib.Val = @ptrCast(c_args[0..args_len]);
            const result: FuncResult = Impl.call(impl, caller, args);
            switch (result) {
                .values => |vals| {
                    const ret: []lib.Val = @ptrCast(c_ret[0..ret_len]);
                    @memcpy(ret, vals);
                    return null;
                },
                .trap => |t| {
                    return @ptrCast(t);
                },
            }
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}

pub fn FuncUncheckedExtern(comptime Impl: type) type {
    return struct {
        fn call(
            ptr: ?*anyopaque,
            c_caller: *c.wasmtime_caller_t,
            aar: [*]c.wasmtime_val_raw_t,
            aar_len: usize,
        ) callconv(.C) ?*c.wasm_trap_t {
            const impl: *Impl = @ptrCast(ptr.?);
            const caller: *Caller = @ptrCast(c_caller);
            const args: []const lib.RawVal = @ptrCast(aar[0..aar_len]);
            const result: UncheckedFuncResult = Impl.call(impl, caller, args);
            switch (result) {
                .values => |vals| {
                    const ret: []lib.RawVal = @ptrCast(aar[0..aar_len]);
                    @memcpy(ret, vals);
                    return null;
                },
                .trap => |t| {
                    return @ptrCast(t);
                },
            }
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}
