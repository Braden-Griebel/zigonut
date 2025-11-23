//! Functions for working with a terminal

const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;
const posix = std.posix;
const math = std.math;

pub var i: usize = 0;
pub var size: Size = undefined;
pub var cooked_termios: posix.termios = undefined;
pub var raw: posix.termios = undefined;
pub var tty: fs.File = undefined;
pub const Size = struct { width: usize, height: usize };

pub fn writeLine(stdout: *std.Io.Writer, txt: []const u8, y: usize, width: usize) !void {
    try moveCursor(stdout, y, 0);
    try stdout.writeAll(txt);
    try stdout.splatByteAll(' ', width - txt.len);
}

pub fn writeLinePadded(stdout: *std.Io.Writer, txt: []const u8, y: usize, left_pad: usize, right_pad: usize) !void {
    try moveCursor(stdout, y, 0);
    try stdout.splatByteAll(' ', left_pad);
    try stdout.writeAll(txt);
    try stdout.splatByteAll(' ', right_pad);
}

pub fn enterRaw(stdout: *std.Io.Writer) !void {
    cooked_termios = try posix.tcgetattr(tty.handle);
    errdefer exitRaw(stdout) catch {};

    raw = cooked_termios;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    raw.lflag.IEXTEN = false;
    // raw.lflag &= ~@as(
    //     posix.tcflag_t,
    //     posix.ECHO | posix.ICANON | posix.ISIG | posix.IEXTEN,
    // );
    raw.iflag.IXON = false;
    raw.iflag.ICRNL = false;
    raw.iflag.BRKINT = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;
    // raw.iflag &= ~@as(
    //     posix.tcflag_t,
    //     posix.IXON | posix.ICRNL | posix.BRKINT | posix.INPCK | posix.ISTRIP,
    // );
    raw.oflag.OPOST = false;
    // raw.oflag &= ~@as(posix.tcflag_t, posix.OPOST);
    // raw.cflag |= posix.CS8;
    raw.cc[@intFromEnum(posix.V.TIME)] = 0;
    raw.cc[@intFromEnum(posix.V.MIN)] = 0;
    try posix.tcsetattr(tty.handle, .FLUSH, raw);

    try hideCursor(stdout);
    try enterAlt(stdout);
    try clear(stdout);
}

pub fn exitRaw(stdout: *std.Io.Writer) !void {
    try clear(stdout);
    try leaveAlt(stdout);
    try showCursor(stdout);
    try attributeReset(stdout);
    try posix.tcsetattr(tty.handle, .FLUSH, cooked_termios);
}

pub fn moveCursor(stdout: *std.Io.Writer, row: usize, col: usize) !void {
    _ = try stdout.print("\x1B[{};{}H", .{ row + 1, col + 1 });
}

pub fn enterAlt(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[s"); // Save cursor position.
    try stdout.writeAll("\x1B[?47h"); // Save screen.
    try stdout.writeAll("\x1B[?1049h"); // Enable alternative buffer.
}

pub fn leaveAlt(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[?1049l"); // Disable alternative buffer.
    try stdout.writeAll("\x1B[?47l"); // Restore screen.
    try stdout.writeAll("\x1B[u"); // Restore cursor position.
}

pub fn hideCursor(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[?25l");
}

pub fn showCursor(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[?25h");
}

pub fn attributeReset(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[0m");
}

pub fn blueBackground(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[44m");
}

pub fn clear(stdout: *std.Io.Writer) !void {
    try stdout.writeAll("\x1B[2J");
}

pub fn getSize() !Size {
    var win_size = mem.zeroes(posix.winsize);
    const err = posix.system.ioctl(tty.handle, posix.system.T.IOCGWINSZ, @intFromPtr(&win_size));
    if (posix.errno(err) != .SUCCESS) {
        return posix.unexpectedErrno(@enumFromInt(err));
    }
    return Size{
        .height = win_size.row,
        .width = win_size.col,
    };
}
