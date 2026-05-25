//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : mem_forwarding_unit.v
// Date        : 2026-01-15
// Author      : Sofía Avalos - Laureano Olocco
// Description : Memory stage forwarding unit for handling data hazards when the instruction in MEM 
//               stage needs to forward data to the next instruction in EX stage.
//               This unit specifically checks for hazards on the second source register (rs2) used 
//               in store instructions, as the first source register (rs1) is typically used for address
//               calculation and is handled by the EX forwarding unit.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module mem_forwarding_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_ADDR       = 5                   ,
  parameter                                                     NB_FORWARD    = 2                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_FORWARD                             - 1 : 0]  o_forward_b                         ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire [NB_ADDR                                 - 1 : 0]  i_mem_rs2                           ,
  input wire [NB_ADDR                                 - 1 : 0]  i_wb_rd                             ,
  input wire                                                    i_wb_reg_write                         
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  reg       [NB_FORWARD                               - 1 : 0]  forward_b_out                       ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    forward_b_out = 2'b00                                                                           ;
    
    if (i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_mem_rs2)) 
    begin
      forward_b_out = 2'b01                                                                         ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_forward_b      = forward_b_out                                                           ;

endmodule