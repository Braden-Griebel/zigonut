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
const delta_time = 50.0;
// The minimum amount of padding on the top and bottom
const vertical_padding = 3;
// The minimum amount of padding on the sides
const horizontal_padding = 3;
// Constants defining the Torus
const torus_major_radius = 10.0;
const torus_minor_radius = 3.0;
const torus_window_size = 50.0;
const torus_window_cells = 30;
const torus_major_steps = 30;
const torus_minor_steps = 10;
const torus_xy_angle_step = (2 * math.pi) / 137.0;
const torus_yz_angle_step = (2 * math.pi) / 195.0;
const torus_xz_angle_step = (2 * math.pi) / 47.0;

// Global Variable Definitions
// The time the previous frame was created, used for delta time
var prev_time: i64 = undefined;

pub fn main() !void {
    // Get the tty
    term.tty = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
    defer term.tty.close();

    // Enter raw mode
    try term.enterRaw();
    defer term.exitRaw() catch {};

    // Get the size of the terminal
    term.size = try term.getSize();

    // Based on the initial size, find the

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
    torus.setWindowSize(torus_window_size);
    try torus.setWindowCells(torus_window_cells);
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

const PaddingError = error{
    TermTooSmall,
};

fn determinePadding(term_size: term.Size, min_horizontal_pad: usize, min_vertical_pad: usize, needed_window_cells: usize) PaddingError!Padding {
    const term_width = term_size.width;
    const term_height = term_size.height;
    // Check if padding is actually possible
    if ((2 * min_horizontal_pad + needed_window_cells > term_width) or (2 * min_vertical_pad + needed_window_cells > term_height)) {
        return PaddingError.TermTooSmall;
    }
    // Determine the actual padding
    const left_pad: usize = @divFloor((term_width - needed_window_cells), 2);
    const top_pad: usize = @divFloor((term_height - needed_window_cells), 2);
    const right_pad: usize = term_width - (left_pad + needed_window_cells);
    const bottom_pad: usize = term_height - (top_pad + needed_window_cells);
    return .{
        .top = top_pad,
        .bottom = bottom_pad,
        .left = left_pad,
        .right = right_pad,
    };
}

/// Display a warning that the window is too small to render the torus
fn dispWindowTooSmall(writer: anytype) !void {
    // For now just in the top left corner, should center it eventually
    try term.moveCursor(writer, 0, 0);
    // Write the message
    try writer.writeAll("Window too small, please resize!");
}

/// Render the Torus (includes stepping the torus before rendering)
fn renderTorus(torus: *donut.Torus) !void {
    const writer = term.tty.writer();

    // Start by getting the needed padding
    const padding = determinePadding(term.size, horizontal_padding, vertical_padding, torus.window_cells) catch |err| switch (err) {
        PaddingError.TermTooSmall => {
            try dispWindowTooSmall(writer);
            return;
        },
    };
    // Step the torus
    stepTorus(torus);
    // Clear the screen
    try term.clear(writer);
    for (padding.top..((term.size.height - padding.bottom)), 0..torus.window_cells) |
        term_row,
        torus_row,
    | {
        // Write a padded line
        try term.writeLinePadded(writer, torus.getLine(torus_row), term_row, padding.left, padding.right);
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
    const delta_xy_angle = torus_xy_angle_step * n_steps;
    const delta_yz_angle = torus_yz_angle_step * n_steps;
    const delta_xz_angle: f64 = torus_xz_angle_step * n_steps;
    // Rotate the torus this amount
    torus.rotate(delta_xy_angle, delta_yz_angle, delta_xz_angle);
    // Calculate the z-values of the window
    torus.calculateCellZ();
    // Determine the charcters in the window
    torus.findChars();
}

fn handleSigWinch(_: c_int) callconv(.C) void {
    term.size = term.getSize() catch return;
}

test "Find padding" {
    const padding = try determinePadding(.{ .width = 100, .height = 100 }, 10, 10, 50);
    try testing.expectEqual(25, padding.top);
    try testing.expectEqual(25, padding.bottom);
    try testing.expectEqual(25, padding.left);
    try testing.expectEqual(25, padding.right);
}
