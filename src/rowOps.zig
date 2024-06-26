const std = @import("std");
const io = @import("std").io;
const data = @import("./data.zig");
const syntax = @import("./syntax_highlighting.zig");

pub fn editorRowCxToRx(row: *data.erow, cx: usize) usize {
    var rx: usize = 0;
    for (0..cx) |j| {
        if (row.chars[j] == '\t') {
            rx += (data.TABSTOP - 1) - (rx % data.TABSTOP);
        }
        rx += 1;
    }
    return rx;
}
pub fn editorRowRxToCx(row: *data.erow, rx: usize) usize {
    var cur_rx: usize = 0;
    var eCx: usize = 0;
    for (0..row.chars.len) |cx| {
        if (row.chars[cx] == '\t') {
            cur_rx += (data.TABSTOP - 1) - (cur_rx % data.TABSTOP);
        }
        cur_rx += 1;

        if (cur_rx > rx) return cx;
        eCx = cx;
    }
    return eCx;
}

pub fn editorInsertRow(at: usize, row: []u8) !void {
    if (at < 0 or at > data.editor.numRows) return;

    data.editor.row = try data.editor.ally.realloc(data.editor.row, data.editor.numRows + 1);
    std.mem.copyBackwards(data.erow, data.editor.row[(at + 1)..data.editor.row.len], data.editor.row[at .. data.editor.row.len - 1]);

    data.editor.row[at].chars = try data.editor.ally.alloc(u8, row.len);
    @memcpy(data.editor.row[at].chars, row);

    data.editor.row[at].render = &.{};
    data.editor.row[at].highlight = &.{};
    try editorUpdateRow(&data.editor.row[at]);
    data.editor.numRows += 1;
    data.editor.dirty += 1;
}

pub fn editorUpdateRow(row: *data.erow) !void {
    var tabs: u8 = 0;

    for (0..row.chars.len) |j| {
        if (row.chars[j] == '\t') tabs += 1;
    }

    const alloc = data.editor.ally;
    alloc.free(row.render);
    row.render = try alloc.alloc(u8, row.chars.len + tabs * (data.TABSTOP - 1));

    var idx: usize = 0;
    for (0..row.chars.len) |j| {
        if (row.chars[j] == '\t') {
            row.render[idx] = ' ';
            idx += 1;
            while (idx % data.TABSTOP != 0) {
                row.render[idx] = ' ';
                idx += 1;
            }
        } else {
            row.render[idx] = row.chars[j];
            idx += 1;
        }
    }
    try syntax.editorUpdateSyntax(row);
}

pub fn editorRowInsertChar(row: *data.erow, at_: usize, key: u16) !void {
    var alloc = data.editor.ally;
    var at: usize = at_;
    if (at < 0 or at > row.chars.len) at = row.chars.len;
    row.chars = try alloc.realloc(row.chars, row.chars.len + 1);
    //Backwards as I am copying things from behind
    std.mem.copyBackwards(u8, row.chars[(at + 1)..row.chars.len], row.chars[at .. row.chars.len - 1]);
    row.chars[at] = @as(u8, @intCast(key));
    try editorUpdateRow(row);
    data.editor.dirty += 1;
}

pub fn editorRowDelChar(row: *data.erow, at: usize) !void {
    if (at < 0 or at >= row.chars.len) return;
    //Forwards because it is the opposite as above
    std.mem.copyForwards(u8, row.chars[at..], row.chars[(at + 1)..row.chars.len]);
    row.chars = try data.editor.ally.realloc(row.chars, row.chars.len - 1);
    try editorUpdateRow(row);
    data.editor.dirty += 1;
}

fn editorFreeRow(row: *data.erow) void {
    data.editor.ally.free(row.chars);
    data.editor.ally.free(row.render);
    data.editor.ally.free(row.highlight);
}

pub fn editorDelRow(at: usize) !void {
    var row = data.editor.row;
    if (at < 0 or at >= data.editor.numRows) return;
    editorFreeRow(&data.editor.row[at]);
    std.mem.copyForwards(data.erow, row[at..], row[(at + 1)..]);
    row = try data.editor.ally.realloc(row, row.len - 1);
    data.editor.numRows -= 1;
    data.editor.row.len -= 1;
    data.editor.dirty += 1;
}

pub fn editorRowAppendString(row: *data.erow, s: []const u8) !void {
    const ally = data.editor.ally;
    const size = row.chars.len;
    row.chars = try ally.realloc(row.chars, row.chars.len + s.len);
    std.mem.copyBackwards(u8, row.chars[size..], s);
    try editorUpdateRow(row);
    data.editor.dirty += 1;
}
