//--------------------------------------------------------------------------------------------------
// Project      : RISC-V Computer Architecture
// Module name  : cpu_core.v
// Date         : 2026-02
// Author       : Sofía Avalos - Laureano Olocco
// Description  : RV32I 5-stage pipelined CPU core (IF, ID, EX, MEM, WB).
//                 - Full data hazard handling: load-use stall, EX/ID/MEM forwarding.
//                 - Control hazard handling: JAL/JALR resolved in ID (early), branches
//                   resolved in ID with forwarded register values (1-cycle penalty).
//                 - Debug Unit (DU) interface: IMEM write, DMEM read, regfile read.
//                 - CPU pipeline is gated by i_en (from DU via cpu_subsystem).
//--------------------------------------------------------------------------------------------------

module cpu_core
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_PC           = 32                , // Program counter width
  parameter                                                     NB_INSTRUCTION  = 32                , // Instruction width
  parameter                                                     NB_DATA         = 32                , // Data width
  parameter                                                     NB_REG          = 32                , // Register file data width
  parameter                                                     IMEM_ADDR_WIDTH = 10                , // IMEM address width (2^10 = 1024 words)
  parameter                                                     DMEM_ADDR_WIDTH = 10                  // DMEM address width (2^10 = 1024 words)
)
(
//----------------------------------------- OUTPUTS PORTS -----------------------------------------//
  // CPU state observation — buffered in cpu_subsystem and forwarded to Debug Unit
  output wire [NB_PC                                  - 1 : 0]  o_pc                                , // Current PC (IF stage)
  output wire [NB_INSTRUCTION                         - 1 : 0]  o_instr                             , // Current instruction (IF stage)
  output wire [NB_REG                                 - 1 : 0]  o_regfile_data                      , // Register file read data (DU inspection)
  output wire [NB_DATA                                - 1 : 0]  o_dmem_data                         , // Data memory read data (DU inspection)
  // Pipeline latch observation (DU inspection)
  // IF/ID
  output wire [NB_PC                                  - 1 : 0]  o_ifid_pc                           , // IF/ID: PC
  output wire [NB_INSTRUCTION                         - 1 : 0]  o_ifid_instr                        , // IF/ID: instruction
  // ID/EX — ctrl = {data_size[1:0], alu_op[1:0], mem_to_reg, alu_source, mem_write, mem_read, reg_write}
  output wire [8                                          : 0]  o_idex_ctrl                         ,
  output wire [NB_DATA                                - 1 : 0]  o_idex_rs1_data                     ,
  output wire [NB_DATA                                - 1 : 0]  o_idex_rs2_data                     ,
  output wire [NB_DATA                                - 1 : 0]  o_idex_imm                          ,
  output wire [4                                          : 0]  o_idex_rd_addr                      ,
  output wire [4                                          : 0]  o_idex_rs1_addr                     ,
  output wire [4                                          : 0]  o_idex_rs2_addr                     ,
  // EX/MEM — ctrl = {mem_to_reg, mem_write, mem_read, reg_write}
  output wire [3                                          : 0]  o_exmem_ctrl                        ,
  output wire [NB_DATA                                - 1 : 0]  o_exmem_alu                         ,
  output wire [NB_DATA                                - 1 : 0]  o_exmem_data2                       ,
  output wire [4                                          : 0]  o_exmem_rd_addr                     ,
  // MEM/WB — ctrl = {mem_to_reg, reg_write}
  output wire [1                                          : 0]  o_memwb_ctrl                        ,
  output wire [NB_DATA                                - 1 : 0]  o_memwb_data                        ,
  output wire [NB_DATA                                - 1 : 0]  o_memwb_alu                         ,
  output wire [4                                          : 0]  o_memwb_rd_addr                     ,
//------------------------------------------ INPUTS PORTS -----------------------------------------//
  // Debug Unit → Instruction Memory write (firmware load)
  input wire  [NB_INSTRUCTION                         - 1 : 0]  i_imem_data                         , // Write data
  input wire  [IMEM_ADDR_WIDTH                        - 1 : 0]  i_imem_waddr                        , // Write address
  input wire                                                     i_imem_wen                          , // Write enable
  // Debug Unit → Register File read
  input wire                                                     i_du_rgfile_rd                      , // Read enable
  input wire  [4                                          : 0]   i_regfile_addr                      , // Read address
  // Debug Unit → Data Memory read
  input wire  [DMEM_ADDR_WIDTH                        - 1 : 0]  i_dmem_raddr                        , // Read address
  input wire  [1                                          : 0]   i_dmem_rsize                        , // Read size
  input wire                                                     i_dmem_ren                          , // Read enable
  // Control
  input wire                                                     i_en                                , // CPU pipeline enable (from DU via cpu_subsystem)
  input wire                                                     i_du_rst                            , // Debug Unit reset
  input wire                                                     i_rst                               , // Global synchronous reset
  input wire                                                     clk                                   // Clock
)                                                                                                    ;

//----------------------------------------- Local Params ------------------------------------------//
  localparam                                                    NB_REGFILE_ADDR  = 5                ;
  localparam                                                    NB_CTRL          = 9                ;
  localparam                                                    NB_ALU_OP        = 2                ;
  localparam                                                    NB_ALU_OP_CODE   = 6                ;
  localparam                                                    NB_FUNC3         = 3                ;
  localparam                                                    NB_FUNC7         = 7                ;
  localparam                                                    NB_DATA_SIZE     = 6                ; // id_ex_reg output width (only 2 lsb used)
  localparam                                                    NB_FORWARD       = 2                ;

  // 7-bit RISC-V opcodes
  localparam                                                    B_TYPE           = 7'b1100011       ; // Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)

  // Branch func3 encodings
  localparam                                                    BEQ              = 3'b000           ;
  localparam                                                    BNE              = 3'b001           ;
  localparam                                                    BLT              = 3'b100           ;
  localparam                                                    BGE              = 3'b101           ;
  localparam                                                    BLTU             = 3'b110           ;
  localparam                                                    BGEU             = 3'b111           ;

  // PC source encodings for mux_4to1
  localparam                                                    PC_SRC_PLUS4     = 2'b00            ; // Sequential: PC + 4
  localparam                                                    PC_SRC_JAL       = 2'b01            ; // JAL:  PC_ID + imm
  localparam                                                    PC_SRC_JALR      = 2'b10            ; // JALR: rs1_fwd + imm
  localparam                                                    PC_SRC_BRANCH    = 2'b11            ; // Branch: PC_ID + imm (same adder as JAL)

//--------------------------------------- Internal Signals - IF Stage -----------------------------//
  wire [NB_PC          - 1 : 0]  pc_out                                                             ; // PC register output
  wire [NB_PC          - 1 : 0]  pc_plus4                                                           ; // PC + 4
  wire [NB_PC          - 1 : 0]  pc_next_mux                                                        ; // Next PC (mux output)
  wire [NB_INSTRUCTION - 1 : 0]  imem_rdata                                                         ; // Instruction from IMEM

//--------------------------------------- Internal Signals - IF/ID Register -----------------------//
  wire [NB_PC          - 1 : 0]  ifid_pc                                                            ;
  wire [NB_PC          - 1 : 0]  ifid_pc_next                                                       ;
  wire [NB_INSTRUCTION - 1 : 0]  ifid_instr                                                         ;
  wire [NB_REGFILE_ADDR- 1 : 0]  ifid_rd_addr                                                       ;
  wire [NB_FUNC3       - 1 : 0]  ifid_func3                                                         ;
  wire [NB_REGFILE_ADDR- 1 : 0]  ifid_rs1_addr                                                      ;
  wire [NB_REGFILE_ADDR- 1 : 0]  ifid_rs2_addr                                                      ;
  wire [NB_FUNC7       - 1 : 0]  ifid_func7                                                         ;

  // Use full 7-bit opcode directly from instruction (bypass NB_OP_CODE=6 bug in if_id_reg)
  wire [6                   : 0]  ifid_opcode_7b                                                     ;
  assign ifid_opcode_7b = ifid_instr[6:0]                                                           ;

//--------------------------------------- Internal Signals - ID Stage -----------------------------//
  wire [NB_REG         - 1 : 0]  rs1_data_raw                                                       ; // Regfile port A output
  wire [NB_REG         - 1 : 0]  rs2_data_raw                                                       ; // Regfile port B output
  wire [NB_DATA        - 1 : 0]  imm_ext                                                            ; // Sign-extended immediate
  wire [NB_CTRL        - 1 : 0]  ctrl_signals                                                       ; // From base_integer_ctrl_unit

  // Hazard detection
  wire                            haz_write_enable                                                   ; // 0 = stall (load-use)
  wire                            haz_ctrl_mux                                                       ; // 1 = insert NOP
  wire                            jhaz_write_enable                                                  ; // 0 = stall (jump hazard)

  wire                            stall                                                              ; // Combined pipeline stall
  assign stall = ~haz_write_enable | ~jhaz_write_enable                                             ;

  // Jump control (JAL/JALR resolved in ID)
  wire [1                   : 0]  jump_pc_src                                                        ;
  wire                            jump_reg_write                                                     ;
  wire                            jump_flush                                                         ;

  // Branch target: PC_ID + imm (shared for JAL and branches)
  wire [NB_PC          - 1 : 0]  id_pc_imm                                                          ;

  // JALR target: rs1_fwd + imm
  wire [NB_PC          - 1 : 0]  id_rs1_imm                                                         ;

  // ID forwarding
  wire [NB_FORWARD     - 1 : 0]  id_fwd_a                                                           ;
  wire [NB_FORWARD     - 1 : 0]  id_fwd_b                                                           ;
  wire [NB_REG         - 1 : 0]  id_rs1_fwd                                                         ; // Forwarded rs1 (for branch/JALR)
  wire [NB_REG         - 1 : 0]  id_rs2_fwd                                                         ; // Forwarded rs2 (for branch)

  // Branch resolution (computed combinationally in ID stage)
  reg                             branch_taken_reg                                                   ;
  wire                            branch_taken                                                       ;
  assign branch_taken = branch_taken_reg                                                             ;

  // PC source select
  wire [1                   : 0]  pc_src                                                             ;
  assign pc_src = branch_taken          ? PC_SRC_BRANCH :
                  (jump_pc_src == 2'b01) ? PC_SRC_JAL    :
                  (jump_pc_src == 2'b10) ? PC_SRC_JALR   :
                                           PC_SRC_PLUS4   ;

  // IF/ID flush: branch taken OR jump (JAL/JALR)
  wire                            flush_ifid                                                         ;
  assign flush_ifid = (branch_taken | jump_flush) & i_en                                            ;

//--------------------------------------- Internal Signals - ID/EX Register ----------------------//
  wire                            idex_reg_write                                                     ;
  wire                            idex_mem_read                                                      ;
  wire                            idex_mem_write                                                     ;
  wire                            idex_alu_source                                                    ;
  wire                            idex_mem_to_reg                                                    ;
  wire [NB_ALU_OP      - 1 : 0]  idex_alu_op                                                        ;
  wire [NB_DATA_SIZE   - 1 : 0]  idex_data_size                                                     ;
  wire [NB_DATA        - 1 : 0]  idex_rs1_data                                                      ;
  wire [NB_DATA        - 1 : 0]  idex_rs2_data                                                      ;
  wire [NB_DATA        - 1 : 0]  idex_immediate                                                     ;
  wire [NB_REGFILE_ADDR- 1 : 0]  idex_rd_addr                                                       ;
  wire [NB_FUNC3       - 1 : 0]  idex_func3                                                         ;
  wire [NB_REGFILE_ADDR- 1 : 0]  idex_rs1_addr                                                      ;
  wire [NB_REGFILE_ADDR- 1 : 0]  idex_rs2_addr                                                      ;
  wire [NB_FUNC7       - 1 : 0]  idex_func7                                                         ;

  // ID/EX flush: insert NOP on stall
  wire                            idex_flush                                                         ;
  assign idex_flush = stall                                                                          ;

//--------------------------------------- Internal Signals - EX Stage -----------------------------//
  wire [NB_ALU_OP_CODE - 1 : 0]  alu_opcode                                                         ; // From alu_ctrl_unit (6-bit)
  wire [NB_DATA        - 1 : 0]  alu_result                                                         ; // ALU output
  wire                            alu_zero                                                           ; // ALU zero flag
  wire                            alu_carry                                                          ; // ALU carry flag

  wire [NB_FORWARD     - 1 : 0]  ex_fwd_a                                                           ; // EX forwarding select for rs1
  wire [NB_FORWARD     - 1 : 0]  ex_fwd_b                                                           ; // EX forwarding select for rs2

  wire [NB_DATA        - 1 : 0]  ex_alu_a                                                           ; // ALU input A (after forwarding)
  wire [NB_DATA        - 1 : 0]  ex_alu_b_pre                                                       ; // ALU input B before src mux
  wire [NB_DATA        - 1 : 0]  ex_alu_b                                                           ; // ALU input B (rs2 or immediate)

//--------------------------------------- Internal Signals - EX/MEM Register ---------------------//
  wire                            exmem_reg_write                                                    ;
  wire                            exmem_mem_read                                                     ;
  wire                            exmem_mem_write                                                    ;
  wire                            exmem_mem_to_reg                                                   ;
  wire [1                   : 0]  exmem_data_size                                                    ; // 2 meaningful bits
  wire [NB_DATA        - 1 : 0]  exmem_alu                                                          ;
  wire [NB_DATA        - 1 : 0]  exmem_data2                                                        ; // rs2 forwarded (for stores)
  wire [NB_REGFILE_ADDR- 1 : 0]  exmem_rd_addr                                                      ;
  wire [NB_FUNC3       - 1 : 0]  exmem_func3                                                        ;

//--------------------------------------- Internal Signals - MEM Stage ----------------------------//
  wire [NB_DATA        - 1 : 0]  dmem_rdata_cpu                                                     ; // DMEM port A — CPU loads
  wire [NB_DATA        - 1 : 0]  dmem_rdata_du                                                      ; // DMEM port B — DU inspection

  wire [NB_FORWARD     - 1 : 0]  mem_fwd_b                                                          ; // MEM forwarding for store data
  wire [NB_DATA        - 1 : 0]  mem_store_data                                                     ; // Final store data (muxed)

//--------------------------------------- Internal Signals - MEM/WB Register ---------------------//
  wire                            memwb_reg_write                                                    ;
  wire                            memwb_mem_to_reg                                                   ;
  wire [NB_DATA        - 1 : 0]  memwb_data                                                         ; // Memory read data
  wire [NB_DATA        - 1 : 0]  memwb_alu                                                          ; // ALU result
  wire [NB_REGFILE_ADDR- 1 : 0]  memwb_rd_addr                                                      ;
  wire [NB_FUNC3       - 1 : 0]  memwb_func3                                                        ;

//--------------------------------------- Internal Signals - WB Stage -----------------------------//
  wire [NB_DATA        - 1 : 0]  wb_mem_data                                                        ; // Sign/zero-extended load data
  wire [NB_DATA        - 1 : 0]  wb_result                                                          ; // Final writeback data (ALU or memory)

  // Regfile write: driven by WB stage
  wire                            regfile_wr_en                                                      ;
  wire [NB_REGFILE_ADDR- 1 : 0]  regfile_wr_addr                                                    ;
  wire [NB_DATA        - 1 : 0]  regfile_wr_data                                                    ;

//--------------------------------------- Pipeline Enable Signals ---------------------------------//
  wire  pc_wen    = i_en & ~stall                                                                    ; // Stall freezes PC
  wire  ifid_en   = i_en & ~stall                                                                    ; // Stall freezes IF/ID
  wire  idex_en   = i_en                                                                             ;
  wire  exmem_en  = i_en                                                                             ;
  wire  memwb_en  = i_en                                                                             ;
  wire  reset_all = i_rst | i_du_rst                                                                 ;

//---------------------------------------- IF Stage - PC & IMEM ----------------------------------//

  // Program Counter
  pc #(
    .NB_PC        (NB_PC)
  ) u_pc (
    .o_pc         (pc_out),
    .i_pc         (pc_next_mux),
    .i_write_en   (pc_wen),
    .i_reset      (reset_all),
    .clock        (clk)
  );

  // PC + 4 adder
  adder #(
    .NB_ADDER     (NB_PC)
  ) u_pc4_adder (
    .o_result     (pc_plus4),
    .i_data_a     (pc_out),
    .i_data_b     ({{(NB_PC-3){1'b0}}, 3'd4})
  );

  // Instruction Memory (IMEM)
  //   Port A: CPU instruction fetch (read)
  //   Write:  DU firmware load (when !i_en)
  block_ram #(
    .NB_DATA      (NB_INSTRUCTION),
    .NB_ADDRESS   (IMEM_ADDR_WIDTH)
  ) u_imem (
    .o_data_a           (imem_rdata),
    .o_data_b           (),
    .i_read_en_data_a   (1'b1),
    .i_read_address_a   (pc_out[IMEM_ADDR_WIDTH+1:2]),
    .i_read_en_data_b   (1'b0),
    .i_read_address_b   ({IMEM_ADDR_WIDTH{1'b0}}),
    .i_write_en         (i_imem_wen),
    .i_write_address    (i_imem_waddr),
    .i_write_data       (i_imem_data),
    .clock              (clk)
  );

  // Next PC mux: sequential (PC+4), JAL/branch target (PC_ID+imm), or JALR target (rs1+imm)
  mux_4to1 #(
    .NB_MUX       (NB_PC)
  ) u_pc_mux (
    .o_mux        (pc_next_mux),
    .i_data_a     (pc_plus4),    // 00: sequential
    .i_data_b     (id_pc_imm),   // 01: JAL target  (PC_ID + imm)
    .i_data_c     (id_rs1_imm),  // 10: JALR target (rs1_fwd + imm)
    .i_data_d     (id_pc_imm),   // 11: branch target (PC_ID + imm, same adder as JAL)
    .i_data_sel   (pc_src)
  );

//--------------------------------------- IF/ID Pipeline Register ---------------------------------//

  if_id_reg #(
    .NB_INSTR     (NB_INSTRUCTION),
    .NB_PC        (NB_PC)
  ) u_if_id (
    .o_pc         (ifid_pc),
    .o_pc_next    (ifid_pc_next),
    .o_instruction(ifid_instr),
    .o_opcode     (),            // 6-bit (buggy) — use ifid_opcode_7b instead
    .o_rd_addr    (ifid_rd_addr),
    .o_func3      (ifid_func3),
    .o_rs1_addr   (ifid_rs1_addr),
    .o_rs2_addr   (ifid_rs2_addr),
    .o_func7      (ifid_func7),
    .i_instruction(imem_rdata),
    .i_pc         (pc_out),
    .i_pc_next    (pc_plus4),
    .i_flush      (flush_ifid),
    .i_enable     (ifid_en),
    .i_rst        (reset_all),
    .clock        (clk)
  );

//---------------------------------------- ID Stage ----------------------------------------------//

  // Register File
  //   Port A: rs1 read (CPU) or DU single-register read (when i_du_rgfile_rd=1)
  //   Port B: rs2 read (CPU, combinational)
  //   Write:  WB stage writeback
  regfile #(
    .NB_DATA      (NB_REG)
  ) u_regfile (
    .o_data_a         (rs1_data_raw),
    .o_data_b         (rs2_data_raw),
    .i_read_address_a (i_du_rgfile_rd ? i_regfile_addr : ifid_rs1_addr),
    .i_read_address_b (ifid_rs2_addr),
    .i_write_address  (regfile_wr_addr),
    .i_write_data     (regfile_wr_data),
    .i_write_enable   (regfile_wr_en),
    .i_reset          (reset_all),
    .clock            (clk)
  );

  // Immediate Generator
  imm_gen #(
    .NB_DATA      (NB_DATA)
  ) u_imm_gen (
    .o_immediate  (imm_ext),
    .i_instruction(ifid_instr)
  );

  // Main Control Unit
  base_integer_ctrl_unit #(
    .NB_CTRL      (NB_CTRL),
    .NB_OPCODE    (7),
    .NB_FUNC3     (NB_FUNC3)
  ) u_ctrl_unit (
    .o_ctrl       (ctrl_signals),
    .i_opcode     (ifid_opcode_7b),
    .i_func3      (ifid_func3)
  );

  // Load-Use Hazard Detection Unit
  hazard_detection_unit #(
    .NB_ADDR      (NB_REGFILE_ADDR)
  ) u_hazard (
    .o_write_enable   (haz_write_enable),
    .o_control_mux    (haz_ctrl_mux),
    .i_id_ex_mem_read (idex_mem_read),
    .i_id_ex_rd       (idex_rd_addr),
    .i_if_id_rs1      (ifid_rs1_addr),
    .i_if_id_rs2      (ifid_rs2_addr)
  );

  // Jump Hazard Detection Unit (RAW hazard on JAL/JALR source register)
  jump_hazard_detection_unit #(
    .NB_OPCODE    (7),
    .NB_ADDR      (NB_REGFILE_ADDR)
  ) u_jump_hazard (
    .o_write_enable   (jhaz_write_enable),
    .i_opcode         (ifid_opcode_7b),
    .i_ex_reg_write   (idex_reg_write),
    .i_ex_rd          (idex_rd_addr),
    .i_id_rs1         (ifid_rs1_addr),
    .i_id_rs2         (ifid_rs2_addr),
    .clock            (clk)
  );

  // Jump Control Unit (resolves JAL/JALR in ID, generates PC source and flush)
  jump_ctrl_unit #(
    .NB_PC        (NB_PC),
    .NB_OPCODE    (7)
  ) u_jump_ctrl (
    .o_pc_src     (jump_pc_src),
    .o_reg_write  (jump_reg_write),
    .o_flush      (jump_flush),
    .i_opcode     (ifid_opcode_7b),
    .i_stall      (stall)
  );

  // ID Forwarding Unit (provides forwarded rs1/rs2 for branch and JALR resolution in ID)
  id_forwarding_unit #(
    .NB_ADDR      (NB_REGFILE_ADDR)
  ) u_id_fwd (
    .o_forward_a      (id_fwd_a),
    .o_forward_b      (id_fwd_b),
    .i_id_rs1         (ifid_rs1_addr),
    .i_id_rs2         (ifid_rs2_addr),
    .i_mem_rd         (exmem_rd_addr),
    .i_wb_rd          (memwb_rd_addr),
    .i_mem_reg_write  (exmem_reg_write),
    .i_wb_reg_write   (memwb_reg_write),
    .i_mem_mem_read   (exmem_mem_read)
  );

  // ID Forwarding Mux — rs1
  mux_3to1 #(
    .NB_MUX       (NB_REG)
  ) u_id_fwd_mux_a (
    .o_mux        (id_rs1_fwd),
    .i_data_a     (rs1_data_raw),  // 00: no forwarding
    .i_data_b     (exmem_alu),     // 01: forward from MEM stage
    .i_data_c     (wb_result),     // 10: forward from WB stage
    .i_data_sel   (id_fwd_a)
  );

  // ID Forwarding Mux — rs2
  mux_3to1 #(
    .NB_MUX       (NB_REG)
  ) u_id_fwd_mux_b (
    .o_mux        (id_rs2_fwd),
    .i_data_a     (rs2_data_raw),  // 00: no forwarding
    .i_data_b     (exmem_alu),     // 01: forward from MEM stage
    .i_data_c     (wb_result),     // 10: forward from WB stage
    .i_data_sel   (id_fwd_b)
  );

  // Branch target adder: PC_ID + imm (used for JAL and branches)
  adder #(
    .NB_ADDER     (NB_PC)
  ) u_branch_adder (
    .o_result     (id_pc_imm),
    .i_data_a     (ifid_pc),
    .i_data_b     (imm_ext)
  );

  // JALR target adder: rs1_fwd + imm
  adder #(
    .NB_ADDER     (NB_PC)
  ) u_jalr_adder (
    .o_result     (id_rs1_imm),
    .i_data_a     (id_rs1_fwd),
    .i_data_b     (imm_ext)
  );

  // Branch condition: compare forwarded rs1/rs2 in ID stage (early branch resolution)
  always @(*)
  begin
    branch_taken_reg = 1'b0                                                                         ;
    if (ifid_opcode_7b == B_TYPE && ~stall && i_en)
    begin
      case (ifid_func3)
        BEQ     : branch_taken_reg = (id_rs1_fwd == id_rs2_fwd)                                    ;
        BNE     : branch_taken_reg = (id_rs1_fwd != id_rs2_fwd)                                    ;
        BLT     : branch_taken_reg = ($signed(id_rs1_fwd) <  $signed(id_rs2_fwd))                  ;
        BGE     : branch_taken_reg = ($signed(id_rs1_fwd) >= $signed(id_rs2_fwd))                  ;
        BLTU    : branch_taken_reg = (id_rs1_fwd <  id_rs2_fwd)                                    ;
        BGEU    : branch_taken_reg = (id_rs1_fwd >= id_rs2_fwd)                                    ;
        default : branch_taken_reg = 1'b0                                                          ;
      endcase
    end
  end

//--------------------------------------- ID/EX Pipeline Register ---------------------------------//

  id_ex_reg #(
    .NB_DATA      (NB_DATA),
    .NB_CTRL      (NB_CTRL)
  ) u_id_ex (
    .o_reg_write  (idex_reg_write),
    .o_mem_read   (idex_mem_read),
    .o_mem_write  (idex_mem_write),
    .o_alu_source (idex_alu_source),
    .o_mem_to_reg (idex_mem_to_reg),
    .o_alu_op     (idex_alu_op),
    .o_data_size  (idex_data_size),
    .o_rs1_data   (idex_rs1_data),
    .o_rs2_data   (idex_rs2_data),
    .o_immediate  (idex_immediate),
    .o_rd_addr    (idex_rd_addr),
    .o_func3      (idex_func3),
    .o_rs1_addr   (idex_rs1_addr),
    .o_rs2_addr   (idex_rs2_addr),
    .o_func7      (idex_func7),
    .i_control    (ctrl_signals),
    .i_rs1_data   (id_rs1_fwd),    // forwarded values into EX
    .i_rs2_data   (id_rs2_fwd),
    .i_immediate  (imm_ext),
    .i_rd_addr    (ifid_rd_addr),
    .i_func3      (ifid_func3),
    .i_rs1_addr   (ifid_rs1_addr),
    .i_rs2_addr   (ifid_rs2_addr),
    .i_func7      (ifid_func7),
    .i_flush      (idex_flush),
    .i_enable     (idex_en),
    .clock        (clk)
  );

//---------------------------------------- EX Stage ----------------------------------------------//

  // ALU Control Unit
  alu_ctrl_unit #(
    .NB_ALU_OP    (NB_ALU_OP),
    .NB_OP_CODE   (NB_ALU_OP_CODE),
    .NB_FUNCT7    (NB_FUNC7),
    .NB_FUNCT3    (NB_FUNC3)
  ) u_alu_ctrl (
    .o_alu_op_code(alu_opcode),
    .i_alu_op     (idex_alu_op),
    .i_funct7     (idex_func7),
    .i_funct3     (idex_func3)
  );

  // EX Forwarding Unit
  ex_forwarding_unit #(
    .NB_ADDR      (NB_REGFILE_ADDR)
  ) u_ex_fwd (
    .o_forward_a      (ex_fwd_a),
    .o_forward_b      (ex_fwd_b),
    .i_ex_rs1         (idex_rs1_addr),
    .i_ex_rs2         (idex_rs2_addr),
    .i_mem_rd         (exmem_rd_addr),
    .i_wb_rd          (memwb_rd_addr),
    .i_mem_reg_write  (exmem_reg_write),
    .i_wb_reg_write   (memwb_reg_write)
  );

  // EX Forwarding Mux — ALU input A (rs1)
  mux_3to1 #(
    .NB_MUX       (NB_DATA)
  ) u_ex_fwd_mux_a (
    .o_mux        (ex_alu_a),
    .i_data_a     (idex_rs1_data),  // 00: from ID/EX reg
    .i_data_b     (exmem_alu),      // 01: forward from MEM stage
    .i_data_c     (wb_result),      // 10: forward from WB stage
    .i_data_sel   (ex_fwd_a)
  );

  // EX Forwarding Mux — ALU input B before src mux (rs2)
  mux_3to1 #(
    .NB_MUX       (NB_DATA)
  ) u_ex_fwd_mux_b (
    .o_mux        (ex_alu_b_pre),
    .i_data_a     (idex_rs2_data),  // 00: from ID/EX reg
    .i_data_b     (exmem_alu),      // 01: forward from MEM stage
    .i_data_c     (wb_result),      // 10: forward from WB stage
    .i_data_sel   (ex_fwd_b)
  );

  // ALU Source Mux: forwarded rs2 vs immediate
  mux_2to1 #(
    .NB_MUX       (NB_DATA)
  ) u_alu_src_mux (
    .o_mux        (ex_alu_b),
    .i_data_a     (ex_alu_b_pre),   // 0: rs2 (forwarded)
    .i_data_b     (idex_immediate), // 1: immediate
    .i_data_sel   (idex_alu_source)
  );

  // ALU
  alu #(
    .NB_DATA      (NB_DATA),
    .NB_OP_CODE   (NB_ALU_OP_CODE)
  ) u_alu (
    .o_result     (alu_result),
    .o_zero       (alu_zero),
    .o_carry      (alu_carry),
    .i_data_a     (ex_alu_a),
    .i_data_b     (ex_alu_b),
    .i_op_code    (alu_opcode)
  );

//--------------------------------------- EX/MEM Pipeline Register --------------------------------//

  ex_mem_reg #(
    .NB_DATA      (NB_DATA),
    .NB_ADDR      (NB_REGFILE_ADDR),
    .NB_FUNC3     (NB_FUNC3),
    .NB_DATA_SIZE (2)
  ) u_ex_mem (
    .o_reg_write  (exmem_reg_write),
    .o_mem_read   (exmem_mem_read),
    .o_mem_write  (exmem_mem_write),
    .o_mem_to_reg (exmem_mem_to_reg),
    .o_data_size  (exmem_data_size),
    .o_alu        (exmem_alu),
    .o_data2      (exmem_data2),
    .o_rd_addr    (exmem_rd_addr),
    .o_func3      (exmem_func3),
    .i_reg_write  (idex_reg_write),
    .i_mem_read   (idex_mem_read),
    .i_mem_write  (idex_mem_write),
    .i_mem_to_reg (idex_mem_to_reg),
    .i_data_size  (idex_data_size[1:0]),  // only 2 meaningful bits
    .i_alu        (alu_result),
    .i_data2      (ex_alu_b_pre),         // rs2 forwarded (before alu_src mux)
    .i_rd_addr    (idex_rd_addr),
    .i_func3      (idex_func3),
    .i_enable     (exmem_en),
    .i_flush      (1'b0),
    .clock        (clk)
  );

//---------------------------------------- MEM Stage ---------------------------------------------//

  // MEM Forwarding Unit (for store data RAW hazard)
  mem_forwarding_unit #(
    .NB_ADDR      (NB_REGFILE_ADDR)
  ) u_mem_fwd (
    .o_forward_b      (mem_fwd_b),
    .i_mem_rs2        (idex_rs2_addr),  // rs2 address from EX stage
    .i_wb_rd          (memwb_rd_addr),
    .i_wb_reg_write   (memwb_reg_write)
  );

  // Store Data Mux: original rs2 or forwarded WB data
  mux_2to1 #(
    .NB_MUX       (NB_DATA)
  ) u_mem_store_mux (
    .o_mux        (mem_store_data),
    .i_data_a     (exmem_data2),  // 0: normal rs2
    .i_data_b     (wb_result),    // 1: forwarded from WB
    .i_data_sel   (mem_fwd_b[0])
  );

  // Data Memory (DMEM)
  //   Port A: CPU loads (read by pipeline)
  //   Port B: DU inspection (read by Debug Unit)
  //   Write:  CPU stores when running (i_en=1); DU write not yet supported in cpu_core
  block_ram #(
    .NB_DATA      (NB_DATA),
    .NB_ADDRESS   (DMEM_ADDR_WIDTH)
  ) u_dmem (
    .o_data_a           (dmem_rdata_cpu),
    .o_data_b           (dmem_rdata_du),
    .i_read_en_data_a   (exmem_mem_read),
    .i_read_address_a   (exmem_alu[DMEM_ADDR_WIDTH-1:0]),
    .i_read_en_data_b   (i_dmem_ren),
    .i_read_address_b   (i_dmem_raddr),
    .i_write_en         (i_en ? exmem_mem_write : 1'b0),
    .i_write_address    (exmem_alu[DMEM_ADDR_WIDTH-1:0]),
    .i_write_data       (mem_store_data),
    .clock              (clk)
  );

//--------------------------------------- MEM/WB Pipeline Register --------------------------------//

  mem_wb_reg #(
    .NB_DATA      (NB_DATA),
    .NB_ADDR      (NB_REGFILE_ADDR),
    .NB_FUNC3     (NB_FUNC3)
  ) u_mem_wb (
    .o_reg_write  (memwb_reg_write),
    .o_mem_to_reg (memwb_mem_to_reg),
    .o_data       (memwb_data),
    .o_alu        (memwb_alu),
    .o_rd_addr    (memwb_rd_addr),
    .o_func3      (memwb_func3),
    .i_reg_write  (exmem_reg_write),
    .i_mem_to_reg (exmem_mem_to_reg),
    .i_data       (dmem_rdata_cpu),
    .i_alu        (exmem_alu),
    .i_rd_addr    (exmem_rd_addr),
    .i_func3      (exmem_func3),
    .i_enable     (memwb_en),
    .clock        (clk)
  );

//---------------------------------------- WB Stage ----------------------------------------------//

  // Data Memory Output Unit: sign/zero-extend load data according to func3
  data_mem_output_unit #(
    .NB_DATA      (NB_DATA),
    .NB_FUNC3     (NB_FUNC3)
  ) u_dmem_out (
    .o_data       (wb_mem_data),
    .i_data       (memwb_data),
    .i_func3      (memwb_func3)
  );

  // Writeback Mux: ALU result or memory load data
  mux_2to1 #(
    .NB_MUX       (NB_DATA)
  ) u_wb_mux (
    .o_mux        (wb_result),
    .i_data_a     (memwb_alu),    // 0: ALU result
    .i_data_b     (wb_mem_data),  // 1: load data (sign/zero-extended)
    .i_data_sel   (memwb_mem_to_reg)
  );

  // Regfile write: WB stage drives the write port
  assign regfile_wr_en   = memwb_reg_write & i_en                                                   ;
  assign regfile_wr_addr = memwb_rd_addr                                                            ;
  assign regfile_wr_data = wb_result                                                                 ;

//-------------------------------------------- Outputs -------------------------------------------//

  // DU observation: PC and instruction from IF stage
  assign o_pc          = pc_out                                                                      ;
  assign o_instr       = imem_rdata                                                                  ;

  // DU register read: port A is switched to DU address when i_du_rgfile_rd=1
  assign o_regfile_data = rs1_data_raw                                                              ;

  // DU DMEM read: from DMEM port B (always available)
  assign o_dmem_data   = dmem_rdata_du                                                               ;

  // Pipeline latch dumps (DU inspection)
  assign o_ifid_pc       = ifid_pc                                                                   ;
  assign o_ifid_instr    = ifid_instr                                                                ;

  assign o_idex_ctrl     = {idex_data_size[1:0], idex_alu_op,
                            idex_mem_to_reg, idex_alu_source,
                            idex_mem_write, idex_mem_read, idex_reg_write}                           ;
  assign o_idex_rs1_data = idex_rs1_data                                                             ;
  assign o_idex_rs2_data = idex_rs2_data                                                             ;
  assign o_idex_imm      = idex_immediate                                                            ;
  assign o_idex_rd_addr  = idex_rd_addr                                                              ;
  assign o_idex_rs1_addr = idex_rs1_addr                                                             ;
  assign o_idex_rs2_addr = idex_rs2_addr                                                             ;

  assign o_exmem_ctrl    = {exmem_mem_to_reg, exmem_mem_write, exmem_mem_read, exmem_reg_write}      ;
  assign o_exmem_alu     = exmem_alu                                                                 ;
  assign o_exmem_data2   = exmem_data2                                                               ;
  assign o_exmem_rd_addr = exmem_rd_addr                                                             ;

  assign o_memwb_ctrl    = {memwb_mem_to_reg, memwb_reg_write}                                       ;
  assign o_memwb_data    = memwb_data                                                                ;
  assign o_memwb_alu     = memwb_alu                                                                 ;
  assign o_memwb_rd_addr = memwb_rd_addr                                                             ;

endmodule
