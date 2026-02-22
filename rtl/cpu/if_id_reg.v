//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : if_id_reg.v
// Date        : 2025-01-25
// Author      : Sofía Avalos - Laureano Olocco
// Description : IF/ID pipeline register module for a RISC-V processor. This module captures the instruction and
//               program counter (PC) values at the end of the Instruction Fetch stage and provides them to the
//               Instruction Decode stage. It also handles control signals for flushing and enabling the pipeline.
//--------------------------------------------------------------------------------------------------

´default nettype none

module if_id_reg
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_INSTR      = 32                  ,      
  parameter                                                     NB_PC         = 32                  ,
  parameter                                                     NB_OP_CODE    = 6                   ,
  parameter                                                     NB_ADDR       = $clog2(NB_INSTR)    ,
  parameter                                                     NB_FUNC3      = 3                   ,
  parameter                                                     NB_FUNC7      = 7                   
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_PC                                  - 1 : 0]  o_pc                                , 
  output wire [NB_PC                                  - 1 : 0]  o_pc_next                           ,  
  output wire [NB_INSTR                               - 1 : 0]  o_instruction                       ,  
  output wire [NB_OP_CODE                             - 1 : 0]  o_opcode                            ,
  output wire [NB_ADDR                                - 1 : 0]  o_rd_addr                           ,
  output wire [NB_FUNC3                               - 1 : 0]  o_func3                             ,
  output wire [NB_ADDR                                - 1 : 0]  o_rs1_addr                          ,
  output wire [NB_ADDR                                - 1 : 0]  o_rs2_addr                          ,
  output wire [NB_FUNC7                               - 1 : 0]  o_func7                             ,

//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input  wire [NB_INSTR                               - 1 : 0]  i_instruction                       ,       
  input  wire [NB_PC                                  - 1 : 0]  i_pc                                , 
  input  wire [NB_PC                                  - 1 : 0]  i_pc_next                           , 
  input  wire                                                   i_flush                             , 
  input  wire                                                   i_enable                            , 
  input  wire                                                   i_rst                               , 
  input  wire                                                   clock                                   
);

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    OP_CODE_INDEX    = 0                ;
  localparam                                                    RD_ADDR_INDEX    = 7                ;
  localparam                                                    FUNC3_INDEX      = 12               ;
  localparam                                                    RS1_ADDR_INDEX   = 15               ;
  localparam                                                    RS2_ADDR_INDEX   = 20               ;
  localparam                                                    FUNC7_INDEX      = 25               ;

//------------------------------------------ Registers ------------------------------------------//
  reg       [NB_PC                                    - 1 : 0]  pc_out                              ;
  reg       [NB_PC                                    - 1 : 0]  pc_next_out                         ;
  reg       [NB_INSTR                                 - 1 : 0]  instruction_out                     ;
  reg       [NB_OP_CODE                               - 1 : 0]  opcode_out                          ;
  reg       [NB_ADDR                                  - 1 : 0]  rd_addr_out                         ;
  reg       [NB_FUNC3                                 - 1 : 0]  func3_out                           ;
  reg       [NB_ADDR                                  - 1 : 0]  rs1_addr_out                        ;
  reg       [NB_ADDR                                  - 1 : 0]  rs2_addr_out                        ;
  reg       [NB_FUNC7                                 - 1 : 0]  func7_out                           ;

//-------------------------------------- Sequential Logic ---------------------------------------//
  always @(posedge clock) 
  begin
    if (i_rst || i_flush) 
    begin
      pc_out          <= {NB_PC{1'b0}}                                                              ;
      pc_next_out     <= {NB_PC{1'b0}}                                                              ;
      instruction_out <= {NB_INSTR{1'b0}}                                                           ;
      opcode_out      <= {NB_OP_CODE{1'b0}}                                                         ;
      rd_addr_out     <= {NB_ADDR{1'b0}}                                                            ;
      func3_out       <= {NB_FUNC3{1'b0}}                                                           ;
      rs1_addr_out    <= {NB_ADDR{1'b0}}                                                            ;
      rs2_addr_out    <= {NB_ADDR{1'b0}}                                                            ;
      func7_out       <= {NB_FUNC7{1'b0}}                                                           ;
    end
    else if (i_enable) 
    begin
      pc_out          <= i_pc                                                                       ;
      pc_next_out     <= i_pc_next                                                                  ;
      instruction_out <= i_instruction                                                              ;
      opcode_out      <= i_instruction[OP_CODE_INDEX  +: NB_OP_CODE ]                               ;
      rd_addr_out     <= i_instruction[RD_ADDR_INDEX  +: NB_ADDR    ]                               ;
      func3_out       <= i_instruction[FUNC3_INDEX    +: NB_FUNC3   ]                               ;
      rs1_addr_out    <= i_instruction[RS1_ADDR_INDEX +: NB_ADDR    ]                               ;
      rs2_addr_out    <= i_instruction[RS2_ADDR_INDEX +: NB_ADDR    ]                               ;
      func7_out       <= i_instruction[FUNC7_INDEX    +: NB_FUNC7   ]                               ;
    end
  end
//-------------------------------------------- OUTPUTS ------------------------------------------//
  assign o_pc           = pc_out                                                                    ;
  assign o_pc_next      = pc_next_out                                                               ;
  assign o_instruction  = instruction_out                                                           ;
  assign o_opcode       = opcode_out                                                                ;
  assign o_rd_addr      = rd_addr_out                                                               ;
  assign o_func3        = func3_out                                                                 ;
  assign o_rs1_addr     = rs1_addr_out                                                              ;
  assign o_rs2_addr     = rs2_addr_out                                                              ;
  assign o_func7        = func7_out                                                                 ;

endmodule