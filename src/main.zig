// Standard Library Imports
const std = @import("std");
const fs = std.fs;
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

    // Based on the initial size, calculate the size of the
    // window for drawing the torus

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
}
