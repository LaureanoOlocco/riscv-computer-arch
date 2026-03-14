//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : mux2to1.v
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : 2-to-1 Multiplexer module.
//                - Parameterizable data width (NB_MUX).
//               - Selects between two NB_MUX-bit inputs based on a 1-bit select signal.
//--------------------------------------------------------------------------------------------------

`default nettype none

module mux_2to1
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_MUX        = 32                
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//    
  // MUX Output Ports
  output wire [NB_MUX                                 - 1 : 0]  o_mux                               ,  
//------------------------------------------- INPUTS PORTS ----------------------------------------//                                 
  // Inputs                          
  input  wire [NB_MUX                                 - 1 : 0]  i_data_a                            , 
  input  wire [NB_MUX                                 - 1 : 0]  i_data_b                            , 
  input  wire                                                   i_data_sel  
)                                                                                                   ;

//----------------------------------------- Local Params -----------------------------------------// 
  localparam                                                    DATA_A        = 1'b0                ;
  localparam                                                    DATA_B        = 1'b1                ;

//--------------------------------------- Internal Signals ---------------------------------------// 
  reg       [NB_MUX                                   - 1 : 0]  output_mux                          ;

//------------------------------------- Combinational Circuit ------------------------------------// 
  always @(*) 
  begin
    output_mux = {NB_MUX{1'b0}}                                                                     ;
    case (i_data_sel)
      DATA_A                                                                                        : 
      begin
        output_mux = i_data_a                                                                       ; 
      end
      DATA_B                                                                                        : 
      begin
        output_mux = i_data_b                                                                       ; 
      end
    endcase
  end
    
//-------------------------------------------- Outputs -------------------------------------------// 
  assign o_mux    = output_mux                                                                      ;

endmodule
