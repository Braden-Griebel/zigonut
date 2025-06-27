//! Module for working with the Torus
const std = @import("std");
const math = std.math;

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
    pub fn init(allocator: std.mem.Allocator) Torus {
        return .{
            .points = std.MultiArrayList(Point).init(allocator),
            .allocator = allocator,
            .major_radius = 0,
            .minor_radius = 0,
            .window_cells = 0,
            .window_size = 0,
            .window = undefined,
            .window_chars = undefined,
        };
    }

    /// Deinitialize the torus, frees the memory
    /// of the points array and the window holding the
    /// z coordinates of the cells
    pub fn deinit(self: *Torus) void {
        // Free the window array
        self.*.allocator.free(self.*.window_z);
        // Free the points array
        self.*.points.deinit();
        // Free the window array
        self.*.allocator.free(self.*.window_z);
        // Free the window character array
        self.*.allocator.free(self.*.window_chars);
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
        // Set the number of
        self.*.window_cells = window_cells;
        self.*.allocator.free(self.*.window_z);
        self.*.window_z = try self.*.allocator.alloc(f64, window_cells * window_cells);
    }

    /// Uses the equation of a torus to create the set of points representing the donut
    pub fn createPoints(self: *Torus, major_radius: f64, major_steps: usize, minor_radius: f64, minor_steps: usize) !void {
        // Find the change in theta required for the number of steps
        const d_theta = 2 * math.pi / major_steps;
        // Find the change in phi required for the number of steps
        const d_phi = 2 * math.pi / minor_steps;
        // Set the major and minor radii
        self.*.major_radius = major_radius;
        self.*.minor_radius = minor_radius;
        // Calculate the points based on the theta phi parameterization
        for (0..major_steps, 0..minor_steps) |theta_steps, phi_steps| {
            const theta = theta_steps * d_theta;
            const phi = phi_steps * d_phi;
            try self.points.append(self.*.allocator, .{
                .x = (major_radius + minor_radius * math.sin(theta)) * math.cos(phi),
                .y = (major_radius + minor_radius * math.sin(theta)) * math.sin(phi),
                .z = minor_radius * math.cos(theta),
            });
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
        for (self.*.points(.x), self.*.points(.y)) |*x, *y| {
            x.* = x.* * cos_angle - y.* * sin_angle;
            y.* = x.* * sin_angle + y.* * cos_angle;
        }
    }

    /// Rotate the torus `angle` radians in the Y-Z plane
    fn rotateYZ(self: *Torus, angle: f64) void {
        // Calculate the cos and sin of the angle
        // doing this outside the loop since the
        // calculation is expensive
        const cos_angle: f64 = math.cos(angle);
        const sin_angle: f64 = math.sin(angle);
        // Use the rotation matrix to rotate the points
        for (self.*.points(.y), self.*.points(.z)) |*y, *z| {
            y.* = y.* * cos_angle - z.* * sin_angle;
            z.* = y.* * sin_angle + z.* * cos_angle;
        }
    }

    /// Rotate the Torus theta in the X-Y plane, and phi in
    /// the Y-Z plane
    pub fn rotate(self: *Torus, theta: f64, phi: f64) void {
        // Rotate through the two degrees of freedom
        self.rotateXY(theta);
        self.rotateYZ(phi);
    }

    /// Calculate the Z value in each cell of the window
    pub fn calculateCellZ(self: *Torus) void {
        // Based on the window size, find how much
        // x and y go in each cell
        const cell_size = self.*.window_size / @as(f64, self.*.window_cells);
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
        for (self.*.points(.x), self.*.points(.y), self.*.points(.z)) |x, y, z| {
            // Translate x and y
            x += translate_x;
            y += translate_y;
            if ((x < 0) | (y < 0)) {
                @panic("Bad x-y coordinate (x or y is less than 0)");
            }
            // Determine which cell the point is in
            const cell_x: usize = math.floor(usize)(x / cell_size);
            const cell_y: usize = math.floot(usize)(y / cell_size);
            // Use the window as row-major
            const position: usize = cell_x * self.*.window_cells + cell_y;
            if (position >= (self.*.window_cells * self.*.window_cells)) {
                @panic("Bad index (exceeds window size)");
            }
            self.*.window_z[position] = @max(self.*.window_z, z);
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
        // a character based on the z value
        for (self.*.window_z, 0..) |cell_z, idx| {
            self.*.window_chars[idx] = chars[math.floor(usize)((cell_z + z_range_half) / z_step)];
        }
    }

    /// Get a particular line from the window_chars array
    pub fn getLine(self: *Torus, line: usize) []u8 {
        const line_start = line * self.*.window_cells;
        const line_end = (line + 1) * self.*.window_cells;
        return self.*.window_chars[line_start..line_end];
    }
};
