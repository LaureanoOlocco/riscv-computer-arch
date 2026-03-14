//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : adder.v
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : Simple parameterizable adder module.
//                - Adds two NB_ADDER-bit inputs and produces an NB_ADDER-bit output.
//                - Purely combinational design.
//--------------------------------------------------------------------------------------------------

`default nettype none

module adder
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_ADDER      = 32                
) 
(
//----------------------------------------- OUTPUTS PORTS ----------------------------------------//    
  // Adder Output Ports
  output wire [NB_ADDER                               - 1 : 0]  o_result                            ,
//------------------------------------------ INPUTS PORTS ----------------------------------------// 
  // PC Inputs Ports                                       
  input  wire [NB_ADDER                               - 1 : 0]  i_data_a                            ,  
  input  wire [NB_ADDER                               - 1 : 0]  i_data_b     
)                                                                                                   ;

//-------------------------------------------- Outputs -------------------------------------------// 
  assign o_result = i_data_a + i_data_b                                                             ;
  
endmodule
