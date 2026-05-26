//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : ex_mem_reg.v
// Date        : 2025-01-25
// Author      : Sofia Avalos - Laureano Olocco
// Description : EX/MEM pipeline register module for a RISC-V processor. 
//               This module captures the control signals, ALU result, data to be written to memory,
//               destination register address, and function code at the end of the Execute stage and 
//               provides them to the Memory Access stage. It also handles control signals for enabling 
//               and flushing the pipeline.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module ex_mem_reg
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_PC         = 32                  ,
  parameter                                                     NB_DATA       = 32                  ,
  parameter                                                     NB_ADDR       = 5                   ,
  parameter                                                     NB_FUNC3      = 3                   ,
  parameter                                                     NB_DATA_SIZE  = 2                                           
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire                                                   o_reg_write                         ,
  output wire                                                   o_mem_read                          ,
  output wire                                                   o_mem_write                         ,
  output wire                                                   o_mem_to_reg                        ,
  output wire [NB_DATA_SIZE                           - 1 : 0]  o_data_size                         ,
  output wire [NB_DATA                                - 1 : 0]  o_alu                               ,
  output wire [NB_DATA                                - 1 : 0]  o_data2                             ,
  output wire [NB_ADDR                                - 1 : 0]  o_rd_addr                           ,
  output wire [NB_FUNC3                               - 1 : 0]  o_func3                             ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire                                                    i_reg_write                         ,
  input wire                                                    i_mem_read                          ,
  input wire                                                    i_mem_write                         ,
  input wire                                                    i_mem_to_reg                        ,
  input wire [NB_DATA_SIZE                            - 1 : 0]  i_data_size                         ,
  input wire [NB_DATA                                 - 1 : 0]  i_alu                               ,
  input wire [NB_DATA                                 - 1 : 0]  i_data2                             ,
  input wire [NB_ADDR                                 - 1 : 0]  i_rd_addr                           ,
  input wire [NB_FUNC3                                - 1 : 0]  i_func3                             ,
  input wire                                                    i_enable                            ,
  input wire                                                    i_flush                             ,
  input wire                                                    clock                                  
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  reg                                                           reg_write_out                       ;
  reg                                                           mem_read_out                        ;
  reg                                                           mem_write_out                       ;
  reg                                                           mem_to_reg_out                      ;
  reg        [NB_DATA_SIZE                            - 1 : 0]  data_size_out                       ;
  reg        [NB_DATA                                 - 1 : 0]  alu_out                             ;
  reg        [NB_DATA                                 - 1 : 0]  data2_out                           ;
  reg        [NB_ADDR                                 - 1 : 0]  rd_addr_out                         ;
  reg        [NB_FUNC3                                - 1 : 0]  func3_out                           ;

//--------------------------------------- Sequential Logic ---------------------------------------//
  always @(posedge clock) 
  begin
    if (i_flush) 
    begin
      reg_write_out       <= 1'b0                                                                   ;
      mem_read_out        <= 1'b0                                                                   ;
      mem_write_out       <= 1'b0                                                                   ;
      mem_to_reg_out      <= 1'b0                                                                   ;
      data_size_out       <= {NB_DATA_SIZE{1'b0}}                                                   ;
      alu_out             <= {NB_DATA     {1'b0}}                                                   ;
      data2_out           <= {NB_DATA     {1'b0}}                                                   ;
      rd_addr_out         <= {NB_ADDR     {1'b0}}                                                   ;
      func3_out           <= {NB_FUNC3    {1'b0}}                                                   ;
    end
    else if (i_enable) 
    begin
      reg_write_out       <= i_reg_write                                                            ;
      mem_read_out        <= i_mem_read                                                             ;
      mem_write_out       <= i_mem_write                                                            ;
      mem_to_reg_out      <= i_mem_to_reg                                                           ;
      data_size_out       <= i_data_size                                                            ;
      alu_out             <= i_alu                                                                  ;
      data2_out           <= i_data2                                                                ;
      rd_addr_out         <= i_rd_addr                                                              ;
      func3_out           <= i_func3                                                                ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_reg_write      = reg_write_out                                                           ;
  assign o_mem_read       = mem_read_out                                                            ;
  assign o_mem_write      = mem_write_out                                                           ;
  assign o_mem_to_reg     = mem_to_reg_out                                                          ;
  assign o_data_size      = data_size_out                                                           ;
  assign o_alu            = alu_out                                                                 ;
  assign o_data2          = data2_out                                                               ;
  assign o_rd_addr        = rd_addr_out                                                             ;
  assign o_func3          = func3_out                                                               ;

endmodule