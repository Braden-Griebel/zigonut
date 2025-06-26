//! Module for working with the Torus
const std = @import("std");
const math = std.math;

//! A single point
pub const Point = struct { x: f64, y: f64, z: f64 };

//! A struct representing a Torus
pub const Torus = struct {
    points: std.MultiArrayList(Point),
    allocator: std.mem.Allocator,
};
