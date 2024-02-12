const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const panic = std.debug.panic;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = "example";
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var tokens = try lex_tokens(&file, allocator);
    defer tokens.deinit();
    defer for (tokens.items) |token| {
        token.deinit();
    };

    for (tokens.items) |token| {
        print("Token: {}\n", .{token});
    }

    print("\n", .{});
    var index: usize = 0;
    const tree = try parse_tree(&tokens, &index, 0, allocator);
    defer tree.deinit();
    print("\n", .{});
    tree.debug_print(0);
}

fn parse_tree(tokens: *ArrayList(Token), index: *usize, depth: usize, allocator: anytype) !TokenTree {
    if (depth > 20) {
        panic("max recursion for parse_tree", .{});
    }

    if (tokens.items.len == 0) {
        return error.NoTokens;
    }
    if (tokens.items.len == 1) {
        const token = tokens.items[0];
        switch (token) {
            .literal => |lit| {
                return TokenTree{ .literal = lit };
            },
            else => return error.SingleBracket,
        }
    }

    var group = ArrayList(TokenTree).init(allocator);

    while (index.* < tokens.items.len) {
        const token = tokens.items[index.*];
        index.* += 1;

        print("{?}\n", .{token});
        switch (token) {
            .literal => |lit| {
                var literal = ArrayList(u8).init(allocator);
                try literal.appendSlice(lit.items);
                try group.append(TokenTree{ .literal = literal });
            },
            .br_left => {
                const subgroup = try parse_tree(tokens, index, depth + 1, allocator);
                try group.append(subgroup);
            },
            .br_right => {
                if (depth == 0) {
                    return error.UnexpectedRightBracket;
                }
                return TokenTree{ .group = group };
            },
        }
    }

    if (depth > 0) {
        return error.UnexpectedEndOfStream;
    }

    return TokenTree{ .group = group };
}

// var a = ArrayList(TokenTree).init(allocator);
// try a.append(TokenTree{ .literal = try string("*", allocator) });
// var b = ArrayList(TokenTree).init(allocator);
// try b.append(TokenTree{ .literal = try string("+", allocator) });
// try b.append(TokenTree{ .literal = try string("12", allocator) });
// try b.append(TokenTree{ .literal = try string("3", allocator) });
// try a.append(TokenTree{ .group = b });
// try a.append(TokenTree{ .literal = try string("81", allocator) });
// return TokenTree{ .group = a };

fn string(comptime literal: []const u8, allocator: anytype) !ArrayList(u8) {
    var array = ArrayList(u8).init(allocator);
    try array.appendSlice(literal);
    return array;
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

    fn debug_print(self: TokenTree, comptime depth: usize) void {
        if (depth > 20) {
            panic("max recursion for debug_print", .{});
        }
        switch (self) {
            .group => |array| {
                print("{s}", .{"    " ** depth});
                print("\x1b[33m", .{});
                print("(\n", .{});
                print("\x1b[0m", .{});
                for (array.items) |item| {
                    debug_print(item, depth + 1);
                }
                print("{s}", .{"    " ** depth});
                print("\x1b[33m", .{});
                print(")\n", .{});
                print("\x1b[0m", .{});
            },
            .literal => |lit| {
                print("{s}", .{"    " ** depth});
                print("{s}\n", .{lit.items});
            },
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
