const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");
const vec = @import("vec.zig");

/// An opaque object representing the type of an import.
pub const ImportType = opaque {
    /// Creates a new import type.
    ///
    /// This function takes ownership of the module `Module`, name `Name`, and
    /// `Extern` arguments. The caller is responsible for deleting the
    /// returned value. Note that `name` can be `null` where in the module linking
    /// proposal the import name can be omitted.
    pub fn new(m: *lib.Module, n: ?*lib.Name, ext: *lib.ExternType) *ImportType {
        return @ptrCast(c.wasm_importtype_new(@ptrCast(m), @ptrCast(n), @ptrCast(ext)));
    }

    /// Delete the `ImportType`.
    pub fn delete(it: *ImportType) void {
        c.wasm_importtype_delete(@ptrCast(it));
    }

    /// \brief Returns the module this import is importing from.
    ///
    /// The returned value is owned by the `ImportType` argument and should not
    /// be deleted.
    pub fn module(it: *const ImportType) *const lib.Name {
        return @ptrCast(c.wasm_importtype_module(@ptrCast(it)));
    }

    /// Returns the name this import is importing from.
    ///
    /// The returned value is owned by the `ImportType` argument and should not
    /// be deleted.
    ///
    /// Note that `null` can be returned which means that the import name is not
    /// provided. This is for imports with the module linking proposal that only
    /// have the module specified.
    pub fn name(it: *const ImportType) ?*const lib.Name {
        return @ptrCast(c.wasm_importtype_name(@ptrCast(it)));
    }

    /// Returns the type of item this import is importing.
    ///
    /// The returned value is owned by the `ImportType` argument and should not
    /// be deleted.
    pub fn externType(it: *const ImportType) *const lib.ExternType {
        return @ptrCast(c.wasm_importtype_type(@ptrCast(it)));
    }
};

/// A list of `ImportType` values.
pub const ImportTypeVec = vec.Vec(*lib.ImportType, "importtype");

/// An opaque object representing the type of an export.
pub const ExportType = opaque {
    /// Creates a new export type.
    ///
    /// This function takes ownership of the `Name` and `ExternType` arguments.
    /// The caller is responsible for deleting the returned value.
    pub fn new(n: *lib.Name, ext: *lib.ExternType) *ExportType {
        return @ptrCast(c.wasm_exporttype_new(@ptrCast(n), @ptrCast(ext)));
    }

    /// Delete the `ExportType`.
    pub fn delete(t: *ExportType) void {
        c.wasm_exporttype_delete(@ptrCast(t));
    }

    /// Returns the name of this export.
    ///
    /// The returned value is owned by the `ExportType` argument and should not
    /// be deleted.
    pub fn name(t: *const ExportType) *const lib.Name {
        return @ptrCast(c.wasm_exporttype_name(@ptrCast(t)));
    }

    /// Returns the type of this export.
    ///
    /// The returned value is owned by the `ExportType` argument and should not
    /// be deleted.
    pub fn externType(t: *const ExportType) *const lib.ExternType {
        return @ptrCast(c.wasm_exporttype_type(@ptrCast(t)));
    }
};

/// A list of `ExportType` values.
pub const ExportTypeVec = vec.Vec(*lib.ExportType, "exporttype");

/// The range of bytes in memory that a compiled `Module` resides in.
pub const ImageRange = struct {
    /// Start is inclusive
    start: usize,
    /// End is exclusive
    end: usize,
};

/// A compiled Wasmtime module
///
/// This type represents a compiled WebAssembly module. The compiled module is
/// ready to be instantiated and can be inspected for imports/exports. It is safe
/// to use a module across multiple threads simultaneously.
pub const Module = opaque {
    /// Compiles a WebAssembly binary into a `Module`.
    ///
    /// This function does not take ownership of any of its arguments, but the
    /// returned module is owned by the caller.
    pub fn new(engine: *lib.Engine, wasm: []const u8) !*Module {
        var ret: ?*c.wasmtime_module_t = null;
        try err.result(c.wasmtime_module_new(@ptrCast(engine), wasm.ptr, wasm.len, &ret));
        return @ptrCast(ret.?);
    }

    /// Deletes the `Module`.
    pub fn delete(m: *Module) void {
        c.wasmtime_module_delete(@ptrCast(m));
    }

    /// Creates a shallow clone of this module, increasing the
    /// internal reference count.
    pub fn clone(m: *Module) *Module {
        return @ptrCast(c.wasmtime_module_clone(@ptrCast(m)));
    }

    pub fn imports(m: *const Module) ImportTypeVec {
        var imps: ImportTypeVec = undefined;
        c.wasmtime_module_imports(@ptrCast(m), @ptrCast(&imps));
        return imps;
    }

    pub fn exports(m: *const Module) ExportType {
        var exps: ExportTypeVec = undefined;
        c.wasmtime_module_exports(@ptrCast(m), @ptrCast(&exps));
        return exps;
    }

    /// This function serializes compiled module artifacts as blob data.
    ///
    /// This function does not take ownership of `module`, and the caller is
    /// expected to deallocate the returned `ByteVec`.
    pub fn serialize(m: *Module) !lib.ByteVec {
        var bytes: lib.ByteVec = undefined;
        try err.result(c.wasmtime_module_serialize(@ptrCast(m), @ptrCast(&bytes)));
        return bytes;
    }

    /// Returns the range of bytes in memory where this module’s compilation
    /// image resides.
    ///
    /// The compilation image for a module contains executable code, data, debug
    /// information, etc. This is roughly the same as the `Module.serialize`
    /// but not the exact same.
    ///
    /// For more details see:
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Module.html#method.image_range
    pub fn imageRange(m: *Module) ImageRange {
        var start: usize = undefined;
        var end: usize = undefined;
        c.wasmtime_module_image_range(@ptrCast(m), @ptrCast(&start), @ptrCast(&end));
        return ImageRange{
            .start = start,
            .end = end,
        };
    }
};
