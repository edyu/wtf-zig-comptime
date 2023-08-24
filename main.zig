const std = @import("std");

pub inline fn square(x: i32) i32 {
    return x * x;
}

pub fn squareComptime(comptime x: comptime_int) comptime_int {
    return x * x;
}

pub inline fn squareNoOverflow(x: i32) u64 {
    return @intCast(std.math.mulWide(i32, x, x));
}

pub inline fn min(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

pub inline fn minComptime(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return if (a < b) a else b;
}

pub fn factorial(comptime n: u8) comptime_int {
    var r = 1;
    inline for (1..(n + 1)) |i| {
        r *= i;
    }
    return r;
}

pub fn numChosen(comptime m: u8, comptime n: u8) comptime_int {
    return factorial(m) / (factorial(n) * factorial(m - n));
}

pub fn ChosenType(comptime m: u8, comptime n: u8) type {
    comptime var t = numChosen(m, n);
    return [t][n]u8;
}

pub fn choose(comptime l: []const u8, comptime k: u8) ChosenType(l.len, k) {
    std.debug.assert(l.len >= k);
    std.debug.assert(k > 0);

    var ret: ChosenType(l.len, k) = std.mem.zeroes(ChosenType(l.len, k));

    if (k == 1) {
        inline for (0..l.len) |i| {
            ret[i] = [k]u8{l[i]};
        }
        return ret;
    }
    comptime var c = choose(l[1..], k - 1);
    comptime var i = 0;
    inline for (0..(l.len - 1)) |m| {
        inline for (0..c.len) |n| {
            if (l[m] < c[n][0]) {
                ret[i][0] = l[m];
                inline for (0..c[n].len) |j| {
                    ret[i][j + 1] = c[n][j];
                }
                i += 1;
            }
        }
    }
    return ret;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("arg = {s}\n", .{args[1]});
    var x = try std.fmt.parseInt(i32, args[1], 10);
    std.debug.print("x = {d}\n", .{x});
    var y = squareNoOverflow(x);
    std.debug.print("square = {d}\n", .{y});
    const z = comptime factorial(10);
    std.debug.print("10! = {d}\n", .{z});
}

test "square" {
    try std.testing.expectEqual(9, square(3));
    try std.testing.expectEqual(25, square(3 + 2));
}

test "squareComptime" {
    try std.testing.expectEqual(9, squareComptime(3));
    try std.testing.expectEqual(25, squareComptime(3 + 2));
}

test "min" {
    try std.testing.expectEqual(min(2, 3), 2);
    try std.testing.expectEqual(min(3, 3), 3);
    try std.testing.expectEqual(min(-1, -3), -3);
}

test "minComptime" {
    try std.testing.expectEqual(minComptime(2, 3), 2);
    try std.testing.expectEqual(minComptime(3, 3), 3);
    try std.testing.expectEqual(minComptime(-1, -3), -3);
}

test "comptime" {
    comptime var y = squareComptime(1337);
    comptime var z = minComptime(y, 1337);
    try std.testing.expectEqual(z, 1337);
}

test "factorial" {
    try std.testing.expectEqual(factorial(5), 120);
    try std.testing.expectEqual(factorial(10), 3628800);
}

test "x choose 3" {
    var list7 = choose(&[_]u8{ 7, 8, 9 }, 3);
    try std.testing.expectEqual(list7.len, 1);
    try std.testing.expectEqual(list7[0], [3]u8{ 7, 8, 9 });

    var list8 = choose(&[_]u8{ 6, 7, 8, 9 }, 3);
    try std.testing.expectEqual(list8.len, 4);
    try std.testing.expectEqual(list8[0], [3]u8{ 6, 7, 8 });
    try std.testing.expectEqual(list8[1], [3]u8{ 6, 7, 9 });
    try std.testing.expectEqual(list8[2], [3]u8{ 6, 8, 9 });
    try std.testing.expectEqual(list8[3], [3]u8{ 7, 8, 9 });
}
