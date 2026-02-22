//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : mux4to1.v
// Date        : 2025-12-08
// Author      : Sofía Avalos - Laureano Olocco
// Description : Program Counter (PC) module for a RISC-V processor. 
//               This module holds the current value of the program counter and updates it based on 
//               the input control signals. It supports synchronous reset and write enable functionality 
//               to allow for proper PC updates during instruction fetch and branch/jump operations.
//--------------------------------------------------------------------------------------------------

`default nettype none

module pc
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_PC         = 32               
) 
(
//---------------------------------------- OUTPUTS PORTS -----------------------------------------//    
  // PC Output Ports
  output wire [NB_PC                                  - 1 : 0]  o_pc                                ,  
//----------------------------------------- INPUTS PORTS -----------------------------------------// 
  // PC Inputs Ports
  input  wire [NB_PC                                  - 1 : 0]  i_pc                                ,  
  input  wire                                                   i_write_en                          ,  
  // General Input ports
  input  wire                                                   i_reset                             ,  
  input  wire                                                   clock     
)                                                                                                   ;

//--------------------------------------- Internal Signals ---------------------------------------// 
  reg       [NB_PC                                    - 1 : 0]  output_pc                           ; 

//-------------------------------------- Program Counter Seq -------------------------------------// 
  always @(posedge clock) 
  begin
    if (i_reset) 
    begin
      output_pc  <= {NB_PC{1'b0}}                                                                   ;
    end
    else if (i_write_en) 
    begin
      output_pc  <= i_pc                                                                            ;
    end
  end
  
//-------------------------------------------- Outputs -------------------------------------------// 
  assign o_pc    = output_pc                                                                         ;

endmodule