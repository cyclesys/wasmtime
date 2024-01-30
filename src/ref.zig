const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");

/// A reference type: either a funcref or an externref.
pub const Ref = opaque {
    pub usingnamespace MakeRefBase(Ref);
};

pub fn MakeRefBase(comptime T: type, comptime name: []const u8) type {
    return struct {
        /// Copies a value of this type to a new one.
        ///
        /// The caller is reponsible for deleting the returned value.
        pub fn copy(t: *const T) *T {
            const f = decl("copy");
            return @ptrCast(f(@ptrCast(t)));
        }

        /// Are the given references pointing to the same externref?
        ///
        /// Note: Wasmtime does not support checking funcrefs for equality, and this
        /// function will always return false for funcrefs.
        ///
        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn same(l: *const T, r: *const T) bool {
            const f = decl("same");
            return f(@ptrCast(l), @ptrCast(r));
        }

        /// Unimplemented for `Ref` in Wasmtime, always returns `null`.
        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn getHostInfo(t: *const T) ?*anyopaque {
            const f = decl("get_host_info");
            return f(@ptrCast(t));
        }

        /// Unimplemented for `Ref` in Wasmtime, aborts the process if called.
        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn setHostInfo(t: *T, ptr: *anyopaque) void {
            const f = decl("set_host_info");
            f(@ptrCast(t), ptr);
        }

        /// Unimplemented for `Ref` in Wasmtime, aborts the process if called.
        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn setHostInfoWithFinalizer(t: *T, ptr: *anyopaque, finalizer: fn (*anyopaque) void) void {
            const f = decl("set_host_info_with_finalizer");
            f(@ptrCast(t), ptr, finalizer);
        }

        fn decl(comptime qualifier: []const u8) @TypeOf(@field(c, ident(qualifier))) {
            return @field(c, ident(qualifier));
        }

        fn ident(comptime qualifier: []const u8) []const u8 {
            return "wasm_" ++ name ++ "_" ++ qualifier;
        }
    };
}

pub fn MakeRef(comptime T: type, comptime name: []const u8) type {
    return struct {
        const base = MakeRefBase(T, name);
        pub usingnamespace base;

        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn fromRef(r: *Ref) *T {
            const f = @field(c, "wasm_ref_as_" ++ name);
            return @ptrCast(f(@ptrCast(r)));
        }

        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn fromRefConst(r: *const Ref) *const T {
            const f = @field(c, "wasm_ref_as_" ++ name ++ "_const");
            return @ptrCast(f(@ptrCast(r)));
        }

        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn asRef(t: *T) *Ref {
            const f = base.decl("as_ref");
            return @ptrCast(f(@ptrCast(t)));
        }

        /// Unimplemented for `Trap` in Wasmtime, aborts the process if called.
        pub fn asRefConst(t: *const T) *const Ref {
            const f = base.decl("as_ref_const");
            return @ptrCast(f(@ptrCast(t)));
        }
    };
}

pub fn MakeShareableRef(comptime T: type, comptime SharedT: type, comptime name: []const u8) type {
    return struct {
        const base = MakeRef(T, name);
        pub usingnamespace base;

        /// Creates a shareable value from the provided value.
        ///
        /// This function does not take ownership of the argument, but the caller is
        /// expected to deallocate the returned value.
        ///
        /// > Note that this API is not necessary in Wasmtime because `Module` can
        /// > be shared across threads. This is implemented for compatibility, however.
        pub fn share(t: *const T) *SharedT {
            const f = base.decl("share");
            return @ptrCast(f(@ptrCast(t)));
        }

        /// * Attempts to create a non-shareable value from the shareable value.
        /// *
        /// * This function does not take ownership of its arguments, but the caller is
        /// * expected to deallocate the returned value.
        /// *
        /// * This function may fail if the engines associated with the `Store` or
        /// * the value are different.
        /// *
        /// * > Note that this API is not necessary in Wasmtime because `Module` can
        /// * > be shared across threads. This is implemented for compatibility, however.
        pub fn obtain(store: *lib.Store, t: *const SharedT) *T {
            const f = base.decl("obtain");
            return @ptrCast(f(@ptrCast(store), @ptrCast(t)));
        }
    };
}
