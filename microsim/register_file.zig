const std = @import("std");
const sim = @import("Simulator");
const bits = @import("bits");
const ControlSignals = @import("ControlSignals");
const misc = @import("misc");
const bus = @import("bus");

const RegistersetNumber = misc.RegistersetNumber;
const RegisterIndex = misc.RegisterIndex;

pub const State = struct {
    gpr_even: [512]u16,
    gpr_odd: [512]u16,
    sr1: [512]u32,
    sr2: [512]u32,

    pub fn reset(self: *State) void {
        self.gpr_even = .{0} ** 512;
        self.gpr_odd = .{0} ** 512;
        self.sr1 = .{0} ** 512;
        self.sr2 = .{0} ** 512;
    }

    pub fn randomize(self: *State, rnd: std.rand.Random) void {
        rnd.bytes(std.mem.sliceAsBytes(self.gpr_even[0..]));
        rnd.bytes(std.mem.sliceAsBytes(self.gpr_odd[0..]));
        rnd.bytes(std.mem.sliceAsBytes(self.sr1[0..]));
        rnd.bytes(std.mem.sliceAsBytes(self.sr2[0..]));
    }

    fn gprAddress(index: RegisterIndex, rsn: RegistersetNumber) u9 {
        return bits.concat2(@truncate(u3, index >> 1), rsn);
    }
    fn sr1Address(index: ControlSignals.SR1Index, rsn: RegistersetNumber) u9 {
        std.debug.assert(@bitSizeOf(ControlSignals.SR1Index) == 3);
        return bits.concat2(@enumToInt(index), rsn);
    }
    fn sr2Address(index: ControlSignals.SR2Index, rsn: RegistersetNumber) u9 {
        std.debug.assert(@bitSizeOf(ControlSignals.SR2Index) == 3);
        return bits.concat2(@enumToInt(index), rsn);
    }

    pub fn readEven(self: *const State, index: RegisterIndex, rsn: RegistersetNumber) u16 {
        return self.gpr_even[gprAddress(index, rsn)];
    }
    pub fn writeEven(self: *State, index: RegisterIndex, rsn: RegistersetNumber, value: u16) void {
        self.gpr_even[gprAddress(index, rsn)] = value;
    }

    pub fn readOdd(self: *const State, index: RegisterIndex, rsn: RegistersetNumber) u16 {
        return self.gpr_odd[gprAddress(index, rsn)];
    }
    pub fn writeOdd(self: *State, index: RegisterIndex, rsn: RegistersetNumber, value: u16) void {
        self.gpr_odd[gprAddress(index, rsn)] = value;
    }

    pub fn readSR1(self: *const State, index: ControlSignals.SR1Index, rsn: RegistersetNumber) u32 {
        return self.sr1[sr1Address(index, rsn)];
    }
    pub fn writeSR1(self: *State, index: ControlSignals.SR1Index, rsn: RegistersetNumber, value: u32) void {
        self.sr1[sr1Address(index, rsn)] = value;
    }

    pub fn readSR2(self: *const State, index: ControlSignals.SR2Index, rsn: RegistersetNumber) u32 {
        return self.sr2[sr2Address(index, rsn)];
    }
    pub fn writeSR2(self: *State, index: ControlSignals.SR2Index, rsn: RegistersetNumber, value: u32) void {
        self.sr2[sr2Address(index, rsn)] = value;
    }

    pub fn readSR(self: *const State, index: ControlSignals.AnySRIndex, rsn: RegistersetNumber) u32 {
        if (ControlSignals.addressBaseToSR1(index)) |sr1| {
            return self.readSR1(sr1, rsn);
        } else if (ControlSignals.addressBaseToSR2(index)) |sr2| {
            return self.readSR2(sr2, rsn);
        } else {
            unreachable;
        }
    }
    pub fn writeSR(self: *const State, index: ControlSignals.AnySRIndex, rsn: RegistersetNumber, value: u32) void {
        if (ControlSignals.addressBaseToSR1(index)) |sr1| {
            self.writeSR1(sr1, rsn, value);
        } else if (ControlSignals.addressBaseToSR2(index)) |sr2| {
            self.writeSR2(sr2, rsn, value);
        } else {
            unreachable;
        }
    }
};

pub const SetupInputs = struct {
    rsn: RegistersetNumber,
    oa: misc.OperandA,
    ob: misc.OperandB,
    JL_SRC: ControlSignals.JLSource,
    JH_SRC: ControlSignals.JHSource,
    K_SRC: ControlSignals.KSource,
    JR_RSEL: ControlSignals.RegFileIndexingSource,
    KR_RSEL: ControlSignals.RegFileIndexingSource,
    JR_RX: bool,
    KR_RX: bool,
    SR1_RI: ControlSignals.SR1Index,
    SR2_RI: ControlSignals.SR2Index,
    BASE: ControlSignals.AnySRIndex,
    LITERAL: ControlSignals.Literal,
};

pub const SetupOutputs = struct {
    j: bus.JParts,
    k: bus.K,
    sr1: bus.JParts,
    sr2: bus.JParts,
    address_base: bus.VirtualAddress,
};

pub const TransactInputs = struct {
    rsn: RegistersetNumber,
    read_rsn: RegistersetNumber,
    oa: misc.OperandA,
    ob: misc.OperandB,
    inhibit_writes: bool,
    l: bus.LParts,
    sr1: bus.JParts,
    sr2: bus.JParts,
    virtual_address: bus.VirtualAddressParts,
    JKR_WSEL: ControlSignals.RegFileIndexingSource,
    JKR_WMODE: ControlSignals.RegFileWriteMode,
    SR1_WSRC: ControlSignals.SR1WriteDataSource,
    SR2_WSRC: ControlSignals.SR2WriteDataSource,
    SR1_WI: ControlSignals.SR1Index,
    SR2_WI: ControlSignals.SR2Index,
    LITERAL: ControlSignals.Literal,
};

pub const RegisterView = struct {
    state: *State,
    rsn: RegistersetNumber,

    pub fn init(state: *State, rsn: RegistersetNumber) RegisterView {
        return .{
            .state = state,
            .rsn = rsn,
        };
    }

    pub fn readGPR(self: *const RegisterView, index: RegisterIndex) u16 {
        if ((index & 1) == 1) {
            return self.state.readOdd(index, self.rsn);
        } else {
            return self.state.readEven(index, self.rsn);
        }
    }
    pub fn writeGPR(self: *RegisterView, index: RegisterIndex, value: u16) void {
        if ((index & 1) == 1) {
            return self.state.writeOdd(index, self.rsn, value);
        } else {
            return self.state.writeEven(index, self.rsn, value);
        }
    }
    pub fn readSignedGPR(self: *const RegisterView, index: RegisterIndex) i16 {
        if ((index & 1) == 1) {
            return @bitCast(i16, self.state.readOdd(index, self.rsn));
        } else {
            return @bitCast(i16, self.state.readEven(index, self.rsn));
        }
    }
    pub fn writeSignedGPR(self: *RegisterView, index: RegisterIndex, value: i16) void {
        if ((index & 1) == 1) {
            return self.state.writeOdd(index, self.rsn, @bitCast(u16, value));
        } else {
            return self.state.writeEven(index, self.rsn, @bitCast(u16, value));
        }
    }

    pub fn readGPR32(self: *const RegisterView, index: RegisterIndex) u32 {
        return bits.concat(.{
            self.readGPR(index),
            self.readGPR(index ^ 1),
        });
    }
    pub fn writeGPR32(self: *RegisterView, index: RegisterIndex, value: u32) void {
        self.writeGPR(index, @truncate(u16, value));
        self.writeGPR(index ^ 1, @intCast(u16, value >> 16));
    }
    pub fn readSignedGPR32(self: *const RegisterView, index: RegisterIndex) i32 {
        return @bitCast(i32, bits.concat(.{
            self.readGPR(index),
            self.readGPR(index ^ 1),
        }));
    }
    pub fn writeSignedGPR32(self: *RegisterView, index: RegisterIndex, value: i32) void {
        const unsigned = @bitCast(u32, value);
        self.writeGPR(index, @truncate(u16, unsigned));
        self.writeGPR(index ^ 1, @intCast(u16, unsigned >> 16));
    }

    pub fn readSR(self: *const RegisterView, index: ControlSignals.AnySRIndex) u32 {
        return self.state.readSR(index, self.rsn);
    }
    pub fn writeSR(self: *RegisterView, index: ControlSignals.AnySRIndex, value: u32) void {
        return self.state.writeSR(index, self.rsn, value);
    }

    pub fn readSR1(self: *const RegisterView, index: ControlSignals.SR1Index) u32 {
        return self.state.readSR1(index, self.rsn);
    }
    pub fn writeSR1(self: *RegisterView, index: ControlSignals.SR1Index, value: u32) void {
        return self.state.writeSR1(index, self.rsn, value);
    }

    pub fn readSR2(self: *const RegisterView, index: ControlSignals.SR2Index) u32 {
        return self.state.readSR2(index, self.rsn);
    }
    pub fn writeSR2(self: *RegisterView, index: ControlSignals.SR2Index, value: u32) void {
        return self.state.writeSR2(index, self.rsn, value);
    }

    pub fn printRegs(self: *const RegisterView, writer: anytype) !void {
        try writer.print(" R1: {X:0>4}   R0: {X:0>4}      Z: {X:0>8}     Z: {X:0>8}\n", .{
            self.readGPR(1), self.readGPR(0), self.readSR1(.zero), self.readSR2(.zero),
        });
        try writer.print(" R3: {X:0>4}   R2: {X:0>4}     RP: {X:0>8}    IP: {X:0>8}\n", .{
            self.readGPR(3), self.readGPR(2), self.readSR1(.rp), self.readSR2(.ip),
        });
        try writer.print(" R5: {X:0>4}   R4: {X:0>4}     SP: {X:0>8}   NIP: {X:0>8}\n", .{
            self.readGPR(5), self.readGPR(4), self.readSR1(.sp), self.readSR2(.next_ip),
        });
        try writer.print(" R7: {X:0>4}   R6: {X:0>4}     BP: {X:0>8}   ASN: {X:0>8}\n", .{
            self.readGPR(7), self.readGPR(6), self.readSR1(.bp), self.readSR2(.asn),
        });
        try writer.print(" R9: {X:0>4}   R8: {X:0>4}   UADL: {X:0>8}   KXP: {X:0>8}\n", .{
            self.readGPR(9), self.readGPR(8), self.readSR1(.fault_ua_dl), self.readSR2(.kxp),
        });
        try writer.print("R11: {X:0>4}  R10: {X:0>4}  RSTAT: {X:0>8}   UXP: {X:0>8}\n", .{
            self.readGPR(11), self.readGPR(10), self.readSR1(.fault_rsn_stat), self.readSR2(.uxp),
        });
        try writer.print("R13: {X:0>4}  R12: {X:0>4}  ROBOA: {X:0>8}   RSR: {X:0>8}\n", .{
            self.readGPR(13), self.readGPR(12), self.readSR1(.int_rsn_fault_ob_oa), self.readSR2(.rs_reserved),
        });
        try writer.print("R15: {X:0>4}  R14: {X:0>4}   TMP1: {X:0>8}  TMP2: {X:0>8}\n", .{
            self.readGPR(15), self.readGPR(14), self.readSR1(.temp_1), self.readSR2(.temp_2),
        });
    }
};

pub fn setup(state: *const State, in: SetupInputs) SetupOutputs {
    const jr_index: RegisterIndex = switch (in.JR_RSEL) {
        .zero => 0,
        .literal => @truncate(RegisterIndex, in.LITERAL),
        .oa => in.oa,
        .ob => in.ob,
    };
    const kr_index: RegisterIndex = switch (in.KR_RSEL) {
        .zero => 0,
        .literal => @truncate(RegisterIndex, in.LITERAL),
        .oa => in.oa,
        .ob => in.ob,
    };

    var jr_swap = @truncate(u1, jr_index) == 1;
    if (in.JR_RX) {
        jr_swap = !jr_swap;
    }

    var kr_swap = @truncate(u1, kr_index) == 1;
    if (in.KR_RX) {
        kr_swap = !kr_swap;
    }

    const jr = if (jr_swap) blk: {
        break :blk bus.JParts{
            .low = state.readOdd(jr_index, in.rsn),
            .high = state.readEven(jr_index, in.rsn),
        };
    } else blk: {
        break :blk bus.JParts{
            .low = state.readEven(jr_index, in.rsn),
            .high = state.readOdd(jr_index, in.rsn),
        };
    };

    const kr = if (kr_swap) blk: {
        break :blk state.readOdd(kr_index, in.rsn);
    } else blk: {
        break :blk state.readEven(kr_index, in.rsn);
    };

    const sr1 = @bitCast(bus.JParts, state.readSR1(in.SR1_RI, in.rsn));
    const sr2 = @bitCast(bus.JParts, state.readSR2(in.SR2_RI, in.rsn));

    return .{
        .j = .{
            .low = switch (in.JL_SRC) {
                .zero => 0,
                .jrl => jr.low,
                .sr1l => sr1.low,
                .sr2l => sr2.low,
            },
            .high = switch (in.JH_SRC) {
                .zero => 0,
                .neg_one => 0xFFFF,
                .sx_jl => bits.sx(u16, switch (in.JL_SRC) {
                    .zero => @as(u1, 0),
                    .jrl => @intCast(u1, jr.low >> 15),
                    .sr1l => @intCast(u1, sr1.low >> 15),
                    .sr2l => @intCast(u1, sr2.low >> 15),
                }),
                .jrl => jr.low,
                .jrh => jr.high,
                .sr1h => sr1.high,
                .sr2h => sr2.high,
            },
        },
        .k = switch (in.K_SRC) {
            .zero             => 0,
            .kr               => kr,
            .sr1l             => sr1.low,
            .sr2l             => sr2.low,
            .ob_oa_zx         => bits.zx(u16, bits.concat2(in.oa, in.ob)),
            .literal          => bits.zx(u16, in.LITERAL),
            .literal_minus_64 => bits._1x(u16, in.LITERAL),
            .literal_special  => bits.concat(.{
                @as(u6, 0),
                @truncate(u7, @shlExact(@as(u8, 1), @truncate(u3, in.LITERAL))),
                @truncate(u3, in.LITERAL >> 3),
            }),
        },
        .sr1 = @bitCast(bus.JParts, sr1),
        .sr2 = @bitCast(bus.JParts, sr2),
        .address_base = state.readSR(in.BASE, in.rsn),
    };
}

pub fn transact(state: *State, in: TransactInputs) void {
    if (in.inhibit_writes) {
        return;
    }

    const jkr_index: RegisterIndex = switch (in.JKR_WSEL) {
        .zero => 0,
        .literal => @truncate(RegisterIndex, in.LITERAL),
        .oa => in.oa,
        .ob => in.ob,
    };

    const odd_register = (jkr_index & 1) == 1;
    switch (in.JKR_WMODE) {
        .no_write => {},
        .write_16 => {
            if (odd_register) {
                state.writeOdd(jkr_index, in.rsn, in.l.low);
            } else {
                state.writeEven(jkr_index, in.rsn, in.l.low);
            }
        },
        .write_16_xor1 => {
            if (odd_register) {
                state.writeEven(jkr_index, in.rsn, in.l.low);
            } else {
                state.writeOdd(jkr_index, in.rsn, in.l.low);
            }
        },
        .write_32 => {
            if (odd_register) {
                state.writeOdd(jkr_index, in.rsn, in.l.low);
                state.writeEven(jkr_index, in.rsn, in.l.high);
            } else {
                state.writeEven(jkr_index, in.rsn, in.l.low);
                state.writeOdd(jkr_index, in.rsn, in.l.high);
            }
        },
    }

    switch (in.SR1_WSRC) {
        .no_write => {},
        .rsn_sr1 => {
            const val = bits.concat2(@truncate(u16, @bitCast(u32, in.sr1)), @as(u16, in.read_rsn));
            state.writeSR1(in.SR1_WI, in.rsn, val);
        },
        .l_bus => state.writeSR1(in.SR1_WI, in.rsn, @bitCast(u32, in.l)),
        .virtual_address => state.writeSR1(in.SR1_WI, in.rsn, @bitCast(u32, in.virtual_address)),
    }

    switch (in.SR2_WSRC) {
        .no_write => {},
        .sr2 => state.writeSR2(in.SR2_WI, in.rsn, @bitCast(u32, in.sr2)),
        .l_bus => state.writeSR2(in.SR2_WI, in.rsn, @bitCast(u32, in.l)),
        .virtual_address => state.writeSR2(in.SR2_WI, in.rsn, @bitCast(u32, in.virtual_address)),
    }
}
