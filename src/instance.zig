const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");
const err = @import("error.zig");

pub const InstanceResult = union(enum) {
    instance: Instance,
    trap: *lib.Trap,
};

pub const ExportNthResult = struct {
    name: []const u8,
    ext: lib.Extern,
};

/// Representation of a instance in Wasmtime.
///
/// Instances are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Instances cannot
/// interoperate between `Store` instances and if the wrong instance
/// is passed to the wrong store then it may trigger an assertion to abort the
/// process.
pub const Instance = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,

    /// Internal index within the store.
    index: usize,

    /// Instantiate a wasm module.
    ///
    /// This function will instantiate a WebAssembly module with the provided
    /// imports, creating a WebAssembly instance. The returned instance can then
    /// afterwards be inspected for exports.
    ///
    /// `ctx` is the store in which to create the instance.
    /// `mod` is the module to instantiate.
    /// `imports` are the imports to provide to the module.
    ///
    /// This function requires that `imports` is the same size as the imports that
    /// `mod` has. Additionally the `imports` slice must be 1:1 lined up with the
    /// imports of the `mod` specified. This is intended to be relatively low
    /// level, and `Linker.instantiate` is provided for a more ergonomic
    /// name-based resolution API.
    ///
    /// This function can result in:
    /// 1. The instance is created successfully, and is returned through `InstanceResult.instance`.
    /// 2. The instance was not created due to a trap, which is returned through `InstanceResult.trap`.
    /// 3. The instance was not created due to an error which is returned.
    ///
    /// Note that this function requires that all `imports` specified must be owned
    /// by the store provided as well.
    ///
    /// This function does not take ownership of any of its arguments, but all return
    /// values are owned by the caller.
    pub fn new(ctx: *lib.Context, mod: *const lib.Module, imports: []const lib.Extern) !InstanceResult {
        var instance: Instance = undefined;
        var trap: ?*lib.Trap = null;
        try err.result(c.wasmtime_instance_new(
            @ptrCast(ctx),
            @ptrCast(mod),
            @ptrCast(imports.ptr),
            imports.len,
            @ptrCast(&instance),
            @ptrCast(&trap),
        ));
        if (trap) |t| {
            return InstanceResult{ .trap = t };
        }
        return InstanceResult{ .instance = instance };
    }

    /// Get an export by name from an instance.
    ///
    /// `ctx` should be the store that ownes the instance.
    ///
    /// Doesn't take ownership of any arguments but does give ownership of the
    /// returned `Extern`.
    pub fn exportGet(i: *const Instance, ctx: *lib.Context, name: []const u8) ?lib.Extern {
        var ext: lib.Extern = undefined;
        if (c.wasmtime_instance_export_get(
            @ptrCast(ctx),
            @ptrCast(i),
            @ptrCast(name.ptr),
            name.len,
            @ptrCast(&ext),
        )) {
            return ext;
        }
        return null;
    }

    /// Get an export by index from an instance.
    ///
    /// `ctx` should be the store that owns the instance.
    ///
    /// Returns an `ExportNthResult` with the name of the export and the `Extern` value.
    /// Otherwise returns `null` if not found.
    ///
    /// Doesn't take ownership of any arguments but does return ownership of the
    /// `Extern`. The `name` slice is owned by the `ctx` and must be immediately
    /// used before calling any other APIs on `Context`.
    pub fn exportNth(i: *const Instance, ctx: *lib.Context, index: usize) ?ExportNthResult {
        var name: *c_char = undefined;
        var name_len: usize = undefined;
        var ext: lib.Extern = undefined;
        if (c.wasmtime_instance_export_nth(
            @ptrCast(ctx),
            @ptrCast(i),
            index,
            &name,
            &name_len,
            @ptrCast(&ext),
        )) {
            var result = ExportNthResult{
                .name = undefined,
                .ext = ext,
            };
            result.name.ptr = @ptrCast(name);
            result.name.len = name_len;
            return result;
        }
        return null;
    }
};

/// An `Instance`, pre-instantiation, that is ready to be instantiated.
///
/// Must be deleted using `InstancePre.delete`.
///
/// For more information see the Rust documentation:
/// https://docs.wasmtime.dev/api/wasmtime/struct.InstancePre.html
pub const InstancePre = opaque {
    /// Delete the `InstancePre`.
    pub fn delete(ip: *InstancePre) void {
        c.wasmtime_instance_pre_delete(@ptrCast(ip));
    }

    /// Instantiates instance within the given store `ctx`.
    ///
    /// This will also run the function's startup function, if there is one.
    ///
    /// For more information on instantiation see `Instance.new`.
    ///
    /// One of three things can happen as a result of this function:
    /// 1. The module is successfully instantiated and returned through `InstanceResult.instance`.
    /// 2. The start function results in a trap, which is returned through `InstanceResult.trap`.
    /// 3. The instantiation fails for another reason, and an error is returned.
    ///
    /// This function does not take ownership of any of its arguments, and all return
    /// values are owned by the caller.
    pub fn instantiate(ip: *const InstancePre, ctx: *lib.Context) !InstanceResult {
        var instance: Instance = undefined;
        var trap: ?*lib.Trap = null;
        try err.result(c.wasmtime_instance_pre_instantiate(
            @ptrCast(ip),
            @ptrCast(ctx),
            @ptrCast(&instance),
            @ptrCast(&trap),
        ));
        if (trap) |t| {
            return InstanceResult{ .trap = t };
        }
        return InstanceResult{ .instance = instance };
    }

    /// Get the module (as a shallow clone).
    ///
    /// The returned module is owned by the caller and the caller **must**
    /// delete it via `Module.delete`.
    pub fn module(ip: *InstancePre) *lib.Module {
        return @ptrCast(c.wasmtime_instance_pre_module(@ptrCast(ip)));
    }
};
