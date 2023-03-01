const bits = @import("bits");
const sim = @import("Simulator");
const ControlSignals = @import("ControlSignals");
const misc = @import("misc");
const bus = @import("bus");

pub fn compute(in: Inputs) Outputs {
    const mode_bits = @bitCast(ControlSignals.MultModeBits, in.ALU_MODE.raw());

    const j = switch (mode_bits.jl) {
        .unsigned => bits.zx(i64, in.j),
        .signed => bits.sx(i64, in.j),
    };

    const k = switch (mode_bits.k) {
        .unsigned => bits.zx(i64, in.k),
        .signed => bits.sx(i64, in.k),
    };

    var result = @bitCast(bus.LParts, @truncate(u32, @bitCast(u64, j * k)));

    if (mode_bits.swap_output) {
        result = .{
            .low = result.high,
            .high = result.low,
        };
    }

    return .{ .data = result };
}

pub const Inputs = struct {
    j: bus.JLow,
    k: bus.K,
    ALU_MODE: ControlSignals.ComputeMode,
};

pub const Outputs = struct {
    data: bus.LParts,
};
