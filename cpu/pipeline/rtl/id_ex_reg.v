//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : if_id_reg.v
// Date        : 2025-01-25
// Author      : Sofía Avalos - Laureano Olocco
// Description : ID/EX pipeline register module for a RISC-V processor. This module captures the control signals, 
//               register data, immediate values, and instruction fields at the end of the Instruction Decode stage 
//               and provides them to the Execute stage. It also handles control signals for flushing and enabling the pipeline.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module id_ex_reg
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,               
  parameter                                                     NB_CTRL       = 9                   ,
  parameter                                                     NB_INSTR      = 32                  ,
  parameter                                                     NB_PC         = 32                  ,
  parameter                                                     NB_OP_CODE    = 6                   ,
  parameter                                                     NB_ADDR       = $clog2(NB_INSTR)    ,
  parameter                                                     NB_FUNC3      = 3                   ,
  parameter                                                     NB_FUNC7      = 7                   ,
  parameter                                                     NB_ALU_OP     = 2                   ,
  parameter                                                     NB_DATA_SIZE  = 6                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire                                                   o_reg_write                         ,
  output wire                                                   o_mem_read                          ,
  output wire                                                   o_mem_write                         ,
  output wire                                                   o_alu_source                        ,
  output wire                                                   o_mem_to_reg                        ,
  output wire [NB_ALU_OP                              - 1 : 0]  o_alu_op                            ,
  output wire [NB_DATA_SIZE                           - 1 : 0]  o_data_size                         , 
  output wire [NB_DATA                                - 1 : 0]  o_rs1_data                          ,  
  output wire [NB_DATA                                - 1 : 0]  o_rs2_data                          ,  
  output wire [NB_DATA                                - 1 : 0]  o_immediate                         ,  
  output wire [NB_ADDR                                - 1 : 0]  o_rd_addr                           ,
  output wire [NB_FUNC3                               - 1 : 0]  o_func3                             ,
  output wire [NB_ADDR                                - 1 : 0]  o_rs1_addr                          ,
  output wire [NB_ADDR                                - 1 : 0]  o_rs2_addr                          ,
  output wire [NB_FUNC7                               - 1 : 0]  o_func7                             ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire [NB_CTRL                                 - 1 : 0]  i_control                           , 
  input wire [NB_DATA                                 - 1 : 0]  i_rs1_data                          , 
  input wire [NB_DATA                                 - 1 : 0]  i_rs2_data                          , 
  input wire [NB_DATA                                 - 1 : 0]  i_immediate                         , 
  input wire [NB_ADDR                                 - 1 : 0]  i_rd_addr                           ,
  input wire [NB_FUNC3                                - 1 : 0]  i_func3                             ,
  input wire [NB_ADDR                                 - 1 : 0]  i_rs1_addr                          ,
  input wire [NB_ADDR                                 - 1 : 0]  i_rs2_addr                          ,
  input wire [NB_FUNC7                                - 1 : 0]  i_func7                             ,
  input wire                                                    i_flush                             ,
  input wire                                                    i_enable                            ,  
  input wire                                                    clock                                  
)                                                                                                   ;


//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    REG_WRITE_INDEX   = 0               ;
  localparam                                                    MEM_READ_INDEX    = 1               ;
  localparam                                                    MEM_WRITE_INDEX   = 2               ;
  localparam                                                    ALU_SOURCE_INDEX  = 3               ;
  localparam                                                    MEM_TO_REG_INDEX  = 4               ;
  localparam                                                    ALU_OP_INDEX      = 5               ;
  localparam                                                    DATA_SIZE_INDEX   = 7               ;
//------------------------------------------- Registers ------------------------------------------//
  reg                                                           reg_write_out                       ;
  reg                                                           mem_read_out                        ;
  reg                                                           mem_write_out                       ;
  reg                                                           alu_source_out                      ;
  reg                                                           mem_to_reg_out                      ;
  reg       [NB_ALU_OP                                - 1 : 0]  alu_op_out                          ;
  reg       [NB_DATA_SIZE                             - 1 : 0]  data_size_out                       ; 
  reg       [NB_DATA                                  - 1 : 0]  rs1_data_out                        ;  
  reg       [NB_DATA                                  - 1 : 0]  rs2_data_out                        ;  
  reg       [NB_DATA                                  - 1 : 0]  immediate_out                       ;  
  reg       [NB_ADDR                                  - 1 : 0]  rd_addr_out                         ;
  reg       [NB_FUNC3                                 - 1 : 0]  func3_out                           ;
  reg       [NB_ADDR                                  - 1 : 0]  rs1_addr_out                        ;
  reg       [NB_ADDR                                  - 1 : 0]  rs2_addr_out                        ;
  reg       [NB_FUNC7                                 - 1 : 0]  func7_out                           ;

//--------------------------------------- Sequential Logic ---------------------------------------//
  always @(posedge clock) 
  begin
    if (i_flush) 
    begin
      reg_write_out       <= 1'b0                                                                   ;
      mem_read_out        <= 1'b0                                                                   ;
      mem_write_out       <= 1'b0                                                                   ;
      alu_source_out      <= 1'b0                                                                   ;
      mem_to_reg_out      <= 1'b0                                                                   ;
      alu_op_out          <= {NB_ALU_OP   {1'b0}}                                                   ;
      data_size_out       <= {NB_DATA_SIZE{1'b0}}                                                   ;
      rs1_data_out        <= {NB_DATA     {1'b0}}                                                   ;
      rs2_data_out        <= {NB_DATA     {1'b0}}                                                   ;
      immediate_out       <= {NB_DATA     {1'b0}}                                                   ;
      rd_addr_out         <= {NB_ADDR     {1'b0}}                                                   ;
      func3_out           <= {NB_FUNC3    {1'b0}}                                                   ;
      rs1_addr_out        <= {NB_ADDR     {1'b0}}                                                   ;
      rs2_addr_out        <= {NB_ADDR     {1'b0}}                                                   ;
      func7_out           <= {NB_FUNC7    {1'b0}}                                                   ;
    end
    else if (i_enable) 
    begin
      reg_write_out       <= i_control[REG_WRITE_INDEX                      ]                       ;
      mem_read_out        <= i_control[MEM_READ_INDEX                       ]                       ;
      mem_write_out       <= i_control[MEM_WRITE_INDEX                      ]                       ;
      alu_source_out      <= i_control[ALU_SOURCE_INDEX                     ]                       ;
      mem_to_reg_out      <= i_control[MEM_TO_REG_INDEX                     ]                       ;
      alu_op_out          <= i_control[ALU_OP_INDEX    + 1 : ALU_OP_INDEX   ]                       ;
      data_size_out       <= i_control[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX]                       ;
      rs1_data_out        <= i_rs1_data                                                             ;
      rs2_data_out        <= i_rs2_data                                                             ;
      immediate_out       <= i_immediate                                                            ;
      rd_addr_out         <= i_rd_addr                                                              ;
      func3_out           <= i_func3                                                                ;
      rs1_addr_out        <= i_rs1_addr                                                             ;
      rs2_addr_out        <= i_rs2_addr                                                             ;
      func7_out           <= i_func7                                                                ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_reg_write      = reg_write_out                                                           ;
  assign o_mem_read       = mem_read_out                                                            ;
  assign o_mem_write      = mem_write_out                                                           ;
  assign o_alu_source     = alu_source_out                                                          ;
  assign o_mem_to_reg     = mem_to_reg_out                                                          ;
  assign o_alu_op         = alu_op_out                                                              ;
  assign o_data_size      = data_size_out                                                           ;
  assign o_rs1_data       = rs1_data_out                                                            ;
  assign o_rs2_data       = rs2_data_out                                                            ;
  assign o_immediate      = immediate_out                                                           ;
  assign o_rd_addr        = rd_addr_out                                                             ;
  assign o_func3          = func3_out                                                               ;
  assign o_rs1_addr       = rs1_addr_out                                                            ;
  assign o_rs2_addr       = rs2_addr_out                                                            ;
  assign o_func7          = func7_out                                                               ;

endmodule