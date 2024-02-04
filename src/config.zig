const c = @cImport(@cInclude("wasmtime.h"));
const err = @import("error.zig");

/// Different ways that Wasmtime can compile WebAssembly.
///
/// Defaults to `auto`.
pub const CompilationStrategy = enum {
    /// Automatically picks the compilation backend, currently always defaulting
    /// to Cranelift.
    auto,

    /// Indicates that Wasmtime will unconditionally use Cranelift to compile
    /// WebAssembly code.
    cranelift,
};

/// Different ways Wasmtime can optimize generated code.
///
/// Defaults to `speed`.
pub const OptimizationLevel = enum {
    /// Generated code will not be optimized at all.
    none,

    /// Generated code will be optimized purely for speed.
    speed,

    /// Generated code will be optimized, but some speed optimizations are
    /// disabled if they cause the generated code to be significantly larger.
    speed_and_size,
};

/// Different ways to profile JIT code.
///
/// Defaults to `none`.
pub const ProfilingStrategy = enum {
    /// No profiling is enabled at runtime.
    none,

    /// Linux's "jitdump" support in `perf` is enabled and when Wasmtime is run
    /// under `perf` necessary calls will be made to profile generated JIT code.
    jitdump,

    /// Support for VTune will be enabled and the VTune runtime will be informed,
    /// at runtime, about JIT code.
    ///
    /// Note that this isn't always enabled at build time.
    vtune,

    /// Linux's simple "perfmap" support in `perf` is enabled and when Wasmtime is
    /// run under `perf` necessary calls will be made to profile generated JIT
    /// code.
    perfmap,
};

/// Return type of linear memory implmentations of `getMemory`.
pub const LinearMemory = struct {
    /// The currently allocated bytes of this linear memory.
    bytes: []u8,
    /// The max number of bytes that can be allocated in this linear memory.
    capacity: usize,
};

pub const Config = opaque {
    /// Creates a new `Config` object.
    ///
    /// Destroy the object by calling `delete`.
    pub fn new() *Config {
        const cfg = c.wasm_config_new();
        return @ptrCast(cfg);
    }

    /// Deletes the `Config` object.
    pub fn delete(cfg: *Config) void {
        c.wasm_config_delete(@ptrCast(cfg));
    }

    /// Configures whether DWARF debug information is constructed at runtime
    /// to describe JIT code.
    ///
    /// This setting is `false` by default. When enabled it will attempt to inform
    /// native debuggers about DWARF debugging information for JIT code to more
    /// easily debug compiled WebAssembly via native debuggers. This can also
    /// sometimes improve the quality of output when profiling is enabled.
    pub fn debugInfo(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_debug_info_set(@ptrCast(cfg), enabled);
    }

    /// Whether or not fuel is enabled for generated code.
    ///
    /// This setting is `false` by default. When enabled it will enable fuel counting
    /// meaning that fuel will be consumed every time a wasm instruction is executed,
    /// and trap when reaching zero.
    pub fn consumeFuel(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_consume_fuel_set(@ptrCast(cfg), enabled);
    }

    /// Whether or not epoch-based interruption is enabled for generated code.
    ///
    /// This setting is `false` by default. When enabled wasm code will check the
    /// current epoch periodically and abort if the current epoch is beyond a
    /// store-configured limit.
    ///
    /// Note that when this setting is enabled all stores will immediately trap and
    /// need to have their epoch deadline otherwise configured with
    /// `Context.setEpochDeadline`.
    ///
    /// Note that the current epoch is engine-local and can be incremented with
    /// `Engine.incrementEpoch`.
    pub fn epochInterruption(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_epoch_interruption_set(@ptrCast(cfg), enabled);
    }

    /// Configures the maximum stack size, in bytes, that JIT code can use.
    ///
    /// This setting is 2MB by default. Configuring this setting will limit the
    /// amount of native stack space that JIT code can use while it is executing. If
    /// you're hitting stack overflow you can try making this setting larger, or if
    /// you'd like to limit wasm programs to less stack you can also configure this.
    ///
    /// Note that this setting is not interpreted with 100% precision. Additionally
    /// the amount of stack space that wasm takes is always relative to the first
    /// invocation of wasm on the stack, so recursive calls with host frames in the
    /// middle will all need to fit within this setting.
    pub fn maxWasmStack(cfg: *Config, size: usize) void {
        c.wasmtime_config_max_wasm_stack_set(@ptrCast(cfg), size);
    }

    /// Configures whether the WebAssembly threading proposal is enabled.
    ///
    /// This setting is `false` by default.
    ///
    /// Note that threads are largely unimplemented in Wasmtime at this time.
    pub fn wasmThreads(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_threads_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly reference types proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmReferenceTypes(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_reference_types_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly SIMD proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmSimd(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_simd_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly relaxed SIMD proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmRelaxedSimd(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_relaxed_simd_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly relaxed SIMD proposal is
    /// in deterministic mode.
    ///
    /// This setting is `false` by default.
    pub fn wasmRelaxedSimdDeterministic(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_relaxed_simd_deterministic_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly bulk memory proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmBulkMemory(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_bulk_memory_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly multi value proposal is
    /// enabled.
    ///
    /// This setting is `true` by default.
    pub fn wasmMultiValue(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_multi_value_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly multi-memory proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmMultiMemory(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_multi_memory_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether the WebAssembly memory64 proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmMemory64(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_memory64_set(@ptrCast(cfg), enabled);
    }

    /// Configures how JIT code will be compiled.
    ///
    /// This setting is `auto` by default.
    pub fn compilationStrategy(cfg: *Config, strategy: CompilationStrategy) void {
        c.wasmtime_config_strategy_set(@ptrCast(cfg), @intFromEnum(strategy));
    }

    /// Configure whether wasmtime should compile a module using multiple
    /// threads.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.parallel_compilation.
    pub fn parallelCompilation(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_parallel_compilation_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether Cranelift's debug verifier is enabled.
    ///
    /// This setting is `false` by default.
    ///
    /// When cranelift is used for compilation this enables expensive debug checks
    /// within Cranelift itself to verify it's correct.
    pub fn craneliftDebugVerifier(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_cranelift_debug_verifier_set(@ptrCast(cfg), enabled);
    }

    /// Configures whether Cranelift should perform a NaN-canonicalization
    /// pass.
    ///
    /// When Cranelift is used as a code generation backend this will configure
    /// it to replace NaNs with a single canonical value. This is useful for users
    /// requiring entirely deterministic WebAssembly computation.
    ///
    /// This is not required by the WebAssembly spec, so it is not enabled by
    /// default.
    ///
    /// The default value for this is `false`
    pub fn craneliftNanCanonicalization(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_cranelift_nan_canonicalization_set(@ptrCast(cfg), enabled);
    }

    /// Configures Cranelift's optimization level for JIT code.
    ///
    /// This setting is `speed` by default.
    pub fn optimizationLevel(cfg: *Config, level: OptimizationLevel) void {
        c.wasmtime_config_cranelift_opt_level_set(@ptrCast(cfg), @intFromEnum(level));
    }

    /// Configures the profiling strategy used for JIT code.
    ///
    /// This setting in #WASMTIME_PROFILING_STRATEGY_NONE by default.
    pub fn profilingStrategy(cfg: *Config, strategy: ProfilingStrategy) void {
        c.wasmtime_config_profiler_set(@ptrCast(cfg), @intFromEnum(strategy));
    }

    /// Configures the “static” style of memory to always be used.
    ///
    /// This setting is `false` by default.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_forced.
    pub fn staticMemoryForced(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_static_memory_forced_set(@ptrCast(cfg), enabled);
    }

    /// Configures the maximum size for memory to be considered "static"
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_maximum_size.
    pub fn staticMemoryMaxSize(cfg: *Config, size: u64) void {
        c.wasmtime_config_static_memory_maximum_size_set(@ptrCast(cfg), size);
    }

    /// Configures the guard region size for "static" memory.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_guard_size.
    pub fn staticMemoryGuardSize(cfg: *Config, size: u64) void {
        c.wasmtime_config_static_memory_guard_size_set(@ptrCast(cfg), size);
    }

    /// Configures the guard region size for "dynamic" memory.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.dynamic_memory_guard_size.
    pub fn dynamicMemoryGuardSize(cfg: *Config, size: u64) void {
        c.wasmtime_config_dynamic_memory_guard_size_set(@ptrCast(cfg), size);
    }

    /// Configures the size, in bytes, of the extra virtual memory space
    /// reserved after a “dynamic” memory for growing into.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.dynamic_memory_reserved_for_growth
    pub fn dynamicMemoryReservedForGrowth(cfg: *Config, size: u64) void {
        c.wasmtime_config_dynamic_memory_reserved_for_growth_set(@ptrCast(cfg), size);
    }

    /// Configures whether to generate native unwind information (e.g.
    /// .eh_frame on Linux).
    ///
    /// This option defaults to true.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.native_unwind_info
    pub fn nativeUnwindInfo(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_native_unwind_info(@ptrCast(cfg), enabled);
    }

    /// Enables Wasmtime's cache and loads configuration from the specified
    /// path.
    ///
    /// By default the Wasmtime compilation cache is disabled. The configuration path
    /// here can be `NULL` to use the default settings, and otherwise the argument
    /// here must be a file on the filesystem with TOML configuration -
    /// https://bytecodealliance.github.io/wasmtime/cli-cache.html.
    ///
    /// An error is returned if the cache configuration could not be loaded or if the
    /// cache could not be enabled.
    pub fn cacheConfigLoad(cfg: *Config, path: ?[:0]const u8) !void {
        try err.result(c.wasmtime_config_cache_config_load(@ptrCast(cfg), path));
    }

    /// Configures the target triple that this configuration will produce
    /// machine code for.
    ///
    /// This option defaults to the native host. Calling this method will
    /// additionally disable inference of the native features of the host (e.g.
    /// detection of SSE4.2 on x86_64 hosts). Native features can be reenabled with
    /// the `cranelift_flag_{set,enable}` properties.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.config
    pub fn target(cfg: *Config, triple: [:0]const u8) !void {
        try err.result(c.wasmtime_config_target_set(@ptrCast(cfg), triple));
    }

    /// Enables a target-specific flag in Cranelift.
    ///
    /// This can be used, for example, to enable SSE4.2 on x86_64 hosts. Settings can
    /// be explored with `wasmtime settings` on the CLI.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.cranelift_flag_enable
    pub fn craneliftFlagEnable(cfg: *Config, flag: [:0]const u8) void {
        c.wasmtime_config_cranelift_flag_enable(@ptrCast(cfg), flag);
    }

    /// Sets a target-specific flag in Cranelift to the specified value.
    ///
    /// This can be used, for example, to enable SSE4.2 on x86_64 hosts. Settings can
    /// be explored with `wasmtime settings` on the CLI.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.cranelift_flag_set
    pub fn craneliftFlagSet(cfg: *Config, key: [:0]const u8, value: [:0]const u8) void {
        c.wasmtime_config_cranelift_flag_set(@ptrCast(cfg), key, value);
    }

    /// \brief Configures whether, when on macOS, Mach ports are used for exception
    /// handling instead of traditional Unix-based signal handling.
    ///
    /// This option defaults to true, using Mach ports by default.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.macos_use_mach_ports
    pub fn macosUseMachPorts(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_macos_use_mach_ports_set(@ptrCast(cfg), enabled);
    }

    /// Sets a custom memory creator.
    ///
    /// Custom memory creators are used when creating host Memory objects or when
    /// creating instance linear memories for the on-demand instance allocation
    /// strategy.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.with_host_memory
    ///
    /// `impl` must be a pointer to a type that implements the following;
    /// ```zig
    /// // A representation of custom memory creator and methods for an instance of
    /// // LinearMemory.
    /// //
    /// // For more information see the Rust documentation at
    /// // https://docs.wasmtime.dev/api/wasmtime/trait.MemoryCreator.html
    /// //
    /// const MemoryCreatorImpl = struct {
    ///
    ///     // required
    ///     //
    ///     // A callback to create a user-defined LinearMemoryImpl from the specified parameters.
    ///     //
    ///     // This callback must be thread-safe.
    ///     //
    ///     // For more information about the parameters see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.MemoryCreator.html#tymethod.new_memory
    ///     fn newMemory(self: *MemoryCreator, min: usize, max: ?u64, is_64_bit: bool, reserved_size: usize, guard_size: usize) !*LinearMemoryImpl {
    ///     }
    ///
    ///     // optional
    ///     //
    ///     // Destructor for MemoryCreator
    ///     fn finalize(self: *MemoryCreator) void {
    ///     }
    /// }
    ///
    /// // A LinearMemoryImpl instance created with `MemoryCreator.newMemory`.
    /// //
    /// // For more information see the Rust documentation at
    /// // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html
    /// //
    /// const LinearMemoryImpl = struct {
    ///
    ///     // required
    ///     //
    ///     // Return the data from a LinearMemoryImpl instance.
    ///     //
    ///     // The size in bytes as well as the maximum number of bytes that can be
    ///     // allocated should be returned as well.
    ///     //
    ///     // For more information about see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html
    ///     //
    ///     // Also see LinearMemory for more info.
    ///     fn getMemory(self: *LinearMemoryImpl) LinearMemory {
    ///     }
    ///
    ///     // required
    ///     //
    ///     // Grow the memory to the `new_size` in bytes.
    ///     //
    ///     // For more information about the parameters see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html#tymethod.grow_to
    ///     fn growMemory(self: *LinearMemoryImpl, new_size: usize) !void {
    ///     }
    ///
    ///     // optional
    ///     //
    ///     // Destructor for LinearMemoryImpl
    ///     fn finalize(self: *LinearMemoryImpl) void {
    ///     }
    /// };
    /// ```
    pub fn memoryCreator(cfg: *Config, impl: anytype) void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Pointer.child;
        const ImplExtern = MemoryCreatorExtern(Impl);
        var creator = c.wasmtime_memory_creator_t{
            .env = @ptrCast(impl),
            .new_memory = ImplExtern.newMemory,
            .finalizer = if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
        };
        c.wasmtime_config_host_memory_creator_set(@ptrCast(cfg), &creator);
    }

    /// Configures whether copy-on-write memory-mapped data is used to
    /// initialize a linear memory.
    ///
    /// Initializing linear memory via a copy-on-write mapping can drastically
    /// improve instantiation costs of a WebAssembly module because copying memory is
    /// deferred. Additionally if a page of memory is only ever read from WebAssembly
    /// and never written too then the same underlying page of data will be reused
    /// between all instantiations of a module meaning that if a module is
    /// instantiated many times this can lower the overall memory required needed to
    /// run that module.
    ///
    /// This option defaults to true.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.memory_init_cow
    pub fn memoryInitCow(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_memory_init_cow_set(@ptrCast(cfg), enabled);
    }

    /// Whether or not to enable support for asynchronous functions in
    /// Wasmtime.
    ///
    /// When enabled, the config can optionally define host functions with async.
    /// Instances created and functions called with this Config must be called
    /// through their asynchronous APIs, however. For example using `Func.call`
    /// will panic when used with this config.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.async_support
    pub fn asyncSupport(cfg: *Config, enabled: bool) void {
        c.wasmtime_config_async_support_set(@ptrCast(cfg), enabled);
    }

    /// Configures the size of the stacks used for asynchronous execution.
    ///
    /// This setting configures the size of the stacks that are allocated for
    /// asynchronous execution.
    ///
    /// The value cannot be less than `Config.maxWasmStack`.
    ///
    /// The amount of stack space guaranteed for host functions is `Config.asyncStackSize` -
    /// `Config.maxWasmStack`, so take care not to set these two values close to one
    /// another; doing so may cause host functions to overflow the stack and abort
    /// the process.
    ///
    /// By default this option is 2 MiB.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.async_stack_size
    pub fn asyncStackSize(cfg: *Config, size: u64) void {
        c.wasmtime_config_async_stack_size_set(@ptrCast(cfg), size);
    }

    /// Sets a custom stack creator.
    ///
    /// Custom memory creators are used when creating creating async instance stacks
    /// for the on-demand instance allocation strategy.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.with_host_stack
    ///
    /// `impl` must be a pointer to a type that implements the following;
    /// ```zig
    /// /// A representation of custom stack creator.
    /// ///
    /// /// For more information see the Rust documentation at
    /// /// https://docs.wasmtime.dev/api/wasmtime/trait.StackCreator.html
    /// const StackCreatorImpl = struct {
    ///     /// Required
    ///     ///
    ///     /// A function to create a new stack memory instance from the specified parameters.
    ///     ///
    ///     /// This callback must be thread-safe.
    ///     pub fn newStack(impl: *StackCreatorImpl, size: usize) *StackMemoryImpl {
    ///     }
    ///
    ///     /// Optional
    ///     ///
    ///     /// Destructor for the user-defined `StackCreatorImpl`.
    ///     pub fn finalize(impl: *StackCreatorImpl) void {
    ///     }
    /// };
    ///
    /// /// A Stack instance created by a user-defined `StackCreatorImpl.newStack`.
    /// ///
    /// /// For more information see the Rust documentation at
    /// /// https://docs.wasmtime.dev/api/wasmtime/trait.StackMemory.html
    /// const StackMemoryImpl = struct {
    ///     /// Required
    ///     ///
    ///     /// A callback to get the top of the stack address and the length of the stack,
    ///     /// excluding guard pages.
    ///     ///
    ///     /// For more information about the parameters see the Rust documentation at
    ///     /// https://docs.wasmtime.dev/api/wasmtime/trait.StackMemory.html
    ///     pub fn getMemory(impl: *StackMemoryImpl) []u8 {
    ///     }
    ///
    ///     /// Optional
    ///     ///
    ///     /// Destructor for the user-defined `StackCreatorImpl`.
    ///     pub fn finalize(impl: *StackMemoryImpl) void {
    ///     }
    /// };
    /// ```
    pub fn stackCreator(cfg: *Config, impl: anytype) void {
        const ImplPtr = @TypeOf(impl);
        const Impl = @typeInfo(ImplPtr).Pointer.child;
        const ImplExtern = StackCreatorExtern(Impl);
        var creator = c.wasmtime_stack_creator_t{
            .env = @ptrCast(impl),
            .new_stack = ImplExtern.newStack,
            .finalizer = if (@hasDecl(Impl, "finalize")) ImplExtern.finalize else null,
        };
        c.wasmtime_config_host_stack_creator_set(@ptrCast(cfg), &creator);
    }
};

fn MemoryCreatorExtern(comptime Impl: type) type {
    return struct {
        fn newMemory(
            ptr: ?*anyopaque,
            ty: *const c.wasm_memorytype_t,
            _: usize, // `min` is discarded because we get the value by calling `c.wasmtime_memorytype_minimum` instead.
            _: usize, // `max` is discarded because we get the value by calling `c.wasmtime_memorytype_maximum` instead.
            reserved_size: usize,
            guard_size: usize,
            mem_ret: *c.wasmtime_linear_memory_t,
        ) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(ptr.?);

            const min: usize = @intCast(c.wasmtime_memorytype_minimum(ty));
            const max: ?usize = blk: {
                var max: u64 = undefined;
                if (c.wasmtime_memory_maximum(ty, &max)) {
                    break :blk @intCast(max);
                }
                break :blk null;
            };
            const is_64_bit = c.wasmtime_memorytype_is64(ty);

            const new_mem = Impl.newMemory(impl, min, max, is_64_bit, reserved_size, guard_size) catch |e| {
                return err.new(@typeName(Impl) ++ ".newMemory error: " ++ @tagName(e));
            };

            const MemImplPtr = @TypeOf(new_mem);
            const MemImpl = @typeInfo(MemImplPtr).Pointer.child;
            const MemImplExtern = LinearMemoryExtern(MemImpl);
            mem_ret.* = c.wasmtime_linear_memory_t{
                .env = @ptrCast(new_mem),
                .get_memory = MemImplExtern.getMemory,
                .growMemory = MemImplExtern.growMemory,
                .finalize = if (@hasDecl(MemImpl, "finalize")) MemImplExtern.finalize else null,
            };

            return null;
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}

fn LinearMemoryExtern(comptime Impl: type) type {
    return struct {
        fn getMemory(ptr: ?*anyopaque, size: *usize, max_size: *usize) callconv(.C) [*]u8 {
            const impl: *Impl = @ptrCast(ptr.?);
            const mem: LinearMemory = Impl.getMemory(impl);
            size.* = mem.bytes.len;
            max_size.* = mem.capacity;
            return mem.bytes.ptr;
        }

        fn growMemory(ptr: ?*anyopaque, new_size: usize) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.growMemory(impl, new_size) catch |e| {
                return err.new(@typeName(Impl) ++ ".growMemory error: " ++ @tagName(e));
            };
            return null;
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}

fn StackCreatorExtern(comptime Impl: type) type {
    return struct {
        fn newStack(ptr: ?*anyopaque, size: usize, stack_ret: *c.wasmtime_stack_memory_t) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(ptr.?);
            const stack_mem = Impl.newStack(impl, size) catch |e| {
                return err.new(@typeName(Impl) ++ ".newStack error: " ++ @tagName(e));
            };

            const StackImplPtr = @TypeOf(stack_mem);
            const StackImpl = @typeInfo(StackImplPtr).Pointer.child;
            const StackImplExtern = StackMemoryExtern(StackImpl);
            stack_ret.* = c.wasmtime_stack_memory_t{
                .env = @ptrCast(stack_mem),
                .get_stack_memory = StackImplExtern.getMemory,
                .finalizer = if (@hasDecl(StackImpl, "finalize")) StackImplExtern.finalize else null,
            };
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}

fn StackMemoryExtern(comptime Impl: type) type {
    return struct {
        fn getMemory(ptr: ?*anyopaque, out_len: usize) callconv(.C) [*]u8 {
            const impl: *Impl = @ptrCast(ptr.?);
            const mem: []u8 = Impl.getMemory(impl);
            out_len.* = mem.len;
            return mem.ptr;
        }

        fn finalize(ptr: ?*anyopaque) callconv(.C) void {
            const impl: *Impl = @ptrCast(ptr.?);
            Impl.finalize(impl);
        }
    };
}
