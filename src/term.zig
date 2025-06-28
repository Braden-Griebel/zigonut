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

pub fn writeLine(writer: anytype, txt: []const u8, y: usize, width: usize) !void {
    try moveCursor(writer, y, 0);
    try writer.writeAll(txt);
    try writer.writeByteNTimes(' ', width - txt.len);
}

pub fn writeLinePadded(writer: anytype, txt: []const u8, y: usize, left_pad: usize, right_pad: usize) !void {
    try moveCursor(writer, y, 0);
    try writer.writeByteNTimes(' ', left_pad);
    try writer.writeAll(txt);
    try writer.writeByteNTimes(' ', right_pad);
}

pub fn enterRaw() !void {
    const writer = tty.writer();

    cooked_termios = try posix.tcgetattr(tty.handle);
    errdefer exitRaw() catch {};

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

    try hideCursor(writer);
    try enterAlt(writer);
    try clear(writer);
}

pub fn exitRaw() !void {
    const writer = tty.writer();
    try clear(writer);
    try leaveAlt(writer);
    try showCursor(writer);
    try attributeReset(writer);
    try posix.tcsetattr(tty.handle, .FLUSH, cooked_termios);
}

pub fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    _ = try writer.print("\x1B[{};{}H", .{ row + 1, col + 1 });
}

pub fn enterAlt(writer: anytype) !void {
    try writer.writeAll("\x1B[s"); // Save cursor position.
    try writer.writeAll("\x1B[?47h"); // Save screen.
    try writer.writeAll("\x1B[?1049h"); // Enable alternative buffer.
}

pub fn leaveAlt(writer: anytype) !void {
    try writer.writeAll("\x1B[?1049l"); // Disable alternative buffer.
    try writer.writeAll("\x1B[?47l"); // Restore screen.
    try writer.writeAll("\x1B[u"); // Restore cursor position.
}

pub fn hideCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?25l");
}

pub fn showCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?25h");
}

pub fn attributeReset(writer: anytype) !void {
    try writer.writeAll("\x1B[0m");
}

pub fn blueBackground(writer: anytype) !void {
    try writer.writeAll("\x1B[44m");
}

pub fn clear(writer: anytype) !void {
    try writer.writeAll("\x1B[2J");
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
