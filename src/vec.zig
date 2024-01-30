const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");

fn Vec(comptime Elem: type, comptime elem_name: []const u8) type {
    return extern struct {
        size: usize,
        data: [*]Elem,

        const ElemVec = @This();

        pub fn newUninitialized(size: usize) ElemVec {
            const f = decl("new_uninitialized");
            var ev: ElemVec = undefined;
            f(&ev, size);
            return ev;
        }

        pub fn newEmpty() ElemVec {
            const f = decl("new_empty");
            var ev: ElemVec = undefined;
            f(&ev);
            return ev;
        }

        pub fn new(init_elems: []const Elem) ElemVec {
            const f = decl("new");
            var ev: ElemVec = undefined;
            f(&ev, init_elems.len, @ptrCast(init_elems.ptr));
            return ev;
        }

        pub fn newSentinel(comptime s: Elem, init_elems: [:s]const Elem) ElemVec {
            const f = decl("new");
            var ev: ElemVec = undefined;
            f(&ev, init_elems.len + 1, @ptrCast(init_elems.ptr));
            return ev;
        }

        pub fn copy(dest: *ElemVec, src: ElemVec) void {
            const f = decl("copy");
            f(@ptrCast(dest), @ptrCast(&src));
        }

        pub fn delete(ev: *ElemVec) void {
            const f = decl("delete");
            f(@ptrCast(&ev));
        }

        pub fn elems(ev: *ElemVec) []const Elem {
            var out: []const Elem = undefined;
            out.ptr = @ptrCast(ev.data);
            out.len = ev.size;
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
pub const Message = Name;
pub const FrameVec = Vec(*lib.Frame, "frame");
