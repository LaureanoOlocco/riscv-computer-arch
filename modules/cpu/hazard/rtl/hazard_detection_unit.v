//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : hazard_detection_unit.v
// Date        : 2026-01-15
// Author      : Sofía Avalos - Laureano Olocco
// Description : Hazard detection unit for stalling the pipeline when a load-use hazard is detected. 
//               This occurs when the instruction in the EX stage is a load and its destination 
//               register matches either source register of the instruction in the ID stage. In such
//               cases, the pipeline needs to be stalled for one cycle to allow the load instruction 
//               to complete and provide the correct data to the dependent instruction.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module hazard_detection_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_ADDR       = 5                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire                                                   o_write_enable                      ,
  output wire                                                   o_control_mux                       ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire                                                    i_id_ex_mem_read                    ,
  input wire [NB_ADDR                                 - 1 : 0]  i_id_ex_rd                          ,
  input wire [NB_ADDR                                 - 1 : 0]  i_if_id_rs1                         ,
  input wire [NB_ADDR                                 - 1 : 0]  i_if_id_rs2                            
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  reg                                                           write_enable_out                    ;
  reg                                                           control_mux_out                     ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    write_enable_out = 1'b1                                                                         ; 
    control_mux_out  = 1'b0                                                                         ;
    // Detect load-use hazard: if the instruction in the EX stage is a load and its destination register matches 
    // either source register of the instruction in the ID stage, stall the pipeline
    if (i_id_ex_mem_read && ((i_id_ex_rd == i_if_id_rs1) || (i_id_ex_rd == i_if_id_rs2))) 
    begin
      write_enable_out = 1'b0                                                                       ;
      control_mux_out  = 1'b1                                                                       ;
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_write_enable   = write_enable_out                                                        ;
  assign o_control_mux    = control_mux_out                                                         ;

endmodule