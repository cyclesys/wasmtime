const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");

/// An opaque object representing the type of a memory.
pub const MemoryType = opaque {
    /// Creates a new memory type from the specified parameters.
    pub fn new(minimum: u64, maximum: ?u64, is_64: bool) *MemoryType {
        return @ptrCast(c.wasmtime_memorytype_new(
            minimum,
            maximum != null,
            maximum orelse 0,
            is_64,
        ));
    }

    /// Delete the `MemoryType`.
    pub fn delete(t: *MemoryType) void {
        c.wasm_memorytype_delete(@ptrCast(t));
    }

    /// Returns the minimum size, in pages, of the specified memory type.
    pub fn min(t: *const MemoryType) u64 {
        return c.wasmtime_memorytype_minimum(@ptrCast(t));
    }

    /// Returns the maximum size, in pages, of the specified memory type.
    ///
    /// If this memory type doesn't have a maximum size listed then `null` is
    /// returned, otherwise the maximum size in pages is returned.
    pub fn max(t: *const MemoryType) ?u64 {
        var v: u64 = undefined;
        if (c.wasmtime_memorytype_maximum(@ptrCast(t), @ptrCast(&v))) {
            return v;
        }
        return null;
    }

    /// Returns whether this type of memory represents a 64-bit memory.
    pub fn is64(t: *const MemoryType) bool {
        return c.wasmtime_memorytype_is64(@ptrCast(t));
    }

    /// Converts a `MemoryType` to an `ExternType`.
    ///
    /// The returned value is owned by the `MemoryType` argument and should not
    /// be deleted.
    pub fn asExternType(t: *MemoryType) *lib.ExternType {
        return @ptrCast(c.wasm_memorytype_as_externtype(@ptrCast(t)));
    }

    /// Converts a `MemoryType` to an `ExternType`.
    ///
    /// The returned value is owned by the `MemoryType` argument and should not
    /// be deleted.
    pub fn asExternTypeConst(t: *const MemoryType) *const lib.ExternType {
        return @ptrCast(c.wasm_memorytype_as_externtype_const(@ptrCast(t)));
    }
};

/// Representation of a memory in Wasmtime.
///
/// Memories are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Memories cannot
/// interoperate between `Store` instances and if the wrong memory is passed to
/// the wrong store then it may trigger an assertion to abort the process.
pub const Memory = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,
    /// Internal index within the store.
    index: usize,

    /// Creates a new WebAssembly linear memory
    ///
    /// `ctx`: the store to create the memory within
    /// `ty`: the type of the memory to create
    pub fn new(ctx: *lib.Context, ty: *const MemoryType) !Memory {
        var m: Memory = undefined;
        try err.result(c.wasmtime_memory_new(@ptrCast(ctx), @ptrCast(ty), @ptrCast(&m)));
        return m;
    }

    /// Returns the type of the memory specified
    pub fn typ(m: *const Memory, ctx: *const lib.Context) *MemoryType {
        return @ptrCast(c.wasmtime_memory_type(@ptrCast(ctx), @ptrCast(m)));
    }

    /// Returns the base pointer in memory where the linear memory starts.
    pub fn ptr(m: *const Memory, ctx: *const lib.Context) [*]u8 {
        return @ptrCast(c.wasmtime_memory_data(@ptrCast(ctx), @ptrCast(m)));
    }

    /// Returns the length in bytes of this linear memory
    pub fn size(m: *const Memory, ctx: *const lib.Context) usize {
        return c.wasmtime_memory_data_size(@ptrCast(ctx), @ptrCast(m));
    }

    /// Returns the length in WebAssembly pages of this linear memory
    pub fn pageSize(m: *const Memory, ctx: *const lib.Context) usize {
        return c.wasmtime_memory_size(@ptrCast(ctx), @ptrCast(m));
    }

    /// Convenience function that returns the memory as a slice of bytes.
    /// Calls `Memory.ptr` and `Memory.size` internally.
    pub fn bytes(m: *const Memory, ctx: *const lib.Context) []u8 {
        const p = m.ptr(ctx);
        const len = m.size(ctx);
        return p[0..len];
    }

    /// Attempts to grow the specified memory by `delta` pages.
    ///
    /// `m`: the memory to grow
    /// `ctx`: the store that owns `m`
    /// `delta`: the number of pages to grow by
    ///
    /// If memory cannot be grown then an error is returned.
    /// Otherwise the previous size of the memory, in WebAssembly pages, is returned.
    pub fn grow(m: *const Memory, ctx: *lib.Context, delta: u64) !u64 {
        var prev_size: u64 = undefined;
        try err.result(c.wasmtime_memory_grow(@ptrCast(ctx), @ptrCast(m), delta, &prev_size));
        return prev_size;
    }
};
