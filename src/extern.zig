const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");

/// The kind of external item represented by an `ExternType` or `Extern`.
pub const ExternKind = enum(u8) {
    /// Represents a `FuncType` or `Func`.
    func,
    /// Represents a `GlobalType` or `Global`.
    global,
    /// Represents a `TableType` or `Table`.
    table,
    /// Represents a `MemoryType` or `Memory`.
    memory,
};

/// An opaque object representing the type of an external value. Can be seen
/// as a superclass of `FuncType`, `GlobalType`, `TableType`, and `MemoryType`.
pub const ExternType = opaque {
    /// Deletes a type.
    pub fn delete(t: *ExternType) void {
        c.wasm_externtype_delete(@ptrCast(t));
    }

    /// Returns the kind of external item this type represents.
    pub fn kind(t: *const ExternType) ExternKind {
        return @enumFromInt(c.wasm_externtype_kind(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `FuncType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `FuncType`.
    pub fn asFuncType(t: *ExternType) ?*lib.FuncType {
        return @ptrCast(c.wasm_externtype_as_functype(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `FuncType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `FuncType`.
    pub fn asFuncTypeConst(t: *const ExternType) *const lib.FuncType {
        return @ptrCast(c.wasm_externtype_as_functype_const(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `GlobalType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `GlobalType`.
    pub fn asGlobalType(t: *ExternType) *lib.GlobalType {
        return @ptrCast(c.wasm_externtype_as_globaltype(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `GlobalType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `GlobalType`.
    pub fn asGlobalTypeConst(t: *const ExternType) *const lib.GlobalType {
        return @ptrCast(c.wasm_externtype_as_globaltype_const(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `TableType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `TableType`.
    pub fn asTableType(t: *ExternType) *lib.TableType {
        return @ptrCast(c.wasm_externtype_as_tabletype(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `TableType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `TableType`.
    pub fn asTableTypeConst(t: *const ExternType) *const lib.TableType {
        return @ptrCast(c.wasm_externtype_as_tabletype_const(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `MemoryType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `MemoryType`.
    pub fn asMemoryType(t: *ExternType) *lib.MemoryType {
        return @ptrCast(c.wasm_externtype_as_memorytype(@ptrCast(t)));
    }

    /// Attempts to convert an `ExternType` to a `MemoryType`.
    ///
    /// The returned value is owned by the `ExternType` argument and should not
    /// be deleted. Returns `null` if the provided argument is not a `MemoryType`.
    pub fn asMemoryTypeConst(t: *const ExternType) *const lib.MemoryType {
        return @ptrCast(c.wasm_externtype_as_memorytype_const(@ptrCast(t)));
    }
};

/// Container for different kinds of extern items.
///
/// Note that this structure may contain an owned value, namely
/// `Module`, depending on the context in which this is used. APIs
/// which consume an `Extern` do not take ownership, but APIs that
/// return an `Extern` require that `Extern.delete` is called to
/// deallocate the value.
pub const Extern = extern struct {
    tag: ExternKind,
    data: Data,

    /// Payload of `Extern`.
    pub const Data = extern union {
        /// `Func` payload if `tag is `func`.
        func: lib.Func,
        /// `Global` payload if `tag` is `global`.
        global: lib.Global,
        /// `Table` payload if `tag` is `table`.
        table: lib.Table,
        /// `Memory` payload if `tag` is `memory`.
        memory: lib.Memory,
    };

    /// Create an `Extern` with a `Func` payload.
    pub fn newFunc(f: lib.Func) Extern {
        return Extern{
            .tag = .func,
            .data = Data{ .func = f },
        };
    }

    /// Create an `Extern` with a `Global` payload.
    pub fn newGlobal(g: lib.Global) Extern {
        return Extern{
            .tag = .global,
            .data = Data{ .global = g },
        };
    }

    /// Create an `Extern` with a `Table` payload.
    pub fn newTable(t: lib.Table) Extern {
        return Extern{
            .tag = .table,
            .data = Data{ .table = t },
        };
    }

    /// Create an `Extern` with a `Memory` payload.
    pub fn newMemory(m: lib.Memory) Extern {
        return Extern{
            .tag = .memory,
            .data = Data{ .memory = m },
        };
    }

    /// Deletes the `Extern`
    pub fn delete(ex: *Extern) void {
        c.wasmtime_extern_delete(@ptrCast(ex));
    }

    /// Returns the `ExternType` of the `Extern`.
    ///
    /// Does not take ownership of `ex` or `ctx`, but the returned
    /// `ExternType` is an owned value that needs to be deleted.
    pub fn typ(ex: *Extern, ctx: *lib.Context) *ExternType {
        return @ptrCast(c.wasmtime_extern_type(@ptrCast(ctx), @ptrCast(ex)));
    }
};
