const ControlSignals = @import("ControlSignals");
const faults = @import("faults.zig");
const uc = @import("microcode");
const misc = @import("misc");
const bus = @import("bus_types");

pub const TransactInputs = struct {
    exec_mode: misc.ExecutionMode,
    ua: uc.Address,
    reset: bool,
    want_atomic: bool,
    stall_atomic: bool,
    fault: faults.ComputeOutputs,
    interrupt_pending: bool,
    flags: uc.FlagSet,
    dl: bus.D,
    lh: bus.LHigh,
    cs_allow_int: bool,
    cs_seq_op: ControlSignals.SequencerOp,
    cs_next_uop: uc.Continuation,
    cs_special: ControlSignals.SpecialOp,
};

pub const UASource = enum {
    reset,
    stall,
    fault,
    interrupt,
    continuation,
    opcode,
    lh,
};

pub const TransactOutputs = struct {
    exec_mode: misc.ExecutionMode,
    ua: uc.Address,
    ua_src: UASource,
};

pub fn getForTransact(in: TransactInputs) TransactOutputs {
    return if (in.reset) .{
        .exec_mode = .interrupt_fault,
        .ua = @enumToInt(uc.Vectors.reset),
        .ua_src = .reset,
    } else if (in.stall_atomic) .{
        .exec_mode = in.exec_mode,
        .ua = in.ua,
        .ua_src = .stall,
    } else switch (in.exec_mode) {
        .normal, .interrupt => if (in.fault.any) .{
            .exec_mode = switch (in.exec_mode) {
                .normal => .fault,
                .interrupt => .interrupt_fault,
                else => unreachable,
            },
            .ua = if (in.fault.page) @enumToInt(uc.Vectors.page_fault)
                else if (in.fault.access) @enumToInt(uc.Vectors.access_fault)
                else if (in.fault.page_align) @enumToInt(uc.Vectors.page_align_fault)
                else if (in.fault.special) uc.getAddressForContinuation(in.cs_next_uop, in.flags)
                else undefined,
            .ua_src = .fault,
        } else if (in.exec_mode == .normal and in.interrupt_pending and in.cs_allow_int and !in.want_atomic) .{
            .exec_mode = .interrupt,
            .ua = @enumToInt(uc.Vectors.interrupt),
            .ua_src = .interrupt,
        } else switch (in.cs_seq_op) {
            .next_uop => .{
                .exec_mode = in.exec_mode,
                .ua = uc.getAddressForContinuation(in.cs_next_uop, in.flags),
                .ua_src = .continuation,
            },
            .next_uop_force_normal => .{
                .exec_mode = .normal,
                .ua = uc.getAddressForContinuation(in.cs_next_uop, in.flags),
                .ua_src = .continuation,
            },
            .next_instruction => .{
                .exec_mode = in.exec_mode,
                .ua = uc.getAddressForOpcode(in.dl, in.flags),
                .ua_src = .opcode,
            },
            .fault_return => .{
                .exec_mode = .fault,
                .ua = @enumToInt(uc.Vectors.instruction_protection_fault),
                .ua_src = .fault,
            },
        },
        .fault, .interrupt_fault => if (in.fault.any) .{
            .exec_mode = in.exec_mode,
            .ua = @enumToInt(uc.Vectors.double_fault),
            .ua_src = .fault,
        } else switch (in.cs_seq_op) {
            .next_uop => .{
                .exec_mode = in.exec_mode,
                .ua = uc.getAddressForContinuation(in.cs_next_uop, in.flags),
                .ua_src = .continuation,
            },
            .next_instruction => .{
                .exec_mode = in.exec_mode,
                .ua = uc.getAddressForOpcode(in.dl, in.flags),
                .ua_src = .opcode,
            },
            .next_uop_force_normal => .{
                .exec_mode = .normal,
                .ua = uc.getAddressForContinuation(in.cs_next_uop, in.flags),
                .ua_src = .continuation,
            },
            .fault_return => .{
                .exec_mode = switch (in.exec_mode) {
                    .fault => .normal,
                    .interrupt_fault => .interrupt,
                    else => unreachable,
                },
                .ua = in.lh,
                .ua_src = .lh,
            },
        },
    };
}
