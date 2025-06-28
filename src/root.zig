//! Create a point cloud representation of a Torus
//! and determine an ascii representation of it
const std = @import("std");

// Re-export the term lib
pub const term = @import("term.zig");
// Re-export the donut lib
pub const donut = @import("donut.zig");

test "Tensor" {
    std.testing.refAllDecls(@This());
}
