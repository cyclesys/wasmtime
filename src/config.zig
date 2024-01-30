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

pub const LinearMemoryBytes = struct {
    bytes: []u8,
    capacity: usize,
};

pub const Config = opaque {
    /// Creates a new `Config` object.
    ///
    /// Destroy the object by calling `delete`.
    pub fn new() *Config {
        const config = c.wasm_config_new();
        return @ptrCast(config);
    }

    /// Destroys the `Config` object.
    pub fn delete(config: *Config) void {
        c.wasm_config_delete(@ptrCast(config));
    }

    /// Configures whether DWARF debug information is constructed at runtime
    /// to describe JIT code.
    ///
    /// This setting is `false` by default. When enabled it will attempt to inform
    /// native debuggers about DWARF debugging information for JIT code to more
    /// easily debug compiled WebAssembly via native debuggers. This can also
    /// sometimes improve the quality of output when profiling is enabled.
    pub fn debugInfo(config: *Config, enabled: bool) void {
        c.wasmtime_config_debug_info_set(@ptrCast(config), enabled);
    }

    /// Whether or not fuel is enabled for generated code.
    ///
    /// This setting is `false` by default. When enabled it will enable fuel counting
    /// meaning that fuel will be consumed every time a wasm instruction is executed,
    /// and trap when reaching zero.
    pub fn consumeFuel(config: *Config, enabled: bool) void {
        c.wasmtime_config_consume_fuel_set(@ptrCast(config), enabled);
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
    pub fn epochInterruption(config: *Config, enabled: bool) void {
        c.wasmtime_config_epoch_interruption_set(@ptrCast(config), enabled);
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
    pub fn maxWasmStack(config: *Config, size: usize) void {
        c.wasmtime_config_max_wasm_stack_set(@ptrCast(config), size);
    }

    /// Configures whether the WebAssembly threading proposal is enabled.
    ///
    /// This setting is `false` by default.
    ///
    /// Note that threads are largely unimplemented in Wasmtime at this time.
    pub fn wasmThreads(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_threads_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly reference types proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmReferenceTypes(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_reference_types_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly SIMD proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmSimd(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_simd_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly relaxed SIMD proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmRelaxedSimd(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_relaxed_simd_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly relaxed SIMD proposal is
    /// in deterministic mode.
    ///
    /// This setting is `false` by default.
    pub fn wasmRelaxedSimdDeterministic(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_relaxed_simd_deterministic_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly bulk memory proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmBulkMemory(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_bulk_memory_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly multi value proposal is
    /// enabled.
    ///
    /// This setting is `true` by default.
    pub fn wasmMultiValue(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_multi_value_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly multi-memory proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmMultiMemory(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_multi_memory_set(@ptrCast(config), enabled);
    }

    /// Configures whether the WebAssembly memory64 proposal is
    /// enabled.
    ///
    /// This setting is `false` by default.
    pub fn wasmMemory64(config: *Config, enabled: bool) void {
        c.wasmtime_config_wasm_memory64_set(@ptrCast(config), enabled);
    }

    /// Configures how JIT code will be compiled.
    ///
    /// This setting is `auto` by default.
    pub fn compilationStrategy(config: *Config, strategy: CompilationStrategy) void {
        c.wasmtime_config_strategy_set(@ptrCast(config), @intFromEnum(strategy));
    }

    /// Configure whether wasmtime should compile a module using multiple
    /// threads.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.parallel_compilation.
    pub fn parallelCompilation(config: *Config, enabled: bool) void {
        c.wasmtime_config_parallel_compilation_set(@ptrCast(config), enabled);
    }

    /// Configures whether Cranelift's debug verifier is enabled.
    ///
    /// This setting is `false` by default.
    ///
    /// When cranelift is used for compilation this enables expensive debug checks
    /// within Cranelift itself to verify it's correct.
    pub fn craneliftDebugVerifier(config: *Config, enabled: bool) void {
        c.wasmtime_config_cranelift_debug_verifier_set(@ptrCast(config), enabled);
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
    pub fn craneliftNanCanonicalization(config: *Config, enabled: bool) void {
        c.wasmtime_config_cranelift_nan_canonicalization_set(@ptrCast(config), enabled);
    }

    /// Configures Cranelift's optimization level for JIT code.
    ///
    /// This setting is `speed` by default.
    pub fn optimizationLevel(config: *Config, level: OptimizationLevel) void {
        c.wasmtime_config_cranelift_opt_level_set(@ptrCast(config), @intFromEnum(level));
    }

    /// Configures the profiling strategy used for JIT code.
    ///
    /// This setting in #WASMTIME_PROFILING_STRATEGY_NONE by default.
    pub fn profilingStrategy(config: *Config, strategy: ProfilingStrategy) void {
        c.wasmtime_config_profiler_set(@ptrCast(config), @intFromEnum(strategy));
    }

    /// Configures the “static” style of memory to always be used.
    ///
    /// This setting is `false` by default.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_forced.
    pub fn staticMemoryForced(config: *Config, enabled: bool) void {
        c.wasmtime_config_static_memory_forced_set(@ptrCast(config), enabled);
    }

    /// Configures the maximum size for memory to be considered "static"
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_maximum_size.
    pub fn staticMemoryMaxSize(config: *Config, size: u64) void {
        c.wasmtime_config_static_memory_maximum_size_set(@ptrCast(config), size);
    }

    /// Configures the guard region size for "static" memory.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.static_memory_guard_size.
    pub fn staticMemoryGuardSize(config: *Config, size: u64) void {
        c.wasmtime_config_static_memory_guard_size_set(@ptrCast(config), size);
    }

    /// Configures the guard region size for "dynamic" memory.
    ///
    /// For more information see the Rust documentation at
    /// https://bytecodealliance.github.io/wasmtime/api/wasmtime/struct.Config.html#method.dynamic_memory_guard_size.
    pub fn dynamicMemoryGuardSize(config: *Config, size: u64) void {
        c.wasmtime_config_dynamic_memory_guard_size_set(@ptrCast(config), size);
    }

    /// Configures the size, in bytes, of the extra virtual memory space
    /// reserved after a “dynamic” memory for growing into.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.dynamic_memory_reserved_for_growth
    pub fn dynamicMemoryReservedForGrowth(config: *Config, size: u64) void {
        c.wasmtime_config_dynamic_memory_reserved_for_growth_set(@ptrCast(config), size);
    }

    /// Configures whether to generate native unwind information (e.g.
    /// .eh_frame on Linux).
    ///
    /// This option defaults to true.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.native_unwind_info
    pub fn nativeUnwindInfo(config: *Config, enabled: bool) void {
        c.wasmtime_config_native_unwind_info(@ptrCast(config), enabled);
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
    pub fn cacheConfigLoad(config: *Config, path: ?[:0]const u8) !void {
        try err.result(c.wasmtime_config_cache_config_load(@ptrCast(config), path));
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
    pub fn target(config: *Config, triple: [:0]const u8) !void {
        try err.result(c.wasmtime_config_target_set(@ptrCast(config), triple));
    }

    /// Enables a target-specific flag in Cranelift.
    ///
    /// This can be used, for example, to enable SSE4.2 on x86_64 hosts. Settings can
    /// be explored with `wasmtime settings` on the CLI.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.cranelift_flag_enable
    pub fn craneliftFlagEnable(config: *Config, flag: [:0]const u8) void {
        c.wasmtime_config_cranelift_flag_enable(@ptrCast(config), flag);
    }

    /// Sets a target-specific flag in Cranelift to the specified value.
    ///
    /// This can be used, for example, to enable SSE4.2 on x86_64 hosts. Settings can
    /// be explored with `wasmtime settings` on the CLI.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.cranelift_flag_set
    pub fn craneliftFlagSet(config: *Config, key: [:0]const u8, value: [:0]const u8) void {
        c.wasmtime_config_cranelift_flag_set(@ptrCast(config), key, value);
    }

    /// \brief Configures whether, when on macOS, Mach ports are used for exception
    /// handling instead of traditional Unix-based signal handling.
    ///
    /// This option defaults to true, using Mach ports by default.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.macos_use_mach_ports
    pub fn macosUseMachPorts(config: *Config, enabled: bool) void {
        c.wasmtime_config_macos_use_mach_ports_set(@ptrCast(config), enabled);
    }

    /// Sets a custom memory creator.
    ///
    /// Custom memory creators are used when creating host Memory objects or when
    /// creating instance linear memories for the on-demand instance allocation
    /// strategy.
    ///
    /// The config does **not** take ownership of the `creator`.
    ///
    /// For more information see the Rust documentation at
    /// https://docs.wasmtime.dev/api/wasmtime/struct.Config.html#method.with_host_memory
    ///
    /// `creator` must be a pointer to a type that implements the following;
    ///
    /// ```zig
    /// // A representation of custom memory creator and methods for an instance of
    /// // LinearMemory.
    /// //
    /// // For more information see the Rust documentation at
    /// // https://docs.wasmtime.dev/api/wasmtime/trait.MemoryCreator.html
    /// //
    /// // can be a struct, enum, union, etc.
    /// const MemoryCreator = struct {
    ///
    ///     // required
    ///     //
    ///     // A callback to create a new LinearMemory from the specified parameters.
    ///     //
    ///     // This callback must be thread-safe.
    ///     //
    ///     // For more information about the parameters see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.MemoryCreator.html#tymethod.new_memory
    ///     fn newMemory(self: *MemoryCreator, min: usize, max: ?u64, is_64_bit: bool, reserved_size: usize, guard_size: usize) !*LinearMemory {
    ///     }
    ///
    ///     // optional
    ///     //
    ///     // Destructor for MemoryCreator
    ///     fn finalize(self: *MemoryCreator) void {
    ///     }
    /// }
    ///
    /// // A LinearMemory instance created with `MemoryCreator.newMemory`.
    /// //
    /// // For more information see the Rust documentation at
    /// // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html
    /// //
    /// // can be a struct, enum, union, etc.
    /// const LinearMemory = struct {
    ///
    ///     // required
    ///     //
    ///     // Return the data from a LinearMemory instance.
    ///     //
    ///     // The size in bytes as well as the maximum number of bytes that can be
    ///     // allocated should be returned as well.
    ///     //
    ///     // For more information about see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html
    ///     //
    ///     // Also see LinearMemoryBytes for more info.
    ///     fn getMemory(self: *LinearMemory) LinearMemoryBytes {
    ///     }
    ///
    ///     // required
    ///     //
    ///     // Grow the memory to the `new_size` in bytes.
    ///     //
    ///     // For more information about the parameters see the Rust documentation at
    ///     // https://docs.wasmtime.dev/api/wasmtime/trait.LinearMemory.html#tymethod.grow_to
    ///     fn growMemory(self: *LinearMemory, new_size: usize) !void {
    ///     }
    ///
    ///     // optional
    ///     //
    ///     // Destructor for LinearMemory
    ///     fn finalize(self: *LinearMemory) void {
    ///     }
    /// };
    /// ```
    pub fn memoryCreator(config: *Config, creator: anytype) void {
        const ImplPtr = @TypeOf(creator);
        const Impl = @typeInfo(ImplPtr).Ptr.child;

        const Creator = MemoryCreator(Impl);
        var callback = Creator.create(creator);
        c.wasmtime_config_host_memory_creator_set(@ptrCast(config), &callback);
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
    pub fn memoryInitCow(config: *Config, enabled: bool) void {
        c.wasmtime_config_memory_init_cow_set(@ptrCast(config), enabled);
    }
};

fn MemoryCreator(comptime Impl: type) type {
    return struct {
        fn create(impl: *Impl) MemoryCreatorExtern {
            return MemoryCreatorExtern{
                .ptr = @ptrCast(impl),
                .newMemory = newMemory,
                .finalize = if (@hasDecl(Impl, "finalize")) finalize else null,
            };
        }

        fn newMemory(
            ptr: *anyopaque,
            ty: *const c.wasm_memorytype_t,
            _: usize, // `min` is discarded because we get the value by calling `c.wasmtime_memorytype_minimum` instead.
            _: usize, // `max` is discarded because we get the value by calling `c.wasmtime_memorytype_maximum` instead.
            reserved_size: usize,
            guard_size: usize,
            mem_ret: *c.wasmtime_linear_memory_t,
        ) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(ptr);

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
            const MemImpl = @typeInfo(MemImplPtr).Ptr.child;
            const Memory = LinearMemory(MemImpl);
            mem_ret.* = Memory.create(new_mem);

            return null;
        }

        fn finalize(ptr: *anyopaque) callconv(.C) void {
            if (!@hasDecl(Impl, "finalize")) {
                @compileError("`MemoryCreator.finalize` was evaluated but `Impl` does not have a `finalize` decl");
            }
            const impl: *Impl = @ptrCast(ptr);
            Impl.finalize(impl);
        }
    };
}

fn LinearMemory(comptime Impl: type) type {
    return struct {
        fn create(impl: *Impl) LinearMemoryExtern {
            return LinearMemoryExtern{
                .ptr = @ptrCast(impl),
                .getMemory = getMemory,
                .growMemory = growMemory,
                .finalize = if (@hasDecl(Impl, "finalize")) finalize else null,
            };
        }

        fn getMemory(ptr: *anyopaque, size: *usize, max_size: *usize) callconv(.C) [*]u8 {
            const impl: *Impl = @ptrCast(ptr);
            const result = Impl.getMemory(impl);
            size.* = result.bytes.len;
            max_size.* = result.capacity;
            return result.bytes.ptr;
        }

        fn growMemory(ptr: *anyopaque, new_size: usize) callconv(.C) ?*c.wasmtime_error_t {
            const impl: *Impl = @ptrCast(ptr);
            Impl.growMemory(impl, new_size) catch |e| {
                return err.new(@typeName(Impl) ++ ".growMemory error: " ++ @tagName(e));
            };
            return null;
        }

        fn finalize(ptr: *anyopaque) callconv(.C) void {
            if (!@hasDecl(Impl, "finalize")) {
                @compileError("`LinearMemory.finalize` was evaluated but `Impl` does not have a `finalize` decl");
            }
            const impl: *Impl = @ptrCast(ptr);
            Impl.finalize(impl);
        }
    };
}

const MemoryCreatorExtern = extern struct {
    ptr: *anyopaque,
    newMemory: *const fn (ptr: *anyopaque) callconv(.C) ?*c.wasmtime_error_t,
    finalize: ?*const fn (ptr: *anyopaque) callconv(.C) void,
};

const LinearMemoryExtern = extern struct {
    ptr: *anyopaque,
    getMemory: *const fn (ptr: *anyopaque, size: *usize, max_size: *usize) callconv(.C) [*]u8,
    growMemory: *const fn (ptr: *anyopaque, new_size: usize) callconv(.C) ?*c.wastime_error_t,
    finalizer: ?*const fn (ptr: *anyopaque) callconv(.C) void,
};
