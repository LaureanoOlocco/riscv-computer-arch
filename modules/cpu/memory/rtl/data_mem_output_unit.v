//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : data_mem_output_unit.v
// Date        : 2026-01-15
// Author      : Sofia Avalos - Laureano Olocco
// Description : Data memory output unit for handling the output data from memory reads. 
//               This unit takes the raw data read from memory and performs sign extension or zero extension
//               based on the function code (i_func3) to produce the final output data.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module data_mem_output_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,
  parameter                                                     NB_FUNC3      = 3                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_DATA                                - 1 : 0]  o_data                              ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input  wire [NB_DATA                                - 1 : 0]  i_data                              ,
  input  wire [NB_FUNC3                               - 1 : 0]  i_func3                                
)                                                                                                   ;

//------------------------------------------- Registers ------------------------------------------//
  localparam                                                    LB_SB            = 3'b000           ;
  localparam                                                    LH_SH            = 3'b001           ;
  localparam                                                    LW_SW            = 3'b010           ;
  localparam                                                    LBU              = 3'b100           ;
  localparam                                                    LHU              = 3'b101           ;

  localparam                                                    NB_BYTE          = 8                ;
  localparam                                                    NB_HALF          = 16               ;
  localparam                                                    NB_WORD          = 32               ;

  reg       [NB_DATA                                  - 1 : 0]  data_out                            ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    data_out = i_data                                                                               ;
    case (i_func3)
      LB_SB   : data_out = {{(NB_DATA - NB_BYTE){i_data[7 ]}}, i_data[7  : 0]}                      ;
      LH_SH   : data_out = {{(NB_DATA - NB_HALF){i_data[15]}}, i_data[15 : 0]}                      ;
      LW_SW   : data_out = i_data                                                                   ;
      LBU     : data_out = {{(NB_DATA - NB_BYTE){1'b0      }}, i_data[7  : 0]}                      ;
      LHU     : data_out = {{(NB_DATA - NB_HALF){1'b0      }}, i_data[15 : 0]}                      ;
      default : data_out = i_data                                                                   ;
    endcase
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_data           = data_out                                                                ;

endmodule