const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");
const func = @import("func.zig");

/// Object used to conveniently link together and instantiate wasm
/// modules.
///
/// This type corresponds to the `wasmtime::Linker` type in Rust. This
/// type is intended to make it easier to manage a set of modules that link
/// together, or to make it easier to link WebAssembly modules to WASI.
///
/// A `Linker` is a higher level way to instantiate a module than
/// `Instance` since it works at the "string" level of imports rather
/// than requiring 1:1 mappings.
pub const Linker = opaque {
    /// Creates a new linker for the specified engine.
    ///
    /// This function does not take ownership of the engine argument, and the caller
    /// is expected to delete the returned linker.
    pub fn new(eng: *lib.Engine) *Linker {
        return @ptrCast(c.wasmtime_linker_new(@ptrCast(eng)));
    }

    /// Deletes the linker
    pub fn delete(l: *Linker) void {
        c.wasmtime_linker_delete(@ptrCast(l));
    }

    /// Configures whether this linker allows later definitions to shadow
    /// previous definitions.
    ///
    /// By default this setting is `false`.
    pub fn allowShadowing(l: *Linker, allow: bool) void {
        c.wasmtime_linker_allow_shadowing(@ptrCast(l), allow);
    }

    /// Defines a new item in this linker.
    ///
    /// This function defines a new item `ext`, owned by store `ctx`,
    /// under module name `mod` and item name `name`.
    ///
    /// For more information about name resolution consult the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#name-resolution).
    pub fn define(l: *Linker, ctx: *lib.Context, mod: []const u8, name: []const u8, ext: *const lib.Extern) !void {
        try err.result(c.wasmtime_linker_define(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(mod.ptr),
            mod.len,
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(ext),
        ));
    }

    /// Defines a new function in this linker.
    ///
    /// This function defines a function `impl` under module name `mod`, and item name `name`
    /// with type `ty`.
    ///
    /// For more information about name resolution consult the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#name-resolution).
    ///
    /// This function is the analog of `Func.new`.
    ///
    /// Note that this function does not create a `Func`. This creates a
    /// store-independent function within the linker, allowing this function
    /// definition to be used with multiple stores.
    ///
    /// See `Func.new` for more details.
    pub fn defineFunc(l: *Linker, mod: []const u8, name: []const u8, ty: *lib.FuncType, impl: anytype) !void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Ptr.child;
        const ImplExtern = func.FuncExtern(Impl);
        try err.result(c.wasmtime_linker_define_func(
            @ptrCast(l),
            @ptrCast(mod.ptr),
            mod.len,
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(ty),
            ImplExtern.call,
            @ptrCast(impl),
            if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
        ));
    }

    /// Defines a new function in this linker.
    ///
    /// This is the same as `Linker.defineFunc` except that it's the analog
    /// of `Func.newUnchecked` instead of `Func.new`.
    ///
    /// See `Func.newUnchecked` for more details.
    pub fn defineFuncUnchecked(l: *Linker, mod: []const u8, name: []const u8, ty: *lib.FuncType, impl: anytype) !void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Ptr.child;
        const ImplExtern = func.FuncUncheckedExtern(Impl);
        try err.result(c.wasmtime_linker_define_func_unchecked(
            @ptrCast(l),
            @ptrCast(mod.ptr),
            mod.len,
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(ty),
            ImplExtern.call,
            @ptrCast(impl),
            if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
        ));
    }

    /// Defines a new async function in this linker.
    ///
    /// This function behaves similar `Linker.defineFunc`, except it
    /// supports async callbacks.
    ///
    /// The `impl` callback will be invoked on another stack (fiber for Windows).
    ///
    /// `impl` must be a pointer to a type that implements the following:
    /// ```
    /// const AsyncFuncImpl = struct {
    ///     /// Required
    ///     ///
    ///     /// This function should imlement the async function.
    ///     ///
    ///     /// The arguments to this function will be kept alive until the `state` function returns true.
    ///     ///
    ///     /// This function should either:
    ///     /// - Initialize `ret_trap`, indicating that a trap occurred, in which case `ret_vals` will be ignored.
    ///     /// - Initialize `ret_vals` and leave `ret_trap` as `null`, indicating that the funcction was successful.
    ///     ///
    ///     /// Then when `state` is called, return `true` to indicate that the functio has finished executing.
    ///     pub fn call(impl: *AsyncFuncImpl, caller: *Caller, args: []const Val, ret_vals: []Val, ret_trap: *?*Trap) void {
    ///     }
    ///
    ///     /// Required
    ///     ///
    ///     /// This function is called by Wasmtime to check the async state of the host call.
    ///     ///
    ///     /// Return `true` if the host call has completed, otherwise `false` will continue to yield
    ///     /// WebAssembly execution.
    ///     pub fn state(impl: *AsyncFuncImpl) bool {
    ///     }
    ///
    ///     /// Optional
    ///     ///
    ///     /// Destructor for `AsyncFuncImpl`.
    ///     pub fn finalize(impl: *AsyncFuncImpl) void {
    ///     }
    /// };
    ///
    /// See also `Func.new` for more info on the `call` arguments.
    pub fn defineAsyncFunc(l: *Linker, mod: []const u8, name: []const u8, ty: *const lib.FuncType, impl: anytype) !void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Ptr.child;
        const ImplExtern = FuncAsyncExtern(Impl);
        try err.result(c.wasmtime_linker_define_async_func(
            @ptrCast(l),
            @ptrCast(mod.ptr),
            mod.len,
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(ty),
            ImplExtern.call,
            @ptrCast(impl),
            if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
        ));
    }

    /// Defines WASI functions in this linker.
    ///
    /// This function will provide WASI function names in the specified linker. Note
    /// that when an instance is created within a store then the store also needs to
    /// have its WASI settings configured with `Context.setWasi` for WASI functions to
    /// work, otherwise an assert will be tripped that will abort the process.
    ///
    /// For more information about name resolution consult the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#name-resolution).
    pub fn defineWasi(l: *Linker) !void {
        try err.result(c.wasmtime_linker_define_wasi(@ptrCast(l)));
    }

    /// Defines an instance owned by store `ctx` under the specified name in this linker.
    ///
    /// This function will take all of the exports of the `instance` provided and
    /// defined them under a module called `name` with a field name as the export's
    /// own name.
    ///
    /// For more information about name resolution consult the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#name-resolution).
    pub fn defineInstance(l: *Linker, ctx: *lib.Context, name: []const u8, ins: *const lib.Instance) !void {
        try err.result(c.wasmtime_linker_define_instance(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(ins),
        ));
    }

    /// Instantiates a `Module` with the items defined in this linker.
    ///
    /// Instantiates `mod` within the store `ctx` and the linker.
    ///
    /// One of three things will result from this function:
    /// 1. The module is successfully instantiated and returned through `InstanceResult.instance`.
    /// 2. The start function of the module results in a trap and is returned through
    ///    `InstanceResult.trap`.
    /// 3. Instantiation fails and an error is returned.
    ///
    /// This function will attempt to satisfy all of the imports of the `module`
    /// provided with items previously defined in this linker. If any name isn't
    /// defined in the linker than an error is returned. (or if the previously
    /// defined item is of the wrong type).
    pub fn instantiate(l: *const Linker, ctx: *lib.Context, mod: *const lib.Module) !lib.InstanceResult {
        var ins: lib.Instance = undefined;
        var trap: ?*lib.Trap = null;
        try err.result(c.wasmtime_linker_instantiate(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(mod),
            @ptrCast(&ins),
            @ptrCast(&trap),
        ));
        if (trap) |t| {
            return lib.InstanceResult{ .trap = t };
        }
        return lib.InstanceResult{ .instance = ins };
    }

    /// Defines automatic instantiations of a `Module` in this linker.
    ///
    /// Instantiates `mod` within the store `ctx` and the linker using
    /// the `name` as the module name.
    ///
    /// Returns an error if the module could not be instantiated or added.
    ///
    /// This function automatically handles [Commands and
    /// Reactors](https://github.com/WebAssembly/WASI/blob/master/design/application-abi.md#current-unstable-abi)
    /// instantiation and initialization.
    ///
    /// For more information see the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#method.module).
    pub fn module(l: *Linker, ctx: *lib.Context, name: []const u8, mod: *const lib.Module) !void {
        try err.result(c.wasmtime_linker_module(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(mod),
        ));
    }

    /// Acquires the "default export" of the named module in this linker.
    ///
    /// `ctx`: the store to load a function into.
    /// `name`: the name of the module to get the default export for.
    ///
    /// Returns an error if the default export could not be found
    ///
    /// For more information see the [Rust
    /// documentation](https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Linker.html#method.get_default).
    pub fn getDefault(l: *const Linker, ctx: *lib.Context, name: []const u8) !lib.Func {
        var f: lib.Func = undefined;
        try err.result(c.wasmtime_linker_get_default(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(&f),
        ));
    }

    /// Loads an item by name from this linker.
    ///
    /// `ctx`: the store to load the item into.
    /// `mod`: the name of the module to get.
    /// `name`: the name of the field to get.
    ///
    /// Returns an `Extern` if the item is defined, otherwise `null`.
    pub fn get(l: *const Linker, ctx: *lib.Context, mod: []const u8, name: []const u8) ?lib.Extern {
        var ext: lib.Extern = undefined;
        if (c.wasmtime_linker_get(
            @ptrCast(l),
            @ptrCast(ctx),
            @ptrCast(mod.name),
            mod.len,
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(&ext),
        )) {
            return ext;
        }
        return null;
    }

    /// Perform all the checks for instantiating `mod` with the linker,
    /// except that instantiation doesn't actually finish.
    ///
    /// For more information see the Rust documentation at:
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html#method.instantiate_pre
    pub fn instantiatePre(l: *const Linker, mod: *const lib.Module) !*lib.InstancePre {
        var ins_pre: *lib.InstancePre = undefined;
        try err.result(c.wasmtime_linker_instantiate_pre(
            @ptrCast(l),
            @ptrCast(mod),
            @ptrCast(&ins_pre),
        ));
        return ins_pre;
    }
};

fn FuncAsyncExtern(comptime Impl: type) type {
    return struct {
        fn call(
            ptr: *anyopaque,
            c_caller: *c.wasmtime_caller_t,
            c_args: [*]const c.wasmtime_val_t,
            args_len: usize,
            c_ret: [*]c.wasmtime_val_t,
            ret_len: usize,
            c_ret_trap: **c.wasm_trap_t,
            continuation_ret: *c.wasmtime_async_continuation_t,
        ) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr);
            const caller: *lib.Func.Caller = @ptrCast(c_caller);
            const args: []const lib.Val = @ptrCast(c_args[0..args_len]);
            const ret_vals: []lib.Val = @ptrCast(c_ret[0..ret_len]);
            const ret_trap: **lib.Trap = @ptrCast(c_ret_trap);

            continuation_ret.* = c.wasmtime_async_continuation_t{
                .callback = state,
                .env = ptr,
                .finalizer = null,
            };

            Impl.call(impl, caller, args, ret_vals, ret_trap);
        }

        fn state(ptr: *anyopaque) callconv(.C) bool {
            const impl: *Impl = @ptrCast(ptr);
            return Impl.state(impl);
        }
    };
}
