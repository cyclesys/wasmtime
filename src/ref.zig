const c = @cImport(@cInclude("wasmtime.h"));

pub const Ref = opaque {
    pub fn delete(r: *Ref) void {
        c.wasm_ref_delete(@ptrCast(r));
    }

    pub fn copy(r: *const Ref) *Ref {
        return c.wasm_ref_copy(@ptrCast(r));
    }

    pub fn same(l: *const Ref, r: *const Ref) bool {
        return c.wasm_ref_same(@ptrCast(l), @ptrCast(r));
    }

    pub fn getHostInfo(r: *const Ref) *anyopaque {
        return c.wasm_ref_get_host_info(@ptrCast(r));
    }

    pub fn setHostInfo(r: *Ref, ptr: *anyopaque) void {
        c.wasm_ref_set_host_info(@ptrCast(r), ptr);
    }

    pub fn setHostInfoWithFinalizer(r: *Ref, ptr: *anyopaque, f: fn (*anyopaque) void) void {
        c.wasm_ref_set_host_info_with_finalizer(@ptrCast(r), ptr, f);
    }
};
