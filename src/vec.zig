const c = @cImport(@cInclude("wasmtime.h"));
const lib = @import("lib.zig");

/// A list of elements.
pub fn Vec(comptime Elem: type, comptime elem_name: []const u8) type {
    return extern struct {
        /// the length of this vector
        size: usize,
        /// the pointer to the base of this vector
        data: [*]Elem,

        const ElemVec = @This();

        /// Initializes the vector with the specified capacity.
        ///
        /// This function will initialize the provided vector with capacity to hold the
        /// specified number of elements.
        pub fn newUninitialized(size: usize) ElemVec {
            const f = decl("new_uninitialized");
            var ev: ElemVec = undefined;
            f(&ev, size);
            return ev;
        }

        /// Intializes an empty vector.
        pub fn newEmpty() ElemVec {
            const f = decl("new_empty");
            var ev: ElemVec = undefined;
            f(&ev);
            return ev;
        }

        /// Copies the specified elements into a new vector.
        pub fn new(init_elems: []const Elem) ElemVec {
            const f = decl("new");
            var ev: ElemVec = undefined;
            f(&ev, init_elems.len, @ptrCast(init_elems.ptr));
            return ev;
        }

        /// Copies the specified elements into a new vector with the sentinel value included.
        pub fn newSentinel(comptime s: Elem, init_elems: [:s]const Elem) ElemVec {
            const f = decl("new");
            var ev: ElemVec = undefined;
            f(&ev, init_elems.len + 1, @ptrCast(init_elems.ptr));
            return ev;
        }

        //// Deletes the vector.
        pub fn delete(ev: *ElemVec) void {
            const f = decl("delete");
            f(@ptrCast(&ev));
        }

        /// Copies another vectors elements into this one.
        ///
        /// The vector that is being written to should not be previously
        /// intialized.
        pub fn copy(v: *ElemVec, src: ElemVec) void {
            const f = decl("copy");
            f(@ptrCast(v), @ptrCast(&src));
        }

        /// The elements of the vector.
        pub fn elems(ev: ElemVec) []Elem {
            var out: []Elem = undefined;
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
