//! Module for working with the Torus
const std = @import("std");
const math = std.math;
const testing = std.testing;
/// A single point
pub const Point = struct { x: f64, y: f64, z: f64 };

/// A struct representing a Torus
pub const Torus = struct {
    /// Array of points making up the torus
    points: std.MultiArrayList(Point),
    /// Allocator used for allocating the points array, and the
    /// window array recording the z positions for drawing
    allocator: std.mem.Allocator,
    /// The distance from the axis of revolution
    major_radius: f64,
    /// The radius of the circle which is revolved to
    /// create the torus
    minor_radius: f64,
    /// The number of cells along one side of the window
    /// i.e. the number of rows and columns (must be square)
    window_cells: usize,
    /// The size of the window in the same units as the radii
    window_size: f64,
    /// The closest z distance within every cell of the window, represented
    /// as a linear array of length window_cells*window_cells
    window_z: []f64,
    /// The character representing the distance the in window
    window_chars: []u8,

    /// Initialize the Torus. This function does not
    /// create the point cloud for the torus, for that
    /// see the createPoints function.
    pub fn init(allocator: std.mem.Allocator) !Torus {
        return .{
            .points = std.MultiArrayList(Point).empty,
            .allocator = allocator,
            .major_radius = 0,
            .minor_radius = 0,
            .window_cells = 0,
            .window_size = 0,
            .window_z = try allocator.alloc(f64, 0),
            .window_chars = try allocator.alloc(u8, 0),
        };
    }

    /// Deinitialize the torus, frees the memory
    /// of the points array and the window holding the
    /// z coordinates of the cells
    pub fn deinit(self: *Torus) void {
        // Free the points array
        self.points.deinit(self.allocator);
        // Free the window_z array
        self.allocator.free(self.window_z);
        // Free the window character array
        self.allocator.free(self.window_chars);
        // Invalidate the pointer
        self.* = undefined;
    }

    /// Set the size of the window, this is in the same units
    /// as the Major and Minor axes (which are arbitrary units,
    /// the relationship between the window size and the radii
    /// are what determine what is drawn).
    pub fn setWindowSize(self: *Torus, window_size: f64) void {
        self.*.window_size = window_size;
    }

    /// Set the number of rows of the window. Note that
    /// since the window must be square this also sets
    /// the number of columns.
    pub fn setWindowCells(self: *Torus, window_cells: usize) !void {
        // Check if an update is needed
        if (self.window_cells == window_cells) {
            return; // Already correct size, no change needed
        }
        // Set the number of cells
        self.window_cells = window_cells;
        // Update the window_z slice to the correct size
        self.allocator.free(self.window_z);
        self.window_z = try self.allocator.alloc(f64, self.window_cells * self.window_cells);
        // Update the window_char slice to the correct size
        self.allocator.free(self.window_chars);
        self.window_chars = try self.allocator.alloc(u8, self.window_cells * self.window_cells);
    }

    /// Uses the equation of a torus to create the set of points representing the donut
    pub fn createPoints(self: *Torus, major_radius: f64, major_steps: usize, minor_radius: f64, minor_steps: usize) !void {
        // Find the change in theta required for the number of steps
        const d_theta: f64 = (2 * math.pi) / @as(f64, @floatFromInt(minor_steps));
        // Find the change in phi required for the number of steps
        const d_phi: f64 = 2 * math.pi / @as(f64, @floatFromInt(major_steps));
        // Set the major and minor radii
        self.major_radius = major_radius;
        self.minor_radius = minor_radius;
        // Calculate the points based on the theta phi parameterization
        for (0..major_steps) |phi_steps| {
            for (0..minor_steps) |theta_steps| {
                const theta = @as(f64, @floatFromInt(theta_steps)) * d_theta;
                const phi = @as(f64, @floatFromInt(phi_steps)) * d_phi;
                try self.points.append(self.allocator, .{
                    .x = (major_radius + minor_radius * math.sin(theta)) * math.cos(phi),
                    .y = (major_radius + minor_radius * math.sin(theta)) * math.sin(phi),
                    .z = minor_radius * math.cos(theta),
                });
            }
        }
    }

    /// Rotate the torus `angle` radians in the X-Y plane
    fn rotateXY(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive
        const cos_angle: f64 = math.cos(angle);
        const sin_angle: f64 = math.sin(angle);
        // Use the rotation matrix to rotate the points
        for (self.points.items(.x), self.points.items(.y)) |*x, *y| {
            const x_new = x.* * cos_angle - y.* * sin_angle;
            const y_new = x.* * sin_angle + y.* * cos_angle;
            x.* = x_new;
            y.* = y_new;
        }
    }

    /// Rotate the torus `angle` radians in the Y-Z plane
    fn rotateYZ(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive

        // Using the negative  of the angle so that
        // a positive angle represents rotating "forward"
        const cos_angle: f64 = math.cos(-angle);
        const sin_angle: f64 = math.sin(-angle);
        // Use the rotation matrix to rotate the points
        for (self.*.points.items(.y), self.*.points.items(.z)) |*y, *z| {
            const z_new = z.* * cos_angle - y.* * sin_angle;
            const y_new = z.* * sin_angle + y.* * cos_angle;
            z.* = z_new;
            y.* = y_new;
        }
    }

    // Rotate the torus `angle` radians in the X-Z plane
    fn rotateXZ(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive

        // Using the negative  of the angle so that
        // a positive angle represents rotating "forward"
        const cos_angle: f64 = math.cos(-angle);
        const sin_angle: f64 = math.sin(-angle);
        // Use the rotation matrix to rotate the points
        for (self.*.points.items(.x), self.*.points.items(.z)) |*x, *z| {
            const z_new = z.* * cos_angle - x.* * sin_angle;
            const x_new = z.* * sin_angle + x.* * cos_angle;
            z.* = z_new;
            x.* = x_new;
        }
    }

    /// Rotate the Torus in the x-y and y-z planes
    pub fn rotate(self: *Torus, xy_rot: f64, yz_rot: f64, xz_rot: f64) void {
        // Rotate through the two degrees of freedom
        self.rotateXY(xy_rot);
        self.rotateYZ(yz_rot);
        self.rotateXZ(xz_rot);
    }

    /// Calculate the Z value in each cell of the window
    pub fn calculateCellZ(self: *Torus) void {
        // Based on the window size, find how much
        // x and y go in each cell
        const cell_size = self.*.window_size / @as(f64, @floatFromInt(self.*.window_cells));
        // Translate the points by half the window size to center them
        const translate_x = self.*.window_size / 2;
        // Same, skipping divide calculation
        // (even though it is just a bit shift theoretically)
        const translate_y = translate_x;
        // "Zero" out the cell array
        for (self.*.window_z) |*cell| {
            cell.* = -math.inf(f64);
        }
        // Step through the points, and figure out the minimum distance
        // away in each cell
        for (self.*.points.items(.x), self.*.points.items(.y), self.*.points.items(.z)) |x, y, z| {
            // Translate x and y
            const new_x = x + translate_x;
            const new_y = y + translate_y;
            if ((new_x < 0) or (new_y < 0)) {
                @panic("Bad x-y coordinate (x or y is less than 0)");
            }
            // Determine which cell the point is in
            const cell_x: usize = @intFromFloat(math.floor(new_x / cell_size));
            const cell_y: usize = @intFromFloat(math.floor(new_y / cell_size));
            // Use the window as row-major
            const position: usize = cell_x * self.*.window_cells + cell_y;
            if (position >= (self.*.window_cells * self.*.window_cells)) {
                @panic("Bad index (exceeds window size)");
            }
            self.*.window_z[position] = @max(self.*.window_z[position], z);
        }
    }

    /// Use the z-values calculated in the
    pub fn findChars(self: *Torus) void {
        // Create an array of characters to use for drawing
        const chars = [_]u8{
            '.', ';', '"', '?', '[', '1', 'w', '&', 'Q', '@',
        };
        // Discretize the z-dimension
        // Find the total range that z can take
        const z_range = self.*.major_radius * 2 + self.*.minor_radius * 4;
        const z_range_half = z_range / 2;
        // Find the length of the steps based on the range and the number
        // of characters being used
        const z_step: f64 = z_range / chars.len;
        // Iterate through the correct row of the window, assigning
        // a character based on the z value, with spaces for -inf
        for (self.*.window_z, 0..) |cell_z, idx| {
            if (cell_z == -math.inf(f64)) {
                self.*.window_chars[idx] = ' ';
            } else {
                self.*.window_chars[idx] = chars[@intFromFloat(math.floor((cell_z + z_range_half) / z_step))];
            }
        }
    }

    /// Get a particular line from the window_chars array
    pub fn getLine(self: *Torus, line: usize) []u8 {
        const line_start = line * self.*.window_cells;
        const line_end = (line + 1) * self.*.window_cells;
        return self.*.window_chars[line_start..line_end];
    }
};

fn checkPointEq(point1: Point, point2: Point, tolerance: f64) bool {
    if ((point1.x - point2.x < tolerance) and (point1.y - point2.y < tolerance) and (point1.z - point2.z < tolerance)) {
        return true;
    }
    return false;
}

fn checkPointsEqNoOrder(points1: std.MultiArrayList(Point), points2: std.MultiArrayList(Point), tolerance: f64) bool {
    if (points1.len != points2.len) {
        return false;
    }
    // Check that points1 is subset of points2
    var points1_subset_points2 = true;
    var found_match = false;
    for (0..points1.len) |i| {
        found_match = false;
        const p1 = points1.get(i);
        for (0..points2.len) |j| {
            const p2 = points2.get(j);
            if (checkPointEq(p1, p2, tolerance)) {
                found_match = true;
            }
        }
        if (!found_match) {
            points1_subset_points2 = false;
        }
    }
    var points2_subset_points1 = true;
    for (0..points2.len) |i| {
        found_match = false;
        const p2 = points2.get(i);
        for (0..points1.len) |j| {
            const p1 = points1.get(j);
            if (checkPointEq(p2, p1, tolerance)) {
                found_match = true;
            }
        }
        if (!found_match) {
            points2_subset_points1 = false;
        }
    }
    if (points1_subset_points2 and points2_subset_points1) {
        return true;
    } else {
        return false;
    }
}
// TESTS:
test "Creating Torus (init and deinit)" {
    var torus = try Torus.init(testing.allocator);
    torus.deinit();
}

test "Generating Torus Points" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    // Create the points array
    try torus.createPoints(10, 20, 1, 5);

    // Should have 20*5==100 points in the points array
    try testing.expectEqual(20 * 5, torus.points.len);
}

test "Generating single point Torus" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    try torus.createPoints(10, 1, 1, 1);

    try testing.expectEqual(1, torus.points.len);

    // The single point should be at when theta=0, phi=0:
    // x = (R + r*sin(theta)) * cos(phi) = (10+0)*1 = 10
    // y = (R + r*sin(theta)) * sin(phi) = (10+0)*0 = 0
    // z = r*cos(theta) = 1*1 = 1
    try testing.expectApproxEqAbs(10.0, torus.points.items(.x)[0], 1e-7);
    try testing.expectApproxEqAbs(0.0, torus.points.items(.y)[0], 1e-7);
    try testing.expectApproxEqAbs(1.0, torus.points.items(.z)[0], 1e-7);
}

test "Generating four point Torus" {
    const test_alloc = testing.allocator;
    var torus: Torus = try Torus.init(test_alloc);
    defer torus.deinit();

    try torus.createPoints(10, 4, 1, 1);
    try testing.expectEqual(4, torus.points.len);
    // Create an expected points list
    var expected_points = std.MultiArrayList(Point).empty;
    defer expected_points.deinit(test_alloc);

    // Phi = 0, pi/2, pi, 3*pi/2
    // x = 10, 0, -10, 0
    // y = 0, 10, 0, -10
    // z = 1, 1, 1, 1
    try expected_points.append(test_alloc, .{ .x = 10.0, .y = 0.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = 10.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = -10.0, .y = 0.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = -10.0, .z = 1.0 });
    try testing.expect(checkPointsEqNoOrder(torus.points, expected_points, 1e-7));
}

test "Rotating points in x-y" {
    const test_alloc = testing.allocator;
    var torus: Torus = try Torus.init(test_alloc);
    defer torus.deinit();

    try torus.createPoints(10, 4, 1, 1);
    try testing.expectEqual(4, torus.points.len);
    // Rotate the four points
    torus.rotateXY(math.pi / 2.0); // Rotating by pi/2 should end up with same coords
    // Create an expected points list
    var expected_points = std.MultiArrayList(Point).empty;
    defer expected_points.deinit(test_alloc);

    // Phi = 0, pi/2, pi, 3*pi/2
    // x = 10, 0, -10, 0
    // y = 0, 10, 0, -10
    // z = 1, 1, 1, 1
    try expected_points.append(test_alloc, .{ .x = 10.0, .y = 0.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = 10.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = -10.0, .y = 0.0, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = -10.0, .z = 1.0 });
    try testing.expect(checkPointsEqNoOrder(torus.points, expected_points, 1e-7));

    // Clear the expected points,
    expected_points.clearRetainingCapacity();
    try expected_points.append(test_alloc, .{ .x = 7.07106781, .y = 7.07106781, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = -7.07106781, .y = 7.07106781, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = -7.07106781, .y = -7.07106781, .z = 1.0 });
    try expected_points.append(test_alloc, .{ .x = 7.07106781, .y = -7.07106781, .z = 1.0 });
    // Rotate the array
    torus.rotateXY(math.pi / 4.0);
    try testing.expect(checkPointsEqNoOrder(torus.points, expected_points, 1e-7));
}

test "Rotating points in y-z" {
    const test_alloc = testing.allocator;
    var torus: Torus = try Torus.init(test_alloc);
    defer torus.deinit();

    try torus.createPoints(10, 4, 1, 1);
    try testing.expectEqual(4, torus.points.len);
    // Rotate the four points
    torus.rotateYZ(math.pi / 2.0);
    // Create an expected points list
    var expected_points = std.MultiArrayList(Point).empty;
    defer expected_points.deinit(test_alloc);

    // Phi = 0, pi/2, pi, 3*pi/2
    // x = 10, 0, -10, 0
    // y = 0, 10, 0, -10
    // z = 1, 1, 1, 1
    try expected_points.append(test_alloc, .{ .x = 10.0, .y = -1.0, .z = 0.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = -1.0, .z = 10.0 });
    try expected_points.append(test_alloc, .{ .x = -10.0, .y = -1.0, .z = 0.0 });
    try expected_points.append(test_alloc, .{ .x = 0.0, .y = -1.0, .z = -10.0 });
    try testing.expect(checkPointsEqNoOrder(torus.points, expected_points, 1e-7));
}
test "Setting window size" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(5.0);

    try testing.expectEqual(5.0, torus.window_size);
}

test "Setting window cells" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(5.0);
    try torus.setWindowCells(10);

    try testing.expectEqual(10, torus.window_cells);
    try testing.expectEqual(100, torus.window_z.len);
    try testing.expectEqual(100, torus.window_chars.len);
}

test "Finding z-coordinates" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0);
    try torus.setWindowCells(10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
}

test "Finding ascii representation" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0);
    try torus.setWindowCells(10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
    torus.findChars();
}

test "Get line of chars" {
    // Basically catch fire test
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0);
    try torus.setWindowCells(10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
    torus.findChars();

    const line = torus.getLine(5);
    try testing.expectEqual(10, line.len);
    for (line) |c| {
        switch (c) {
            '.', ';', '"', '?', '[', '1', 'w', '&', 'Q', '@', ' ' => {},
            else => {
                @panic("Invalid character found in Torus line");
            },
        }
    }
}
