// Standard Library Imports
const std = @import("std");
const fs = std.fs;
const math = std.math;
const os = std.os;

// Local Imports
const zigonut = @import("zigonut");
const term = zigonut.term;
const donut = zigonut.donut;

// Global Constant Definitions
// The amount of time between each step (in ms)
const delta_time = 200;
// The minimum amount of padding on the top and bottom
const vertical_padding = 3;
// The minimum amount of padding on the sides
const horizontal_padding = 3;
// Constants defining the Torus
const torus_major_radius = 5;
const torus_minor_radius = 1;
const torus_window_size = 20;
const torus_window_cells = 30;
const torus_major_step = 50;
const torus_minor_step = 10;
const torus_theta_step = (2 * math.pi) / 100;
const torus_phi_step = (2 * math.pi) / 200;

// Global Variable Definitions
// The time the previous frame was created, used for delta time
var prev_time = std.time.milliTimestamp();

pub fn main() !void {
    // Get the tty
    term.tty = try fs.cwd().openFile("/dev/tty", .{ .read = true, .write = true });
    defer term.tty.close();

    // Enter raw mode
    try term.enterRaw();
    defer term.exitRaw() catch {};

    // Get the size of the terminal
    term.size = try term.getSize();

    // Based on the initial size, find the

    // Handle the terminal being resized (SIGWINCH signal)
    os.sigaction(os.SIG.WINCH, &os.Sigaction{
        .handler = .{ .handler = term.handleSigWinch },
        .mask = os.empty_sigset,
        .flags = 0,
    }, null);

    // Create the torus
    // get an allocator for the torus
    var gpa = std.head.GeneralPurposeALlocator(.{}){};
    const allocator = gpa.allocator();
    // Initialize the torus with this allocator
    var torus = donut.Torus.init(allocator);
    defer torus.deinit();
    // Create the points of the torus
    try torus.createPoints(torus_major_radius, torus_major_steps, torus_minor_radius, torus_minor_steps);
    // Set the window size and cells
    torus.setWindowSize(torus_window_size);
    try torus.setWindowCells(torus_window_cells);
    // Calculate the initial
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
    if ((2 * min_horizontal_pad + needed_window_cells > term_width) | (2 * min_vertical_pad + needed_window_cells > term_height)) {
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

fn dispWindowTooSmall(writer: anytype) !void {
    // For now just in the top left corner, should center it eventually
    term.moveCursor(writer, 0, 0);
    // Write the message
    try writer.writeAll("Window too small, please resize!");
}

fn renderTorus(writer: anytype, torus: *donut.Torus) !void {}

fn stepTorus(writer: anytype, torus: *donut.Torus) !void {}
