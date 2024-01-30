pub usingnamespace @import("config.zig");
pub usingnamespace @import("engine.zig");
pub usingnamespace @import("instance.zig");
pub const Ref = @import("ref.zig").Ref;
pub usingnamespace @import("store.zig");
pub usingnamespace @import("trap.zig");
pub usingnamespace @import("vec.zig");
pub usingnamespace @import("wasi.zig");

const err = @import("error.zig");
pub const errorMessage = err.message;
pub const errorStatus = err.status;
pub const errorTrace = err.trace;

pub const Finalizer = fn (*anyopaque) void;
