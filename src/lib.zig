pub usingnamespace @import("config.zig");
pub usingnamespace @import("instance.zig");
pub usingnamespace @import("ref.zig");
pub usingnamespace @import("trap.zig");
pub usingnamespace @import("vec.zig");

const err = @import("error.zig");
pub const errorMessage = err.message;
pub const errorStatus = err.status;
pub const errorTrace = err.trace;
