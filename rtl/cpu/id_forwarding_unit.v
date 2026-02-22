//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : id_forwarding_unit.v
// Date        : 2026-01-15
// Author      : Sofía Avalos - Laureano Olocco
// Description : Instruction Decode stage forwarding unit for handling data hazards when the instruction 
//               in ID stage needs to forward data to itself from the instructions in MEM or WB stages.
//               This unit checks for hazards on both source registers (rs1 and rs2) used in the ID stage,
//               as the instruction in ID stage may need to forward data for both registers if they are 
//               used in the same instruction (e.g., R-type instructions).
//               It also ensures that forwarding from MEM stage only occurs if the instruction in MEM stage 
//               is not a load, as load data is not available until the end of MEM stage.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module id_forwarding_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_ADDR       = 5                   ,
  parameter                                                     NB_FORWARD    = 2                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_FORWARD                             - 1 : 0]  o_forward_a                         ,
  output wire [NB_FORWARD                             - 1 : 0]  o_forward_b                         ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire [NB_ADDR                                 - 1 : 0]  i_id_rs1                            ,
  input wire [NB_ADDR                                 - 1 : 0]  i_id_rs2                            ,
  input wire [NB_ADDR                                 - 1 : 0]  i_mem_rd                            ,
  input wire [NB_ADDR                                 - 1 : 0]  i_wb_rd                             ,
  input wire                                                    i_mem_reg_write                     ,
  input wire                                                    i_wb_reg_write                      ,
  input wire                                                    i_mem_mem_read                         
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  reg       [NB_FORWARD                               - 1 : 0]  forward_a_out                       ;
  reg       [NB_FORWARD                               - 1 : 0]  forward_b_out                       ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    forward_a_out = 2'b00                                                                           ;
    forward_b_out = 2'b00                                                                           ;
    // Check for forwarding from MEM stage (only if it's not a load, as load data is not available until the end of MEM stage)
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_id_rs1) && ~i_mem_mem_read) 
    begin
      forward_a_out = 2'b01                                                                         ;
    end 
    // Check for forwarding from WB stage
    else if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_id_rs1)) 
    begin
      forward_a_out = 2'b10                                                                         ;
    end
    
    // Check for forwarding from MEM stage (only if it's not a load, as load data is not available until the end of MEM stage)
    if (i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_id_rs2) && ~i_mem_mem_read) 
    begin
      forward_b_out = 2'b01                                                                         ;
    end 
    // Check for forwarding from WB stage
    else if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_id_rs2)) 
    begin
      forward_b_out = 2'b10                                                                         ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_forward_a      = forward_a_out                                                           ;
  assign o_forward_b      = forward_b_out                                                           ;

endmodule