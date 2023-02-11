const std = @import("std");
const builtin = @import("builtin");
const Log2Int = std.math.Log2Int;
const native_endian = builtin.cpu.arch.endian();
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    // symbol compatibility with libgcc
    @export(__ashlsi3, .{ .name = "__ashlsi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(__ashrsi3, .{ .name = "__ashrsi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(__lshrsi3, .{ .name = "__lshrsi3", .linkage = common.linkage, .visibility = common.visibility });

    @export(__ashlti3, .{ .name = "__ashlti3", .linkage = common.linkage, .visibility = common.visibility });
    @export(__ashrti3, .{ .name = "__ashrti3", .linkage = common.linkage, .visibility = common.visibility });
    @export(__lshrti3, .{ .name = "__lshrti3", .linkage = common.linkage, .visibility = common.visibility });

    if (common.want_aeabi) {
        @export(__aeabi_llsl, .{ .name = "__aeabi_llsl", .linkage = common.linkage, .visibility = common.visibility });
        @export(__aeabi_lasr, .{ .name = "__aeabi_lasr", .linkage = common.linkage, .visibility = common.visibility });
        @export(__aeabi_llsr, .{ .name = "__aeabi_llsr", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__ashldi3, .{ .name = "__ashldi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__ashrdi3, .{ .name = "__ashrdi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(__lshrdi3, .{ .name = "__lshrdi3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn Dwords(comptime T: type, comptime signed_half: bool) type {
    return extern union {
        const bits = @divExact(@typeInfo(T).Int.bits, 2);
        const HalfTU = std.meta.Int(.unsigned, bits);
        const HalfTS = std.meta.Int(.signed, bits);
        const HalfT = if (signed_half) HalfTS else HalfTU;

        all: T,
        s: if (native_endian == .Little)
            extern struct { low: HalfT, high: HalfT }
        else
            extern struct { high: HalfT, low: HalfT },
    };
}

// Arithmetic shift left: shift in 0 from right to left
// Precondition: 0 <= b < bits_in_dword
inline fn ashlXi3(comptime T: type, a: T, b: i32) T {
    const dwords = Dwords(T, false);
    const S = Log2Int(dwords.HalfT);

    const input = dwords{ .all = a };
    var output: dwords = undefined;

    if (b >= dwords.bits) {
        output.s.low = 0;
        output.s.high = input.s.low << @intCast(S, b - dwords.bits);
    } else if (b == 0) {
        return a;
    } else {
        output.s.low = input.s.low << @intCast(S, b);
        output.s.high = input.s.high << @intCast(S, b);
        output.s.high |= input.s.low >> @intCast(S, dwords.bits - b);
    }

    return output.all;
}

// Arithmetic shift right: shift in 1 from left to right
// Precondition: 0 <= b < T.bit_count
inline fn ashrXi3(comptime T: type, a: T, b: i32) T {
    const dwords = Dwords(T, true);
    const S = Log2Int(dwords.HalfT);

    const input = dwords{ .all = a };
    var output: dwords = undefined;

    if (b >= dwords.bits) {
        output.s.high = input.s.high >> (dwords.bits - 1);
        output.s.low = input.s.high >> @intCast(S, b - dwords.bits);
    } else if (b == 0) {
        return a;
    } else {
        output.s.high = input.s.high >> @intCast(S, b);
        output.s.low = input.s.high << @intCast(S, dwords.bits - b);
        // Avoid sign-extension here
        output.s.low |= @bitCast(
            dwords.HalfT,
            @bitCast(dwords.HalfTU, input.s.low) >> @intCast(S, b),
        );
    }

    return output.all;
}

// Logical shift right: shift in 0 from left to right
// Precondition: 0 <= b < T.bit_count
inline fn lshrXi3(comptime T: type, a: T, b: i32) T {
    const dwords = Dwords(T, false);
    const S = Log2Int(dwords.HalfT);

    const input = dwords{ .all = a };
    var output: dwords = undefined;

    if (b >= dwords.bits) {
        output.s.high = 0;
        output.s.low = input.s.high >> @intCast(S, b - dwords.bits);
    } else if (b == 0) {
        return a;
    } else {
        output.s.high = input.s.high >> @intCast(S, b);
        output.s.low = input.s.high << @intCast(S, dwords.bits - b);
        output.s.low |= input.s.low >> @intCast(S, b);
    }

    return output.all;
}

pub fn __ashlsi3(a: i32, b: i32) callconv(.C) i32 {
    return ashlXi3(i32, a, b);
}

pub fn __ashrsi3(a: i32, b: i32) callconv(.C) i32 {
    return ashrXi3(i32, a, b);
}

pub fn __lshrsi3(a: i32, b: i32) callconv(.C) i32 {
    return lshrXi3(i32, a, b);
}

pub fn __ashldi3(a: i64, b: i32) callconv(.C) i64 {
    return ashlXi3(i64, a, b);
}
fn __aeabi_llsl(a: i64, b: i32) callconv(.AAPCS) i64 {
    return ashlXi3(i64, a, b);
}

pub fn __ashlti3(a: i128, b: i32) callconv(.C) i128 {
    return ashlXi3(i128, a, b);
}

pub fn __ashrdi3(a: i64, b: i32) callconv(.C) i64 {
    return ashrXi3(i64, a, b);
}
fn __aeabi_lasr(a: i64, b: i32) callconv(.AAPCS) i64 {
    return ashrXi3(i64, a, b);
}

pub fn __ashrti3(a: i128, b: i32) callconv(.C) i128 {
    return ashrXi3(i128, a, b);
}

pub fn __lshrdi3(a: i64, b: i32) callconv(.C) i64 {
    return lshrXi3(i64, a, b);
}
fn __aeabi_llsr(a: i64, b: i32) callconv(.AAPCS) i64 {
    return lshrXi3(i64, a, b);
}

pub fn __lshrti3(a: i128, b: i32) callconv(.C) i128 {
    return lshrXi3(i128, a, b);
}

test {
    _ = @import("shift_test.zig");
}
