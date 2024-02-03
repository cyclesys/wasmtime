const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");
const vec = @import("vec.zig");

pub const GlobalType = opaque {
    /// Creates a new global type.
    ///
    /// This function takes ownership of the `ValType` argument.
    ///
    /// The caller is responsible for deleting the returned value.
    pub fn new(val_t: *lib.ValType, mut: bool) *GlobalType {
        return @ptrCast(c.wasm_globaltype_new(@ptrCast(val_t), if (mut) c.WASM_VAR else c.WASM_CONST));
    }

    /// Deletes the `GlobalType`.
    pub fn delete(t: *GlobalType) void {
        c.wasm_globaltype_delete(@ptrCast(t));
    }

    /// Returns the type of value contained in the global.
    ///
    /// The returned value is owned by the `GlobalType` argument and should not
    /// be deleted.
    pub fn valType(t: *const GlobalType) *const lib.ValType {
        return @ptrCast(c.wasm_globaltype_content(@ptrCast(t)));
    }

    /// Returns whether or not the global is mutable.
    pub fn mutable(t: *const GlobalType) bool {
        const mut = c.wasm_globaltype_mutability(@ptrCast(t));
        return mut == c.WASM_VAR;
    }

    /// Converts a `GlobalType` to an `ExternType`.
    ///
    /// The returned value is owned by the `GlobalType` argument and should not
    /// be deleted.
    pub fn asExternType(t: *GlobalType) *lib.ExternType {
        return @ptrCast(c.wasm_globaltype_as_externtype(@ptrCast(t)));
    }

    /// Converts a `GlobalType` to an `ExternType`.
    ///
    /// The returned value is owned by the `GlobalType` argument and should not
    /// be deleted.
    pub fn asExternTypeConst(t: *const GlobalType) *const lib.ExternType {
        return @ptrCast(c.wasm_globaltype_as_externtype_const(@ptrCast(t)));
    }
};

/// Representation of a global in Wasmtime.
///
/// Globals are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Globals cannot
/// interoperate between `Store` instances and if the wrong global is passed to
/// the wrong store then it may trigger an assertion to abort the process.
pub const Global = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,
    /// Internal index within the store.
    index: usize,

    /// Creates a new global value.
    ///
    /// Creates a new host-defined global value within the provided `ctx`.
    ///
    /// `ctx`: the store in which to create the global
    /// `ty`: the wasm type of the global being created
    /// `val`: the initial value of the global
    ///
    /// This function may return an error if the `val` argument does not match the
    /// specified type of the global, or if `val` comes from a different store than
    /// the one provided.
    ///
    /// This function does not take ownership of any of its arguments.
    pub fn new(ctx: *lib.Context, ty: *const lib.GlobalType, val: *const lib.Val) !Global {
        var g: Global = undefined;
        try err.result(c.wasmtime_global_new(@ptrCast(ctx), @ptrCast(ty), @ptrCast(val), @ptrCast(&g)));
        return g;
    }

    /// Returns the wasm type of the specified global.
    ///
    /// The returned `GlobalType` is owned by the caller.
    pub fn typ(g: *const Global, ctx: *lib.Context) *lib.GlobalType {
        return @ptrCast(c.wasmtime_global_type(@ptrCast(ctx), @ptrCast(g)));
    }

    /// Get the value of the specified global.
    ///
    /// `g`: the global to get
    /// `ctx`: the store that owns `g`
    ///
    /// This function returns ownership of the contents of the returned `Val`, so
    /// `Val.delete` may need to be called on the value.
    pub fn get(g: *const Global, ctx: *lib.Context) lib.Val {
        var val: lib.Val = undefined;
        c.wasmtime_global_get(@ptrCast(ctx), @ptrCast(g), @ptrCast(&val));
        return val;
    }

    /// Sets a global to a new value.
    ///
    /// `g`: the global to set
    /// `ctx`: the store that owns `g`
    /// `val`: the value to store in the global
    ///
    /// This function may return an error if `g` is not mutable or if `val` has
    /// the wrong type for `g`.
    ///
    /// This does not take ownership of any argument.
    pub fn set(g: *const Global, ctx: *lib.Context, val: *const lib.Val) !void {
        try err.result(c.wasmtime_global_set(@ptrCast(ctx), @ptrCast(g), @ptrCast(val)));
    }
};
