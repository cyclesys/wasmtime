const c = @cImport(@cInclude("wasmtime/wasmtime.h"));
const lib = @import("lib.zig");

/// Configuration object for the WASI API.
pub const WasiConfig = opaque {
    /// Creates a new empty configuration object.
    ///
    /// The caller is expected to deallocate the returned configuration
    pub fn new() *WasiConfig {
        return @ptrCast(c.wasi_config_new());
    }

    /// Sets the argv list for this configuration object.
    ///
    /// By default WASI programs have an empty argv list, but this can be used to
    /// explicitly specify what the argv list for the program is.
    ///
    /// The arguments are copied into the `config` object as part of this function
    /// call, so `argv` only needs to stay alive for this function call.
    pub fn setArgv(cfg: *WasiConfig, argv: []const [:0]const u8) void {
        c.wasi_config_set_argv(@ptrCast(cfg), @intCast(argv.len), @ptrCast(argv.ptr));
    }

    /// Indicates that the argv list should be inherited from this process's
    /// argv list.
    pub fn inheritArgv(cfg: *WasiConfig) void {
        c.wasi_config_inherit_argv(@ptrCast(cfg));
    }

    /// Sets the list of environment variables available to the WASI instance.
    ///
    /// By default WASI programs have a blank environment, but this can be used to
    /// define some environment variables for them.
    ///
    /// It is required that the `names` and `values` both have the same length.
    ///
    /// The env vars are copied into the `config` object as part of this function
    /// call, so `names` and `values` only need to stay alive for this function call.
    pub fn setEnv(cfg: *WasiConfig, names: []const [:0]const u8, values: []const [:0]const u8) void {
        if (names.len != values.len) @panic("`names` and `values` must have the same length");
        c.wasi_config_set_env(@ptrCast(cfg), @intCast(names.len), @ptrCast(names.ptr), @ptrCast(values.ptr));
    }

    /// Indicates that the entire environment of the calling process should be
    /// inherited by this WASI configuration.
    pub fn inheritEnv(cfg: *WasiConfig) void {
        c.wasi_config_inherit_env(@ptrCast(cfg));
    }

    /// Configures standard input to be taken from the specified file.
    ///
    /// By default WASI programs have no stdin, but this configures the specified
    /// file to be used as stdin for this configuration.
    ///
    /// If the stdin location does not exist or it cannot be opened for reading then
    /// `false` is returned. Otherwise `true` is returned.
    pub fn setStdinFile(cfg: *WasiConfig, path: [:0]const u8) bool {
        return c.wasi_config_set_stdin_file(@ptrCast(cfg), @ptrCast(path.ptr));
    }

    /// Configures standard input to be taken from the specified `bytes`.
    ///
    /// By default WASI programs have no stdin, but this configures the specified
    /// bytes to be used as stdin for this configuration.
    pub fn setStdinBytes(cfg: *WasiConfig, bytes: []const u8) void {
        var byte_vec = lib.ByteVec.new(bytes);
        c.wasi_config_set_stdin_bytes(@ptrCast(cfg), @ptrCast(&byte_vec));
    }

    /// Configures this process's own stdin stream to be used as stdin for
    /// this WASI configuration.
    pub fn inheritStdin(cfg: *WasiConfig) void {
        c.wasi_config_inherit_stdin(@ptrCast(cfg));
    }

    /// Configures standard output to be written to the specified file.
    ///
    /// By default WASI programs have no stdout, but this configures the specified
    /// file to be used as stdout.
    ///
    /// If the stdout location could not be opened for writing then `false` is
    /// returned. Otherwise `true` is returned.
    pub fn setStdoutFile(cfg: *WasiConfig, path: [:0]const u8) bool {
        return c.wasi_config_set_stdout_file(@ptrCast(cfg), @ptrCast(path.ptr));
    }

    /// Configures this process's own stdout stream to be used as stdout for
    /// this WASI configuration.
    pub fn inheritStdout(cfg: *WasiConfig) void {
        c.wasi_config_inherit_stdout(@ptrCast(cfg));
    }

    /// Configures standard error to be written to the specified file.
    ///
    /// By default WASI programs have no stderr, but this configures the specified
    /// file to be used as stderr.
    ///
    /// If the stderr location could not be opened for writing then `false` is
    /// returned. Otherwise `true` is returned.
    pub fn setStderrFile(cfg: *WasiConfig, path: [:0]const u8) bool {
        return c.wasi_config_set_stderr_file(@ptrCast(cfg), @ptrCast(path.ptr));
    }

    /// Configures this process's own stderr stream to be used as stderr for
    /// this WASI configuration.
    pub fn inheritStderr(cfg: *WasiConfig) void {
        c.wasi_config_inherit_stderr(@ptrCast(cfg));
    }

    /// Configures a "preopened directory" to be available to WASI APIs.
    ///
    /// By default WASI programs do not have access to anything on the filesystem.
    /// This API can be used to grant WASI programs access to a directory on the
    /// filesystem, but only that directory (its whole contents but nothing above
    /// it).
    ///
    /// The `path` argument here is a path name on the host filesystem, and
    /// `guest_path` is the name by which it will be known in wasm.
    pub fn preopenDir(cfg: *WasiConfig, path: [:0]const u8, guest_path: [:0]const u8) bool {
        return c.wasi_config_preopen_dir(@ptrCast(cfg), @ptrCast(path.ptr), @ptrCast(guest_path.ptr));
    }

    /// Configures a "preopened" listen socket to be available to WASI APIs.
    ///
    /// By default WASI programs do not have access to open up network sockets on
    /// the host. This API can be used to grant WASI programs access to a network
    /// socket file descriptor on the host.
    ///
    /// The `fd_num` argument is the number of the file descriptor by which it will be
    /// known in WASM and the `host_port` is the IP address and port (e.g.
    /// "127.0.0.1:8080") requested to listen on.
    pub fn preopenSocket(cfg: *WasiConfig, fd_num: u32, host_port: [:0]const u8) bool {
        return c.wasi_config_preopen_socket(@ptrCast(cfg), fd_num, @ptrCast(host_port.ptr));
    }
};
