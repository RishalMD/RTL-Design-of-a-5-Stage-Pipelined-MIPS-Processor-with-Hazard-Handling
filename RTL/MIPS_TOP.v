module MIPS_TOP(

    input clk,
    input reset

);

//====================================================
// IF <-> ID wires
//====================================================
wire [31:0] instruction_address_bus;
wire [31:0] instruction_bus;

wire [31:0] IF_ID_IR;
wire [31:0] IF_ID_NPC;

//====================================================
// ID <-> EX wires
//====================================================
wire [31:0] ID_EX_A;
wire [31:0] ID_EX_B;
wire [31:0] ID_EX_NPC;
wire [31:0] ID_EX_IR;
wire [31:0] ID_EX_Imm;

//====================================================
// EX <-> MEM wires
//====================================================
wire [31:0] EX_MEM_IR;
wire [31:0] EX_MEM_ALUOUT;
wire [31:0] EX_MEM_B;
wire        EX_MEM_COND;

//====================================================
// MEM <-> WB wires
//====================================================
wire [31:0] MEM_WB_IR;
wire [31:0] MEM_WB_ALUOUT;
wire [31:0] MEM_WB_LMD;

//====================================================
// WB -> ID (register writeback) wires
//====================================================
wire        reg_update_flag;
wire [4:0]  reg_update_address;
wire [31:0] reg_update_data;

//====================================================
// MEM <-> DATA_MEMORY wires
//====================================================
wire [31:0] data_bus_address;
wire        read_enable;
wire        write_enable;
wire [31:0] data_write_data;
wire [31:0] data_bus;

//====================================================
// Hazard / Forwarding control wires
//====================================================
wire        load_hazard;
wire [1:0]  ForwardA;
wire [1:0]  ForwardB;

//====================================================
// Branch control wires
//====================================================
wire        branch_flag;
wire [31:0] branch_target;

// Branch target is simply EX's computed branch address,
// registered into EX_MEM_ALUOUT (NPC + offset for BEQZ/BNEQZ)
assign branch_target = EX_MEM_ALUOUT;


//====================================================
// IF Stage
//====================================================
IF if_stage(
    .clk                     (clk),
    .reset                   (reset),
    .branch_flag             (branch_flag),
    .load_hazard             (load_hazard),
    .branch_target           (branch_target),
    .instruction_bus         (instruction_bus),
    .instruction_address_bus (instruction_address_bus),
    .IF_ID_IR                (IF_ID_IR),
    .IF_ID_NPC               (IF_ID_NPC)
);


//====================================================
// Instruction Memory
//====================================================
INSTRUCTION_MEMORY instr_mem(
    .instruction_address_bus (instruction_address_bus),
    .instruction_bus         (instruction_bus)
);


//====================================================
// ID Stage
//====================================================
ID id_stage(
    .clk                 (clk),
    .reset               (reset),
    .branch_flag         (branch_flag),
    .load_hazard         (load_hazard),
    .IF_ID_NPC           (IF_ID_NPC),
    .IF_ID_IR            (IF_ID_IR),
    .reg_update_flag     (reg_update_flag),
    .reg_update_address  (reg_update_address),
    .reg_update_data     (reg_update_data),
    .ID_EX_A             (ID_EX_A),
    .ID_EX_B             (ID_EX_B),
    .ID_EX_NPC           (ID_EX_NPC),
    .ID_EX_IR            (ID_EX_IR),
    .ID_EX_Imm           (ID_EX_Imm)
);


//====================================================
// EX Stage
//====================================================
EX ex_stage(
    .clk            (clk),
    .reset          (reset),
    .branch_flag    (branch_flag),
    .ID_EX_IR       (ID_EX_IR),
    .ID_EX_NPC      (ID_EX_NPC),
    .ID_EX_A        (ID_EX_A),
    .ID_EX_B        (ID_EX_B),
    .ID_EX_Imm      (ID_EX_Imm),
    .MEM_WB_ALUOUT  (MEM_WB_ALUOUT),
    .MEM_WB_LMD     (MEM_WB_LMD),
    .ForwardA       (ForwardA),
    .ForwardB       (ForwardB),
    .EX_MEM_IR      (EX_MEM_IR),
    .EX_MEM_ALUOUT  (EX_MEM_ALUOUT),
    .EX_MEM_B       (EX_MEM_B),
    .EX_MEM_COND    (EX_MEM_COND)
);


//====================================================
// MEM Stage
//====================================================
MEM mem_stage(
    .clk               (clk),
    .reset             (reset),
    .EX_MEM_ALUOUT     (EX_MEM_ALUOUT),
    .EX_MEM_IR         (EX_MEM_IR),
    .EX_MEM_B          (EX_MEM_B),
    .data_bus          (data_bus),
    .MEM_WB_IR         (MEM_WB_IR),
    .MEM_WB_ALUOUT     (MEM_WB_ALUOUT),
    .MEM_WB_LMD        (MEM_WB_LMD),
    .data_bus_address  (data_bus_address),
    .read_enable       (read_enable),
    .write_enable      (write_enable),
    .data_write_data   (data_write_data)
);


//====================================================
// Data Memory
//====================================================
DATA_MEMORY data_mem(
    .clk               (clk),
    .reset             (reset),
    .data_bus_address  (data_bus_address),
    .read_enable       (read_enable),
    .write_enable      (write_enable),
    .data_write_data   (data_write_data),
    .data_bus          (data_bus)
);


//====================================================
// WB Stage
//====================================================
WB wb_stage(
    .clk                 (clk),
    .reset               (reset),
    .MEM_WB_ALUOUT       (MEM_WB_ALUOUT),
    .MEM_WB_LMD          (MEM_WB_LMD),
    .MEM_WB_IR           (MEM_WB_IR),
    .reg_update_flag     (reg_update_flag),
    .reg_update_address  (reg_update_address),
    .reg_update_data     (reg_update_data)
);


//====================================================
// Branch Prediction / Resolution Unit
//====================================================
BRANCH_PREDICTION_UNIT branch_unit(
    .EX_MEM_COND  (EX_MEM_COND),
    .EX_MEM_IR    (EX_MEM_IR),
    .branch_flag  (branch_flag)
);


//====================================================
// Hazard Detection / Forwarding Unit
//====================================================
HAZARD_UNIT hazard_unit(
    .IF_ID_IR     (IF_ID_IR),
    .ID_EX_IR     (ID_EX_IR),
    .EX_MEM_IR    (EX_MEM_IR),
    .MEM_WB_IR    (MEM_WB_IR),
    .load_hazard  (load_hazard),
    .ForwardA     (ForwardA),
    .ForwardB     (ForwardB)
);

endmodule
