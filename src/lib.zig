pub usingnamespace @import("config.zig");
pub usingnamespace @import("engine.zig");
pub usingnamespace @import("extern.zig");
pub usingnamespace @import("global.zig");
pub usingnamespace @import("instance.zig");
pub usingnamespace @import("linker.zig");
pub usingnamespace @import("memory.zig");
pub usingnamespace @import("module.zig");
pub usingnamespace @import("ref.zig");
pub usingnamespace @import("store.zig");
pub usingnamespace @import("table.zig");
pub usingnamespace @import("trap.zig");
pub usingnamespace @import("val.zig");
pub usingnamespace @import("wasi.zig");

const e = @import("error.zig");
pub const Error = e.Error;
pub const err = e.consumeErr;

const f = @import("func.zig");
pub const FuncType = f.FuncType;
pub const Caller = f.Caller;
pub const FuncResult = f.FuncResult;
pub const UncheckedFuncResult = f.UncheckedFuncResult;
pub const Future = f.Future;
pub const AsyncErrorTrapReturn = f.AsyncErrorTrapReturn;
pub const Func = f.Func;

const vec = @import("vec.zig");
/// A list of bytes
pub const ByteVec = vec.Vec(u8, "byte");

/// Alias for `ByteVec`.
pub const Name = ByteVec;

/// Alias for `Name` i.e. a `ByteVec`.
pub const Message = Name;
