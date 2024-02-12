const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = "example";
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    const tokens = try lex_tokens(&file, allocator);
    defer tokens.deinit();
    defer for (tokens.items) |token| {
        token.deinit();
    };

    for (tokens.items) |token| {
        print("Token: {}\n", .{token});
    }

    const tree = try parse_tree(tokens, allocator);
    defer tree.deinit();
    print("\nTree: {any}\n", .{tree});
}

fn parse_tree(tokens: ArrayList(Token), allocator: anytype) !TokenTree {
    _ = tokens;
    var string = ArrayList(u8).init(allocator);
    try string.appendSlice("bruh");
    return TokenTree{ .literal = string };
}

const TokenTree = union(enum) {
    group: ArrayList(TokenTree),
    literal: ArrayList(u8),

    fn deinit(self: TokenTree) void {
        switch (self) {
            .group => |array| {
                for (array.items) |item| {
                    item.deinit();
                }
                array.deinit();
            },
            .literal => |lit| lit.deinit(),
        }
    }
};

fn lex_tokens(file: *const fs.File, allocator: anytype) !ArrayList(Token) {
    var tokens = ArrayList(Token).init(allocator);
    var current_token = ArrayList(u8).init(allocator);

    var reader = file.reader();
    while (true) {
        const char = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        switch (char) {
            ' ', '(', ')' => {
                if (current_token.items.len > 0) {
                    try tokens.append(Token{ .literal = current_token });
                    current_token = ArrayList(u8).init(allocator);
                }
            },
            else => {},
        }

        switch (char) {
            '\n' => {},
            ' ' => {},
            '(' => {
                try tokens.append(Token.br_left);
            },
            ')' => {
                try tokens.append(Token.br_right);
            },
            else => try current_token.append(char),
        }
    }
    if (current_token.items.len > 0) {
        try tokens.append(Token{ .literal = current_token });
    }

    return tokens;
}

const Token = union(enum) {
    br_left,
    br_right,
    literal: ArrayList(u8),

    pub fn deinit(self: Token) void {
        switch (self) {
            Token.literal => |lit| lit.deinit(),
            else => {},
        }
    }

    pub fn format(
        self: Token,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            Token.literal => |lit| try writer.print("{s}", .{lit.items}),
            Token.br_left => try writer.writeAll("("),
            Token.br_right => try writer.writeAll(")"),
        }
    }
};
