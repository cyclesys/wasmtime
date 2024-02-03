const UserData = @This();

ptr: ?*anyopaque,
finalizer: ?*const fn (*anyopaque) void,

pub fn create(data: anytype) UserData {
    const Data = @TypeOf(data);
    if (@typeInfo(Data) == .Ptr) {
        const DataExtern = FinalizerExtern(Data);
        return UserData{
            .ptr = @ptrCast(data),
            .finalizer = if (@hasDecl(Data, "finalize")) DataExtern.finalize else null,
        };
    }

    if (@typeInfo(Data) == .Optional) {
        const ImplPtr = @typeInfo(Data).Optional.child;
        const Impl = @typeInfo(ImplPtr).Ptr.child;
        const ImplExtern = FinalizerExtern(Impl);
        if (data) |ptr| {
            return UserData{
                .ptr = ptr,
                .finalizer = if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
            };
        }
    }

    if (@typeInfo(Data) != .Null) {
        @compileError("UserData `data` can only be a null, a ptr, or an optional ptr value.");
    }

    return UserData{
        .ptr = null,
        .finalizer = null,
    };
}

fn FinalizerExtern(comptime Impl: type) type {
    return struct {
        fn finalize(ptr: *anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr);
            Impl.finalize(impl);
        }
    };
}
