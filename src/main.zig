// Standard Library Imports
const std = @import("std");
const fs = std.fs;
const math = std.math;
const os = std.os;
const testing = std.testing;
const posix = std.posix;

// Local Imports
const zigonut = @import("zigonut");
const term = zigonut.term;
const donut = zigonut.donut;

// Global Constant Definitions
// The amount of time between each step (in ms)
const delta_time = 100.0;
// The maximum number of frames to render per second
const max_frames = 30;
const min_millis_per_frame = 1000 / max_frames;
// The minimum amount of padding on the top and bottom
const min_vertical_padding = 0;
// The minimum amount of padding on the sides
const min_horizontal_padding = 0;
// The next two values define the RATIO of the horizontal to
// vertical cells, not the actual values
const torus_window_cells_horizontal_ratio = 3;
const torus_window_cells_vertical_ratio = 1;
// Number of steps of rotation about the z axis to define the torus
const torus_major_steps = 50;
// Number of steps around the "tube" of the torus
const torus_minor_steps = 20;
// Define the speed of rotation
const torus_z_angle_step = (2 * math.pi) / 50.0;
const torus_x_angle_step = (2 * math.pi) / 25.0;
const torus_y_angle_step = (2 * math.pi) / 50.0;

// Global Variable Definitions
// The time the previous frame was created, used for delta time
var prev_time: i64 = undefined;
// Variables defining the Torus
var torus_major_radius: f64 = 20.0;
var torus_minor_radius: f64 = 5.0;
var torus_window_size_horizontal: f64 = 200.0;
var torus_window_size_vertical: f64 = 100.0;
// The calculated window size in cells for the torus
var torus_window_cells: TorusSizeCells = undefined;

pub fn main() !void {
    // Get the tty
    term.tty = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
    defer term.tty.close();

    // Enter raw mode
    try term.enterRaw();
    defer term.exitRaw() catch {};

    // Get the size of the terminal
    term.size = try term.getSize();

    // Based on the initial size, find the desired size of the torus
    torus_window_cells.update();
    // Handle the terminal being resized (SIGWINCH signal)
    posix.sigaction(posix.SIG.WINCH, &posix.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = posix.sigemptyset(),
        .flags = 0,
    }, null);

    // Create the torus
    // get an allocator for the torus
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // Initialize the torus with this allocator
    var torus = try donut.Torus.init(allocator);
    defer torus.deinit();
    // Create the points of the torus
    try torus.createPoints(torus_major_radius, torus_major_steps, torus_minor_radius, torus_minor_steps);
    // Set the window size and cells
    torus.setWindowSize(torus_window_size_horizontal, torus_window_size_vertical);
    try torus.setWindowCells(torus_window_cells.window_horizontal_cells, torus_window_cells.window_vertical_cells);
    // Get the current time
    prev_time = std.time.milliTimestamp();
    // Render loop
    while (true) {
        try renderTorus(&torus);
        // Handle user input (basically only care to quit)
        var buffer: [1]u8 = undefined;
        _ = try term.tty.read(&buffer);

        // Handle the q button press
        if (buffer[0] == 'q') {
            return;
        }
    }
}

const Padding = struct {
    top: usize,
    bottom: usize,
    left: usize,
    right: usize,
};

/// A struct to hold information about the
/// Torus window size in cells
const TorusSizeCells = struct {
    window_horizontal_cells: usize,
    window_vertical_cells: usize,
    term_padding: Padding,

    pub fn update(self: *TorusSizeCells) void {
        // Set the horizontal cells to the maximum, and calculate what that would mean the
        // vertical cells should be
        const horizontal_cells_max: usize = term.size.width - 2 * min_horizontal_padding;
        const calculated_vertical_cells: usize = @divFloor(horizontal_cells_max, torus_window_cells_horizontal_ratio) * torus_window_cells_vertical_ratio;

        // Set the vertical cells to the maximum and calculate what that would mean the vertical
        // cells should be
        const vertical_cells_max: usize = term.size.height - 2 * min_vertical_padding;
        const calculated_horizontal_cells: usize = @divFloor(vertical_cells_max, torus_window_cells_vertical_ratio) * torus_window_cells_horizontal_ratio;

        // If we can match the maximum horizontal, then do that
        if (calculated_vertical_cells <= vertical_cells_max) {
            self.window_horizontal_cells = horizontal_cells_max;
            self.window_vertical_cells = calculated_vertical_cells;
        } else if (calculated_horizontal_cells <= horizontal_cells_max) {
            // Otherwise match the vertical
            self.window_horizontal_cells = calculated_horizontal_cells;
            self.window_vertical_cells = vertical_cells_max;
        } else {
            // The window size is too small
            self.window_horizontal_cells = 0;
            self.window_vertical_cells = 0;
        }

        // Now that the window size has been determined, set the padding
        const new_top_padding: usize = @divFloor(term.size.height - self.window_vertical_cells, 2);
        const new_bottom_padding = term.size.height - (new_top_padding + self.window_vertical_cells);
        const new_right_padding: usize = @divFloor(term.size.width - self.window_horizontal_cells, 2);
        const new_left_padding: usize = term.size.width - (new_right_padding + self.window_horizontal_cells);

        self.term_padding = .{
            .top = new_top_padding,
            .bottom = new_bottom_padding,
            .left = new_left_padding,
            .right = new_right_padding,
        };
    }
};

/// Render the Torus (includes stepping the torus before rendering)
fn renderTorus(torus: *donut.Torus) !void {
    // Set a maximum frame limit
    if (std.time.milliTimestamp() - prev_time < min_millis_per_frame) {
        return;
    }

    const writer = term.tty.writer();

    // Start by updating the window size
    torus_window_cells.update();
    // Update the torus window size
    try torus.setWindowCells(torus_window_cells.window_horizontal_cells, torus_window_cells.window_vertical_cells);

    // Step the torus
    stepTorus(torus);
    // Clear the screen
    try term.clear(writer);
    // If the window is too small (i.e. the window size is 0), skip trying to render
    if ((torus_window_cells.window_horizontal_cells == 0) or (torus_window_cells.window_vertical_cells == 0)) {
        return;
    }

    for (torus_window_cells.term_padding.top..((term.size.height - torus_window_cells.term_padding.bottom)), 0..torus.window_cells_vertical) |
        term_row,
        torus_row,
    | {
        // Write a padded line
        try term.writeLinePadded(writer, torus.getLine(torus_row), term_row, torus_window_cells.term_padding.left, torus_window_cells.term_padding.right);
    }
    return;
}

/// Step the torus, includes rotation, and updating the window_z and window_chars
fn stepTorus(torus: *donut.Torus) void {
    // Start by getting the amount of time since the last frame was rendered
    const cur_time = std.time.milliTimestamp();
    const frame_time = cur_time - prev_time;
    prev_time = cur_time;
    // Find how much the angles should change based on the time
    const n_steps = @as(f64, @floatFromInt(frame_time)) / delta_time;
    const delta_x_angle = torus_x_angle_step * n_steps;
    const delta_z_angle = torus_z_angle_step * n_steps;
    const delta_y_angle: f64 = torus_y_angle_step * n_steps;
    // Rotate the torus this amount
    torus.rotate(delta_x_angle, delta_y_angle, delta_z_angle);
    // Calculate the z-values of the window
    torus.calculateCellZ();
    // Determine the charcters in the window
    torus.calculateCellChars();
}

fn handleSigWinch(_: c_int) callconv(.C) void {
    term.size = term.getSize() catch return;
}
