const sim = @import("simulator");
const ctrl = @import("control_signals");

pub const ComputeInputs = struct {
    page_fault: bool,
    page_align_fault: bool,
    access_fault: bool,
    SPECIAL: ctrl.Special_Op,
};

pub const ComputeOutputs = struct {
    any: bool,
    page: bool,
    page_align: bool,
    access: bool,
    special: bool,
};

pub fn compute(in: ComputeInputs) ComputeOutputs {
    const special = in.SPECIAL == .trigger_fault;
    return .{
        .any = in.page_fault or in.page_align_fault or in.access_fault or special,
        .page = in.page_fault,
        .page_align = in.page_align_fault,
        .access = in.access_fault,
        .special = special,
    };
}
