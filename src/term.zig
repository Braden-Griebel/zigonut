//! Functions for working with a terminal

const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;
const math = std.math;

pub var i: usize = 0;
pub var size: Size = undefined;
pub var cooked_termios: os.termios = undefined;
pub var raw: os.termios = undefined;
pub var tty: fs.File = undefined;

const Size = struct { width: usize, height: usize };

pub fn writeLine(writer: anytype, txt: []const u8, y: usize, width: usize) !void {
    try moveCursor(writer, y, 0);
    try writer.writeAll(txt);
    try writer.writeByteNTimes(' ', width - txt.len);
}

pub fn enterRaw() !void {
    const writer = tty.writer();
    cooked_termios = try os.tcgetattr(tty.handle);
    errdefer exitRaw();

    raw = cooked_termios;
    raw.lflag &= ~@as(
        os.system.tcflag_t,
        os.system.ECHO | os.system.ICANON | os.system.ISIG | os.system.IEXTEN,
    );
    raw.iflag &= ~@as(
        os.system.tcflag_t,
        os.system.IXON | os.system.ICRNL | os.system.BRKINT | os.system.INPCK | os.system.ISTRIP,
    );
    raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);
    raw.cflag |= os.system.CS8;
    raw.cc[os.system.V.TIME] = 0;
    raw.cc[os.system.V.MIN] = 1;
    try os.tcsetattr(tty.handle, .FLUSH, raw);

    try hideCursor(writer);
    try enterAlt(writer);
    try clear(writer);
}

pub fn exitRaw() !void {
    const writer = tty.write();
    try clear(writer);
    try leaveAlt(writer);
    try showCursor(writer);
    try attributeReset(writer);
    try os.tcsetattr(tty.handle, .FLUSH, cooked_termios);
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
    var win_size = mem.zeroes(os.system.winsize);
    const err = os.system.ioctl(tty.handle, os.system.T.IOCGWINSZ, @intFromPtr(&win_size));
    if (os.errno(err) != .SUCCESS) {
        return os.unexpectedErrno(@enumFromInt(os.system.E));
    }
    return Size{
        .height = win_size.ws_row,
        .width = win_size.ws_col,
    };
}
