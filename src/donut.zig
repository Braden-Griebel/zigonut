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
    /// The number of horizontal cells of the
    /// window, i.e. number of columns
    window_cells_horizontal: usize,
    /// The number of vertical cells of the window
    window_cells_vertical: usize,
    /// The horizontal size of the window in the same units as the radii
    window_size_horizontal: f64,
    /// The vertical size of the window in the same units as the radii
    window_size_vertical: f64,
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
            .window_cells_horizontal = 0,
            .window_cells_vertical = 0,
            .window_size_horizontal = 0,
            .window_size_vertical = 0,
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
    pub fn setWindowSize(self: *Torus, horizontal: f64, vertical: f64) void {
        self.window_size_horizontal = horizontal;
        self.window_size_vertical = vertical;
    }

    /// Set the number of rows of the window. Note that
    /// since the window must be square this also sets
    /// the number of columns.
    pub fn setWindowCells(self: *Torus, horizontal: usize, vertical: usize) !void {
        // Check if an update is needed
        if ((self.window_cells_horizontal == horizontal) and (self.window_cells_vertical == vertical)) {
            return; // Already correct size, no change needed
        }
        // Set the number of cells
        self.window_cells_horizontal = horizontal;
        self.window_cells_vertical = vertical;
        // Update the window_z slice to the correct size
        self.allocator.free(self.window_z);
        self.window_z = try self.allocator.alloc(f64, self.window_cells_horizontal * self.window_cells_vertical);
        // Update the window_char slice to the correct size
        self.allocator.free(self.window_chars);
        self.window_chars = try self.allocator.alloc(u8, self.window_cells_horizontal * self.window_cells_vertical);
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

    /// Rotate the torus `angle` radians about the x-axis
    fn rotateAboutX(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive
        const cos_angle: f64 = math.cos(angle);
        const sin_angle: f64 = math.sin(angle);
        // Use the rotation matrix to rotate the points
        for (self.points.items(.y), self.points.items(.z)) |*y, *z| {
            const y_new = y.* * cos_angle - z.* * sin_angle;
            const z_new = y.* * sin_angle + z.* * cos_angle;
            z.* = z_new;
            y.* = y_new;
        }
    }

    // Rotate the torus `angle` radians about the y-axis
    fn rotateAboutY(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive
        const cos_angle: f64 = math.cos(angle);
        const sin_angle: f64 = math.sin(angle);
        // Use the rotation matrix to rotate the points
        for (self.points.items(.x), self.points.items(.z)) |*x, *z| {
            const z_new = z.* * cos_angle - x.* * sin_angle;
            const x_new = z.* * sin_angle + x.* * cos_angle;
            z.* = z_new;
            x.* = x_new;
        }
    }

    /// Rotate the torus `angle` radians about the z-axis
    fn rotateAboutZ(self: *Torus, angle: f64) void {
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

    /// Rotate the Torus about the three different axis
    pub fn rotate(self: *Torus, x_axis_rot: f64, y_axis_rot: f64, z_axis_rot: f64) void {
        // Rotate through the three degrees of freedom
        self.rotateAboutX(x_axis_rot);
        self.rotateAboutY(y_axis_rot);
        self.rotateAboutZ(z_axis_rot);
    }

    /// Calculate the Z value in each cell of the window
    pub fn calculateCellZ(self: *Torus) void {
        // Based on the window size, find how much
        // x and y go in each cell
        const cell_size_horizontal = self.window_size_horizontal / @as(f64, @floatFromInt(self.window_cells_horizontal));
        const cell_size_vertical = self.window_size_vertical / @as(f64, @floatFromInt(self.window_cells_vertical));
        // Moving the origin to the center of the window
        // Translate the points by half the window size horizontally
        const translate_x = self.window_size_horizontal / 2.0;
        // Translate the points by hald the window size vertically
        const translate_y = self.window_size_vertical / 2.0;
        // Zero out the z-array
        @memset(self.window_z, -math.inf(f64));
        // Step through the points, and figure out the minimum distance
        // away in each cell
        for (self.points.items(.x), self.points.items(.y), self.points.items(.z)) |x, y, z| {
            // Translate x and y
            const new_x = x + translate_x;
            const new_y = -y + translate_y; // y is flipped, since the window is from top to bottom
            // If either x or y are still less than zero,
            // do not try to render this point
            if ((new_x < 0.0) or (new_y < 0.0)) {
                continue;
            }
            // Determine which cell the point should be in
            const cell_x: usize = @intFromFloat(math.floor(new_x / cell_size_horizontal));
            const cell_y: usize = @intFromFloat(math.floor(new_y / cell_size_vertical));
            // If the cell for either is too large, do not try to render
            if ((cell_x >= self.window_cells_horizontal) or (cell_y >= self.window_cells_vertical)) {
                continue;
            }
            // Use the window as row-major
            const position: usize = cell_y * self.window_cells_horizontal + cell_x;
            // If the position is too large don't render the point
            if (position >= self.window_z.len) {
                continue; // This should never actually happen
            }
            // Set the value (this should be safe with the above checks)
            self.window_z[position] = @max(self.window_z[position], z);
        }
    }

    /// Use the z-values calculated in the calculateCellZ function
    /// to determine the character that should be in each cell
    pub fn calculateCellChars(self: *Torus) void {
        // Create an array of characters to use for drawing
        // These should get brighter as they go farther forward
        const chars = [_]u8{
            '.',
            '"',
            '+',
            '=',
            '*',
            'i',
            'l',
            'a',
            'p',
            'b',
            '&',
            '@',
        };
        // Discretize the z-dimension
        // Find the total range that z can take
        const z_range = self.major_radius * 2 + self.minor_radius * 2;
        const z_range_half = z_range / 2;
        // Find the length of the steps based on the range and the number
        // of characters being used
        const z_step: f64 = z_range / chars.len;
        // Iterate through the correct row of the window, assigning
        // a character based on the z value, with spaces for -inf
        for (self.window_z, 0..) |cell_z, idx| {
            if (cell_z == -math.inf(f64)) {
                self.window_chars[idx] = ' ';
            } else {
                // Translate the z so that the range is all positive
                const translated_z = cell_z + z_range_half;
                // Make sure no translated z is negative
                if (translated_z < 0.0) {
                    continue;
                }
                // Determine the character position based on the step
                const char_pos: usize = @intFromFloat(math.floor((cell_z + z_range_half) / z_step));
                // If the character position is too great, don't render it
                if (char_pos >= chars.len) {
                    continue;
                }
                // Actually set the calculated character
                self.window_chars[idx] = chars[char_pos];
            }
        }
    }

    /// Get a particular line from the window_chars array
    pub fn getLine(self: *Torus, line: usize) []u8 {
        const line_start = line * self.window_cells_horizontal;
        const line_end = (line + 1) * self.window_cells_horizontal;
        return self.window_chars[line_start..line_end];
    }
};

// Helper functions (Mostly to help with testing)
/// Check that two points are equal, within tolerance
fn checkPointEq(point1: Point, point2: Point, tolerance: f64) bool {
    if ((point1.x - point2.x < tolerance) and (point1.y - point2.y < tolerance) and (point1.z - point2.z < tolerance)) {
        return true;
    }
    return false;
}

/// Check that two MultiArrayLists of points contain points that are equal (within tolerance)
/// Checks this equality by determining that both sets of points are subsets of each other
/// which is equivalent to equality without considering order
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

test "Rotating points about z" {
    const test_alloc = testing.allocator;
    var torus: Torus = try Torus.init(test_alloc);
    defer torus.deinit();

    try torus.createPoints(10, 4, 1, 1);
    try testing.expectEqual(4, torus.points.len);
    // Rotate the four points
    torus.rotateAboutZ(math.pi / 2.0); // Rotating by pi/2 should end up with same coords
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
    torus.rotateAboutZ(math.pi / 4.0);
    try testing.expect(checkPointsEqNoOrder(torus.points, expected_points, 1e-7));
}

test "Rotating points about x" {
    const test_alloc = testing.allocator;
    var torus: Torus = try Torus.init(test_alloc);
    defer torus.deinit();

    try torus.createPoints(10, 4, 1, 1);
    try testing.expectEqual(4, torus.points.len);
    // Rotate the four points
    torus.rotateAboutX(math.pi / 2.0);
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

    torus.setWindowSize(5.0, 6.0);

    try testing.expectEqual(5.0, torus.window_size_horizontal);
    try testing.expectEqual(6.0, torus.window_size_vertical);
}

test "Setting window cells" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(5.0, 5.0);
    try torus.setWindowCells(20, 10);

    try testing.expectEqual(20, torus.window_cells_horizontal);
    try testing.expectEqual(10, torus.window_cells_vertical);
    try testing.expectEqual(200, torus.window_z.len);
    try testing.expectEqual(200, torus.window_chars.len);
}

test "Finding z-coordinates" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0, 20.0);
    try torus.setWindowCells(20, 10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
}

test "Finding ascii representation" {
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0, 20.0);
    try torus.setWindowCells(20, 10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
    torus.calculateCellChars();
}

test "Get line of chars" {
    // Basically catch fire test
    var torus = try Torus.init(testing.allocator);
    defer torus.deinit();

    torus.setWindowSize(20.0, 20.0);
    try torus.setWindowCells(20, 10);

    try torus.createPoints(5.0, 10, 1.0, 5);

    torus.calculateCellZ();
    torus.calculateCellChars();

    const line = torus.getLine(5);
    try testing.expectEqual(20, line.len);
    for (line) |c| {
        switch (c) {
            '.', '-', '`', ';', '!', '"', '+', '(', ')', '=', 'v', 'L', '*', '?', '[', 'T', 'n', 'i', '}', '{', '7', 'l', 'j', '1', 'a', 'V', '2', 'P', '6', 'f', 'w', 'E', 'p', 'b', 'A', 'q', '#', '&', '%', 'Q', 'M', 'B', '@', '$', ' ' => {},
            else => {
                @panic("Invalid character found in Torus line");
            },
        }
    }
}
