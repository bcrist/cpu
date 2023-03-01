const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    //[[!! include 'build' !! 209 ]]
    //[[ ################# !! GENERATED CODE -- DO NOT MODIFY !! ################# ]]

    const bits = b.createModule(.{
        .source_file = .{ .path = "pkg/bits.zig" },
    });

    const bus = b.createModule(.{
        .source_file = .{ .path = "arch/bus.zig" },
    });

    const misc = b.createModule(.{
        .source_file = .{ .path = "arch/misc.zig" },
        .dependencies = &.{
            .{ .name = "bus", .module = bus },
        },
    });

    const microcode = b.createModule(.{
        .source_file = .{ .path = "arch/microcode.zig" },
        .dependencies = &.{
            .{ .name = "bits", .module = bits },
            .{ .name = "misc", .module = misc },
        },
    });

    const ControlSignals = b.createModule(.{
        .source_file = .{ .path = "arch/ControlSignals.zig" },
        .dependencies = &.{
            .{ .name = "microcode", .module = microcode },
            .{ .name = "misc", .module = misc },
        },
    });

    const Simulator = b.createModule(.{
        .source_file = .{ .path = "microsim/Simulator.zig" },
    });

    const physical_address = b.createModule(.{
        .source_file = .{ .path = "arch/physical_address.zig" },
        .dependencies = &.{
            .{ .name = "bus", .module = bus },
        },
    });

    const register_file = b.createModule(.{
        .source_file = .{ .path = "microsim/register_file.zig" },
        .dependencies = &.{
            .{ .name = "ControlSignals", .module = ControlSignals },
            .{ .name = "Simulator", .module = Simulator },
            .{ .name = "bits", .module = bits },
            .{ .name = "bus", .module = bus },
            .{ .name = "misc", .module = misc },
        },
    });

    Simulator.dependencies.put("ControlSignals", ControlSignals) catch unreachable;
    Simulator.dependencies.put("Simulator", Simulator) catch unreachable;
    Simulator.dependencies.put("bits", bits) catch unreachable;
    Simulator.dependencies.put("bus", bus) catch unreachable;
    Simulator.dependencies.put("microcode", microcode) catch unreachable;
    Simulator.dependencies.put("misc", misc) catch unreachable;
    Simulator.dependencies.put("physical_address", physical_address) catch unreachable;
    Simulator.dependencies.put("register_file", register_file) catch unreachable;

    const deep_hash_map = b.createModule(.{
        .source_file = .{ .path = "pkg/deep_hash_map.zig" },
    });

    const sx = b.createModule(.{
        .source_file = .{ .path = "pkg/sx/sx.zig" },
    });

    const instruction_encoding = b.createModule(.{
        .source_file = .{ .path = "arch/instruction_encoding.zig" },
        .dependencies = &.{
            .{ .name = "ControlSignals", .module = ControlSignals },
            .{ .name = "bits", .module = bits },
            .{ .name = "deep_hash_map", .module = deep_hash_map },
            .{ .name = "microcode", .module = microcode },
            .{ .name = "misc", .module = misc },
            .{ .name = "sx", .module = sx },
        },
    });

    const instruction_encoding_data = b.createModule(.{
        .source_file = .{ .path = "arch/instruction_encoding_data.zig" },
    });

    const rom_compress = b.createModule(.{
        .source_file = .{ .path = "pkg/rom_compress.zig" },
        .dependencies = &.{
            .{ .name = "bits", .module = bits },
        },
    });

    const rom_decompress = b.createModule(.{
        .source_file = .{ .path = "pkg/rom_decompress.zig" },
        .dependencies = &.{
            .{ .name = "bits", .module = bits },
            .{ .name = "rom_compress", .module = rom_compress },
        },
    });

    const srec = b.createModule(.{
        .source_file = .{ .path = "pkg/srec.zig" },
    });

    const microcode_rom_serialization = b.createModule(.{
        .source_file = .{ .path = "arch/microcode_rom_serialization.zig" },
        .dependencies = &.{
            .{ .name = "ControlSignals", .module = ControlSignals },
            .{ .name = "microcode", .module = microcode },
            .{ .name = "misc", .module = misc },
            .{ .name = "rom_compress", .module = rom_compress },
            .{ .name = "rom_decompress", .module = rom_decompress },
            .{ .name = "srec", .module = srec },
        },
    });

    const microcode_roms = b.createModule(.{
        .source_file = .{ .path = "arch/microcode_roms/roms.zig" },
    });

    const temp_allocator = b.createModule(.{
        .source_file = .{ .path = "pkg/tempallocator/temp_allocator.zig" },
    });

    const compile_arch = b.addExecutable(.{
        .name = "compile_arch",
        .root_source_file = .{ .path = "arch/compile_arch.zig" },
        .target = target,
        .optimize = mode,
    });
    compile_arch.addModule("ControlSignals", ControlSignals);
    compile_arch.addModule("bits", bits);
    compile_arch.addModule("instruction_encoding", instruction_encoding);
    compile_arch.addModule("microcode", microcode);
    compile_arch.addModule("misc", misc);
    compile_arch.addModule("physical_address", physical_address);
    compile_arch.addModule("rom_compress", rom_compress);
    compile_arch.addModule("rom_decompress", rom_decompress);
    compile_arch.addModule("srec", srec);
    compile_arch.addModule("sx", sx);
    compile_arch.addModule("temp_allocator", temp_allocator);
    compile_arch.install();
    _ = makeRunStep(b, compile_arch, "uc", "run compile_arch");

    const microsim = b.addExecutable(.{
        .name = "microsim",
        .root_source_file = .{ .path = "microsim/microsim.zig" },
        .target = target,
        .optimize = mode,
    });
    microsim.addModule("ControlSignals", ControlSignals);
    microsim.addModule("Simulator", Simulator);
    microsim.addModule("instruction_encoding", instruction_encoding);
    microsim.addModule("instruction_encoding_data", instruction_encoding_data);
    microsim.addModule("microcode_rom_serialization", microcode_rom_serialization);
    microsim.addModule("microcode_roms", microcode_roms);
    microsim.addModule("misc", misc);
    microsim.install();
    _ = makeRunStep(b, microsim, "usim", "run microsim");

    const tests1 = b.addTest(.{
        .root_source_file = .{ .path = "arch/test_instruction_encoding.zig"},
        .target = target,
        .optimize = mode,
    });
    tests1.addModule("instruction_encoding", instruction_encoding);
    tests1.addModule("instruction_encoding_data", instruction_encoding_data);

    const tests2 = b.addTest(.{
        .root_source_file = .{ .path = "arch/test_instruction_behavior.zig"},
        .target = target,
        .optimize = mode,
    });
    tests2.addModule("ControlSignals", ControlSignals);
    tests2.addModule("Simulator", Simulator);
    tests2.addModule("instruction_encoding", instruction_encoding);
    tests2.addModule("instruction_encoding_data", instruction_encoding_data);
    tests2.addModule("microcode", microcode);
    tests2.addModule("misc", misc);
    tests2.addModule("register_file", register_file);
    tests2.addModule("rom_compress", rom_compress);
    tests2.addModule("rom_decompress", rom_decompress);
    tests2.addModule("srec", srec);

    const tests3 = b.addTest(.{
        .root_source_file = .{ .path = "pkg/bits.zig"},
        .target = target,
        .optimize = mode,
    });

    const tests4 = b.addTest(.{
        .root_source_file = .{ .path = "pkg/rom_decompress.zig"},
        .target = target,
        .optimize = mode,
    });
    tests4.addModule("bits", bits);
    tests4.addModule("rom_compress", rom_compress);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&tests1.step);
    test_step.dependOn(&tests2.step);
    test_step.dependOn(&tests3.step);
    test_step.dependOn(&tests4.step);

    //[[ ######################### END OF GENERATED CODE ######################### ]]
}

fn makeRunStep(b: *std.build.Builder, exe: *std.build.LibExeObjStep, name: []const u8, desc: []const u8) *std.build.RunStep {
    var run = exe.run();
    run.step.dependOn(b.getInstallStep());
    b.step(name, desc).dependOn(&run.step);
    return run;
}
