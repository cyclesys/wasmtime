const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");

fn Vec(comptime Elem: type, comptime elem_name: []const u8) type {
    return struct {
        inner: Inner,

        const Inner = decl("t");
        const ElemVec = @This();

        pub fn newEmpty() ElemVec {
            const f = comptime decl("new_empty");
            var inner: Inner = undefined;
            f(&inner);
            return ElemVec{ .inner = inner };
        }

        pub fn newUninitialized(size: usize) ElemVec {
            const f = comptime decl("new_uninitialized");
            var inner: Inner = undefined;
            f(&inner, size);
            return ElemVec{ .inner = inner };
        }

        pub fn new(init_elems: []const Elem) ElemVec {
            const f = comptime decl("new");
            var inner: Inner = undefined;
            f(&inner, init_elems.len, @ptrCast(init_elems.ptr));
            return ElemVec{ .inner = inner };
        }

        pub fn newSentinel(comptime s: Elem, init_elems: [:s]const Elem) ElemVec {
            const f = comptime decl("new");
            var inner: Inner = undefined;
            f(&inner, init_elems.len + 1, @ptrCast(init_elems.ptr));
            return ElemVec{ .inner = inner };
        }

        pub fn copy(dest: *ElemVec, src: ElemVec) void {
            const f = comptime decl("copy");
            f(&dest.inner, &src.inner);
        }

        pub fn delete(ev: *ElemVec) void {
            const f = comptime decl("delete");
            f(&ev.inner);
        }

        pub fn elems(ev: *ElemVec) []const Elem {
            var out: []const Elem = undefined;
            out.ptr = @ptrCast(ev.inner.data);
            out.len = ev.inner.size;
            return out;
        }

        fn decl(comptime name: []const u8) @TypeOf(@field(c, ident(name))) {
            return @field(c, ident(name));
        }

        fn ident(comptime name: []const u8) []const u8 {
            return "wasm_" ++ elem_name ++ "_vec_" ++ name;
        }
    };
}

pub const ByteVec = Vec(u8, "byte");

pub const Name = ByteVec;

pub const FrameVec = Vec(*lib.Frame, "frame");
