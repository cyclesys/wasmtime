const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const vec = @import("vec.zig");
const UserData = @import("UserData.zig");

/// Different kinds of types supported in wasm.
pub const ValKind = enum(u8) {
    i32,
    i64,
    f32,
    f64,
    any_ref = 128,
    func_ref,

    /// Whether this val kind is a num kind.
    pub fn isNum(k: ValKind) bool {
        return k < @intFromEnum(ValKind.any_ref);
    }

    /// Whether this val kind is a ref type.
    pub fn isRef(k: ValKind) bool {
        return k >= @intFromEnum(ValKind.any_ref);
    }
};

/// An object representing the type of a value.
pub const ValType = opaque {
    /// Creates a new value type from the specified kind.
    ///
    /// The caller is responsible for deleting the returned type.
    pub fn new(k: ValKind) *ValType {
        return c.wasm_valtype_new(@intFromEnum(k));
    }

    /// Deletes the `ValType`.
    pub fn delete(t: *ValType) void {
        c.wasm_valtype_delete(@ptrCast(t));
    }

    /// Returns the associated kind for this value type.
    pub fn kind(t: *const ValType) ValKind {
        return @enumFromInt(c.wasm_valtype_kind(@ptrCast(t)));
    }
};

/// A list of `ValType` values.
pub const ValTypeVec = vec.Vec(*lib.ValType, "valtype");

/// A host-defined un-forgeable reference to pass into WebAssembly.
///
/// This structure represents an `externref` that can be passed to WebAssembly.
/// It cannot be forged by WebAssembly itself and is guaranteed to have been
/// created by the host.
pub const ExternRef = opaque {
    /// Creates a new `ExternRef` value wrapping the provided data, returning the
    /// pointer to the externref.
    ///
    /// `impl` should be a pointer to a type that optionally has a `finalize` function:
    /// ```zig
    /// const Impl = struct {
    ///     /// Optional
    ///     pub fn finalize(data: *Impl) void {
    ///     }
    /// };
    /// ```
    /// When the reference is reclaimed finalize will be called.
    ///
    /// The returned value must be deleted with `ExternRef.delete`.
    pub fn new(impl: anytype) *ExternRef {
        const ud = UserData.create(impl);
        return @ptrCast(c.wasmtime_externref_new(ud.ptr, ud.finalizer));
    }

    /// Decrements the reference count of the `ExternRef`, deleting it if it's the
    /// last reference.
    pub fn delete(er: *ExternRef) void {
        c.wasmtime_externref_delete(@ptrCast(er));
    }

    /// Returns the original `data_ptr` passed to `ExternRef.new`.
    pub fn data(er: *ExternRef) *anyopaque {
        return c.wasmtime_externref_data(@ptrCast(er));
    }

    /// Creates a shallow copy of the `ExternRef`, returning a
    /// separately owned pointer (increases the reference count).
    pub fn clone(er: *ExternRef) *ExternRef {
        return @ptrCast(c.wasmtime_externref_clone(@ptrCast(er)));
    }

    /// Converts a `RawVal.extern_ref` value into an `ExternRef`.
    ///
    /// Note that the returned `ExternRef` is an owned value that must be
    /// deleted via `ExternRef.delete` by the caller if it is non-null.
    pub fn fromRaw(ctx: *lib.Context, raw: RawVal) ?*ExternRef {
        return @ptrCast(c.wasmtime_externref_from_raw(@ptrCast(ctx), raw.extern_ref));
    }

    /// Converts the `ExternRef` to a `RawVal.extern_ref`.
    ///
    /// Note that the returned underlying value is not tracked by Wasmtime's garbage
    /// collector until it enters WebAssembly. This means that a GC may release the
    /// context's reference to the raw value, making the raw value invalid within the
    /// context of the store. Do not perform a GC between calling this function and
    /// passing it to WebAssembly.
    pub fn toRaw(er: *const ExternRef, ctx: *lib.Context) RawVal {
        const extern_ref = c.wasmtime_externref_to_raw(@ptrCast(ctx), @ptrCast(er));
        return RawVal{ .extern_ref = extern_ref };
    }
};

/// A 128-bit value representing the WebAssembly `v128` type. Bytes are
/// stored in little-endian order.
pub const v128 = [16]u8;

/// Container for different kinds of wasm values.
///
/// Note that this structure may contain an owned value, namely
/// `ExternRef`, depending on the context in which this is used. APIs
/// which consume a `Val` do not take ownership, but APIs that return
/// `Val` require that `Val.delete` is called to deallocate the value.
pub const Val = extern struct {
    /// discriminant
    tag: Tag,
    /// payload
    data: Data,

    /// Discriminant of `Val`.
    pub const Tag = enum(u8) {
        /// `Val` contains an `i32`.
        i32,
        /// `Val` contains an `i64`.
        i64,
        /// `Val` contains an `f32`.
        f32,
        /// `Val` contains an `f64`.
        f64,
        /// `Val` contains a `v128`.
        v128,
        /// `Val` contains a `Func`.
        func_ref,
        /// `Val` contains an `*ExternRef`.
        extern_ref,
    };

    /// Payload of `Val`.
    pub const Data = extern union {
        /// `i32` payload if `tag` is `i32`.
        i32: i32,
        /// `i64` payload if `tag` is `i64`.
        i64: i64,
        /// `f32` payload if `tag` is `f32`.
        f32: f32,
        /// `f64` payload if `tag` is f64`.
        f64: f64,
        /// `v128` payload if `tag` is `v128`.
        v128: v128,
        /// `Func` payload if `tag` is `func_ref`.
        func_ref: lib.Func,
        /// `*ExternRef` payload if `tag` is `extern_ref`.
        extern_ref: *ExternRef,
    };

    pub fn newI32(v: i32) Val {
        return Val{
            .tag = .i32,
            .data = .{ .i32 = v },
        };
    }

    pub fn newI64(v: i64) Val {
        return Val{
            .tag = .i64,
            .data = .{ .i64 = v },
        };
    }

    pub fn newF32(v: f32) Val {
        return Val{
            .tag = .f32,
            .data = .{ .f32 = v },
        };
    }

    pub fn newF64(v: f64) Val {
        return Val{
            .tag = .f64,
            .data = .{ .f64 = v },
        };
    }

    pub fn newV128(v: v128) Val {
        return Val{
            .tag = .v128,
            .data = .{ .v128 = v },
        };
    }

    pub fn newFuncRef(v: lib.Func) Val {
        return Val{
            .tag = .func_ref,
            .data = .{ .func_ref = v },
        };
    }

    pub fn newExternRef(v: *ExternRef) Val {
        return Val{
            .tag = .extern_ref,
            .data = .{ .extern_ref = v },
        };
    }

    /// Deletes an owned `Val`.
    ///
    /// Note that this only deletes the contents, not the memory that `val` points to
    /// itself (which is owned by the caller).
    pub fn delete(val: *Val) void {
        c.wasmtime_val_delete(@ptrCast(val));
    }

    /// Creates a copy of `val`.
    pub fn copy(val: Val) Val {
        var dst: Val = undefined;
        c.wasmtime_val_copy(@ptrCast(&dst), @ptrCast(&val));
    }
};

/// Container for possible wasm values.
///
/// This type is used on conjunction with `Func.newUnchecked` as well
/// as `Func.callUnchecked`. Instances of this type do not have type
/// information associated with them, it's up to the embedder to figure out
/// how to interpret the bits contained within, often using some other channel
/// to determine the type.
pub const RawVal = extern union {
    /// Field for when this val is a WebAssembly `i32` value.
    ///
    /// Note that this field is always stored in a little-endian format.
    i32: i32,
    /// Field for when this val is a WebAssembly `i64` value.
    ///
    /// Note that this field is always stored in a little-endian format.
    i64: i64,
    /// Field for when this val is a WebAssembly `f32` value.
    ///
    /// Note that this field is always stored in a little-endian format.
    f32: f32,
    /// Field for when this val is a WebAssembly `f64` value.
    ///
    /// Note that this field is always stored in a little-endian format.
    f64: f64,
    /// Field for when this val is a WebAssembly `v128` value.
    ///
    /// Note that this field is always stored in a little-endian format.
    v128: v128,
    /// Field for when this val is a WebAssembly `funcref` value.
    ///
    /// If this is set to `null` then it's a null funcref, otherwise this must be
    /// passed to `Func.fromRaw` to determine the `Func`.
    ///
    /// Note that this field is always stored in a little-endian format.
    func_ref: ?*anyopaque,
    /// Field for when this val is a WebAssembly `externref` value.
    ///
    /// If this is set to `null` then it's a null externref, otherwise this must be
    /// passed to `ExternRef.fromRaw` to determine the `ExternRef`.
    ///
    /// Note that this field is always stored in a little-endian format.
    extern_ref: ?*anyopaque,
};
