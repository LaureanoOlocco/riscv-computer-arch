//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : mem_wb_reg.v
// Date        : 2025-01-25
// Author      : Sofía Avalos - Laureano Olocco
// Description : MEM/WB pipeline register module for a RISC-V processor.
//               This module captures the control signals, memory data, ALU result, and instruction fields
//               at the end of the Memory Access stage and provides them to the Write Back stage. It also
//               handles control signals for enabling the pipeline.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module mem_wb_reg
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_PC         = 32                  ,
  parameter                                                     NB_DATA       = 32                  ,
  parameter                                                     NB_ADDR       = 5                   ,
  parameter                                                     NB_FUNC3      = 3                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire                                                   o_reg_write                         ,
  output wire                                                   o_mem_to_reg                        ,
  output wire [NB_DATA                                - 1 : 0]  o_data                              ,
  output wire [NB_DATA                                - 1 : 0]  o_alu                               ,
  output wire [NB_ADDR                                - 1 : 0]  o_rd_addr                           ,
  output wire [NB_FUNC3                               - 1 : 0]  o_func3                             ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire                                                    i_reg_write                         ,
  input wire                                                    i_mem_to_reg                        ,
  input wire [NB_DATA                                 - 1 : 0]  i_data                              ,
  input wire [NB_DATA                                 - 1 : 0]  i_alu                               ,
  input wire [NB_ADDR                                 - 1 : 0]  i_rd_addr                           ,
  input wire [NB_FUNC3                                - 1 : 0]  i_func3                             ,
  input wire                                                    i_enable                            ,
  input wire                                                    clock                                  
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  reg                                                           reg_write_out                       ;
  reg                                                           mem_to_reg_out                      ;
  reg       [NB_DATA                                  - 1 : 0]  data_out                            ;
  reg       [NB_DATA                                  - 1 : 0]  alu_out                             ;
  reg       [NB_ADDR                                  - 1 : 0]  rd_addr_out                         ;
  reg       [NB_FUNC3                                 - 1 : 0]  func3_out                           ;

//--------------------------------------- Sequential Logic ---------------------------------------//
  always @(posedge clock) 
  begin
    if (i_enable) 
    begin
      reg_write_out       <= i_reg_write                                                            ;
      mem_to_reg_out      <= i_mem_to_reg                                                           ;
      data_out            <= i_data                                                                 ;
      alu_out             <= i_alu                                                                  ;
      rd_addr_out         <= i_rd_addr                                                              ;
      func3_out           <= i_func3                                                                ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_reg_write      = reg_write_out                                                           ;
  assign o_mem_to_reg     = mem_to_reg_out                                                          ;
  assign o_data           = data_out                                                                ;
  assign o_alu            = alu_out                                                                 ;
  assign o_rd_addr        = rd_addr_out                                                             ;
  assign o_func3          = func3_out                                                               ;

endmodule