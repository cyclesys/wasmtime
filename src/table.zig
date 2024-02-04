const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");
const vec = @import("vec.zig");

/// Limits for tables in wasm modules.
pub const Limits = extern struct {
    min: u32,
    max: u32,
};

/// An opaque object representing the type of a table.
pub const TableType = opaque {
    /// Creates a new table type.
    ///
    /// This function takes ownership of the `ValType` argument.
    ///
    /// The caller is responsible for deleting the returned type.
    pub fn new(val_t: *lib.ValType, lim: Limits) *TableType {
        return @ptrCast(c.wasm_tabletype_new(@ptrCast(val_t), @ptrCast(&lim)));
    }

    /// Delete the `TableType`.
    pub fn delete(t: *TableType) void {
        c.wasm_tabletype_delete(@ptrCast(t));
    }

    /// Returns the element type of this table.
    ///
    /// The returned value is owned by the `TableType` argument and should not
    /// be deleted.
    pub fn elemType(t: *TableType) *const lib.ValType {
        return @ptrCast(c.wasm_tabletype_element(@ptrCast(t)));
    }

    /// Returns the limits of this table.
    pub fn limits(t: *const TableType) Limits {
        const lim: *const Limits = @ptrCast(c.wasm_tabletype_limits(@ptrCast(t)));
        return lim.*;
    }

    /// Converts a `TableType` to an `ExternType`.
    ///
    /// The returned value is owned by the `TableType` argument and should not
    /// be deleted.
    pub fn asExternType(t: *TableType) *lib.ExternType {
        return @ptrCast(c.wasm_tabletype_as_externtype(@ptrCast(t)));
    }

    /// Converts a `TableType` to an `ExternType`.
    ///
    /// The returned value is owned by the `TableType` argument and should not
    /// be deleted.
    pub fn asExternTypeConst(t: *const TableType) *const lib.ExternType {
        return @ptrCast(c.wasm_tabletype_as_externtype_const(@ptrCast(t)));
    }
};

/// Representation of a table in Wasmtime.
///
/// Tables are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Tables cannot
/// interoperate between `Store` instances and if the wrong table is passed to
/// the wrong store then it may trigger an assertion to abort the process.
pub const Table = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,
    /// Internal index within the store.
    index: usize,

    /// Creates a new host-defined wasm table.
    ///
    /// `ctx`: store the store to create the table within
    /// `ty`: ty the type of the table to create
    /// `init`: init the initial value for this table's elements
    ///
    /// This function does not take ownership of any of its parameters.
    ///
    /// This function may return an error if the `init` value does not match `ty`, for example.
    pub fn new(ctx: *lib.Context, ty: *const lib.TableType, init: *const lib.Val) !Table {
        var t: Table = undefined;
        try err.result(c.wasmtime_table_new(@ptrCast(ctx), @ptrCast(ty), @ptrCast(init), @ptrCast(&t)));
        return t;
    }

    /// Returns the type of this table.
    ///
    /// The caller has ownership of the returned `TableType`.
    pub fn typ(t: *const Table, ctx: *const lib.Context) *lib.TableType {
        return @ptrCast(c.wasmtime_table_type(@ptrCast(ctx), @ptrCast(t)));
    }

    /// Gets a value in a table.
    ///
    /// `t`: the table to access
    /// `ctx`:the store that owns `t`
    /// `index`: the table index to access
    ///
    /// This function will attempt to access a table element. A `Val` is returned if
    /// `index` is valid, and the `Val` is owned by the caller. `null` is returned
    /// if the `index` is out of bounds.
    pub fn get(t: *const Table, ctx: *lib.Context, index: u32) ?lib.Val {
        var val: lib.Val = undefined;
        if (c.wasmtime_table_get(@ptrCast(ctx), @ptrCast(t), index, @ptrCast(&val))) {
            return val;
        }
        return null;
    }

    /// Sets a value in a table.
    ///
    /// `t`: the table to write to
    /// `ctx`: the store that owns `t`
    /// `index`: the table index to write
    /// `val`: the value to store.
    ///
    /// This function will store `val` into the specified index in the table. This
    /// does not take ownership of any argument.
    ///
    /// This function can fail if `val` has the wrong type for the table, or if
    /// `index` is out of bounds.
    pub fn set(t: *const Table, ctx: *lib.Context, index: usize, val: *const lib.Val) !void {
        try err.result(c.wasmtime_table_set(@ptrCast(ctx), @ptrCast(t), index, @ptrCast(val)));
    }

    /// Returns the size, in elements, of the specified table
    pub fn size(t: *const Table, ctx: *const lib.Context) u32 {
        return c.wasmtime_table_size(@ptrCast(ctx), @ptrCast(t));
    }

    /// Grows a table.
    ///
    /// `t`: the table to grow
    /// `ctx`: the store that owns `t`
    /// `delta`: the number of elements to grow the table by
    /// `init`: the initial value for new table element slots
    ///
    /// Returns the size of the table before the growth.
    ///
    /// This function will attempt to grow the table by `delta` table elements. This
    /// can fail if `delta` would exceed the maximum size of the table or if `init`
    /// is the wrong type for this table. If growth is successful then the previous size
    /// of the table in elements, before the growth happened, is returned.
    ///
    /// This function does not take ownership of any of its arguments.
    pub fn grow(t: *const Table, ctx: *lib.Context, delta: u32, init: *const lib.Val) !u32 {
        var prev_size: u32 = undefined;
        try err.result(c.wasmtime_table_grow(@ptrCast(ctx), @ptrCast(t), delta, @ptrCast(init), &prev_size));
        return prev_size;
    }
};
