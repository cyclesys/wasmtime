const c = @cImport(@cInclude("wasmtime/wasmtime.h"));

/// Representation of a instance in Wasmtime.
///
/// Instances are represented with a 64-bit identifying integer in Wasmtime.
/// They do not have any destructor associated with them. Instances cannot
/// interoperate between `Store` instances and if the wrong instance
/// is passed to the wrong store then it may trigger an assertion to abort the
/// process.
pub const Instance = extern struct {
    /// Internal identifier of what store this belongs to, never zero.
    store_id: u64,

    /// Internal index within the store.
    index: usize,
};
