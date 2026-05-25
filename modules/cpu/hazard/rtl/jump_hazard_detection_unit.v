//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : jump_hazard_detection_unit.v
// Date        : 2026-01-15
// Author      : Sofía Avalos - Laureano Olocco
// Description : Jump hazard detection unit for handling control hazards.
//               This unit detects hazards related to jump and branch instructions. It checks if the
//               instruction in the EX stage is writing to a register that is being read by a jump or branch
//               instruction in the ID stage. If such a hazard is detected, it stalls the pipeline to ensure
//               correct execution of the jump or branch instruction.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module jump_hazard_detection_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_OPCODE     = 7                   ,
  parameter                                                     NB_ADDR       = 5                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire                                                   o_write_enable                      ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire [NB_OPCODE                               - 1 : 0]  i_opcode                            ,
  input wire                                                    i_ex_reg_write                      ,
  input wire [NB_ADDR                                 - 1 : 0]  i_ex_rd                             ,
  input wire [NB_ADDR                                 - 1 : 0]  i_id_rs1                            ,
  input wire [NB_ADDR                                 - 1 : 0]  i_id_rs2                            ,
  input wire                                                    clock                                  
)                                                                                                   ;

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    I_TYPE_3      = 7'b1100111          ;
  localparam                                                    B_TYPE        = 7'b1100011          ;

//------------------------------------------- Registers ------------------------------------------//
  reg                                                           write_enable_out                    ;
  reg                                                           not_stall                           ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    write_enable_out = 1'b1                                                                         ;

    if (i_opcode == I_TYPE_3) 
    begin
      if (i_ex_reg_write && (i_ex_rd == i_id_rs1) && not_stall) 
      begin
        write_enable_out = 1'b0                                                                     ;
      end
    end
    if (i_opcode == B_TYPE) 
    begin
      if (i_ex_reg_write && ((i_ex_rd == i_id_rs1) || (i_ex_rd == i_id_rs2)) && not_stall) 
      begin
        write_enable_out = 1'b0                                                                     ;
      end
    end
  end

//--------------------------------------- Sequential Logic ---------------------------------------//
  always @(posedge clock) 
  begin
    not_stall <= o_write_enable                                                                     ;
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_write_enable   = write_enable_out                                                        ;

endmodule