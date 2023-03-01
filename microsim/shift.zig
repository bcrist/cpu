const bits = @import("bits");
const sim = @import("Simulator");
const ControlSignals = @import("ControlSignals");
const bus = @import("bus");

pub fn compute(in: Inputs) Outputs {
    const mode_bits = @bitCast(ControlSignals.ShiftModeBits, in.ALU_MODE.raw());

    const k0 = (in.k & 1) == 1;
    const k1 = (in.k & 2) == 2;
    const k2 = (in.k & 4) == 4;
    const k3 = (in.k & 8) == 8;
    const k4 = (in.k & 16) == 16;

    var j = @bitCast(u32, in.j);

    if (mode_bits.left) {
        j = bits.swapHalves(u32, @bitReverse(j));
    }

    if (mode_bits.wide and k4) {
        if (!mode_bits.early_swap16) {
            j = bits.swapHalves(u32, j);
        }
    } else if (mode_bits.early_swap16) {
        j = bits.swapHalves(u32, j);
    }

    var c: u1 = 0;

    if (mode_bits.wide and k4) {
        c = @truncate(u1, j >> 31);
        j = j & 0x0000_FFFF;
    }

    if (k2) {
        j >>= 3;
        c = @truncate(u1, j);
        j >>= 1;
    }
    if (k1) {
        j >>= 1;
        c = @truncate(u1, j);
        j >>= 1;
    }
    if (k0) {
        c = @truncate(u1, j);
        j >>= 1;
    }

    if (k3) {
        j >>= 7;
        c = @truncate(u1, j);
        j >>= 1;
    }

    if (mode_bits.late_swap16) {
        j = bits.swapHalves(u32, j);
    }

    if (mode_bits.left) {
        // reverse bits in top and lower halves of J:
        j = bits.swapHalves(u32, @bitReverse(j));
    }

    return .{
        .data = @bitCast(bus.LParts, j),
        .c = c != 0,
    };
}

pub const Inputs = struct {
    j: bus.JParts,
    k: u16,
    ALU_MODE: ControlSignals.ComputeMode,
};

pub const Outputs = struct {
    data: bus.LParts,
    c: bool,
};
