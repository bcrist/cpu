const sim = @import("Simulator");
const ctrl = @import("control_signals");
const misc = @import("misc");
const bus = @import("bus");

pub fn compute(in: Inputs) Outputs {
    const mode_bits = @bitCast(ctrl.Logic_Mode_Bits, in.ALU_MODE.raw());
    const j = if (mode_bits.invert_JL) ~in.j.low else in.j.low;
    const k = if (mode_bits.invert_K) ~in.k else in.k;
    const y = if (mode_bits.xor) (j ^ k) else (j & k);
    return .{
        .data = .{
            .low = (if (mode_bits.invert_Y) ~y else y),
            .high = in.j.high,
        },
    };
}

pub const Inputs = struct {
    j: bus.JParts,
    k: bus.K,
    ALU_MODE: ctrl.ALU_Mode,
};

pub const Outputs = struct {
    data: bus.LParts,
};
