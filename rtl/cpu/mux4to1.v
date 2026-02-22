//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : mux4to1.v
// Date        : 2025-12-08
// Author      : Sofía Avalos - Laureano Olocco
// Description : 4 to 1 multiplexer module.
//                - Parameterizable data width via NB_MUX (default: 32).
//                - Parameterizable select width via NB_SELECT (default: 2).
//--------------------------------------------------------------------------------------------------

`default nettype none

module mux_4to1
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_MUX        = 32                  ,
  parameter                                                     NB_SELECT     = 2     
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//    
  // MUX Output Ports
  output wire [NB_MUX                                 - 1 : 0]  o_mux                               ,  
//------------------------------------------- INPUTS PORTS ----------------------------------------//                                 
  // Inputs                          
  input  wire [NB_MUX                                 - 1 : 0]  i_data_a                            , 
  input  wire [NB_MUX                                 - 1 : 0]  i_data_b                            , 
  input  wire [NB_MUX                                 - 1 : 0]  i_data_c                            , 
  input  wire [NB_MUX                                 - 1 : 0]  i_data_d                            ,
  input  wire [NB_SELECT                              - 1 : 0]  i_data_sel  
)                                                                                                   ;

//----------------------------------------- Local Params -----------------------------------------// 
  localparam                                                    DATA_A        = 2'b00               ;
  localparam                                                    DATA_B        = 2'b01               ;
  localparam                                                    DATA_C        = 2'b10               ;
  localparam                                                    DATA_D        = 2'b11               ;

//--------------------------------------- Internal Signals ---------------------------------------// 
  reg       [NB_MUX                                   - 1 : 0]  output_mux                          ;

//------------------------------------- Combinational Circuit ------------------------------------// 
  always @(*) 
  begin
    output_mux     = {NB_MUX{1'b0}}                                                                 ;
    case (i_data_sel)
      DATA_A                                                                                        : 
      begin
        output_mux = i_data_a                                                                       ; 
      end
      DATA_B                                                                                        : 
      begin
        output_mux = i_data_b                                                                       ; 
      end
      DATA_C                                                                                        :
      begin
        output_mux = i_data_c                                                                       ; 
      end
      DATA_D                                                                                        :
      begin
        output_mux = i_data_d                                                                       ; 
      end
    endcase
  end
    
//-------------------------------------------- Outputs -------------------------------------------// 
  assign o_mux     = output_mux                                                                     ;

endmodule
