//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : jump_ctrl_unit.v
// Date        : 2026-01-15
// Author      : Sofía Avalos - Laureano Olocco
// Description : Jump control unit for handling jump and branch instructions. This unit generates 
//               control signals for determining the next PC source, whether to write to the 
//               register file, and whether to flush the pipeline based on the opcode of the
//               instruction in the ID stage. It also takes into account whether the pipeline is 
//               currently stalled to avoid generating control signals for jump or branch instructions
//               when the pipeline is stalled, which could lead to incorrect behavior.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module jump_ctrl_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_PC         = 32                  ,
  parameter                                                     NB_OPCODE     = 7                   ,
  parameter                                                     NB_PC_SRC     = 2                                            
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_PC_SRC                              - 1 : 0]  o_pc_src                            ,
  output wire                                                   o_reg_write                         ,
  output wire                                                   o_flush                             ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire [NB_OPCODE                               - 1 : 0]  i_opcode                            ,
  input wire                                                    i_stall                                
)                                                                                                   ;

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    J_TYPE        = 7'b1101111          ;
  localparam                                                    I_TYPE_3      = 7'b1100111          ;

//------------------------------------------- Registers ------------------------------------------//
  reg       [NB_PC_SRC                                - 1 : 0]  pc_src_out                          ;
  reg                                                           reg_write_out                       ;
  reg                                                           flush_out                           ;

//--------------------------------------- Combinational Logic ------------------------------------//
  always @(*) 
  begin
    pc_src_out          = 2'b00                                                                     ;
    reg_write_out       = 1'b0                                                                      ;
    flush_out           = 1'b0                                                                      ;
    
    if (~i_stall) 
    begin
      case (i_opcode)
        J_TYPE: 
        begin
          pc_src_out    = 2'b01                                                                     ;
          reg_write_out = 1'b1                                                                      ;
          flush_out     = 1'b1                                                                      ;
        end
        I_TYPE_3: 
        begin
          pc_src_out    = 2'b10                                                                     ;
          reg_write_out = 1'b1                                                                      ;
          flush_out     = 1'b1                                                                      ;
        end
        default: 
        begin
          pc_src_out    = 2'b00                                                                     ;
          reg_write_out = 1'b0                                                                      ;
          flush_out     = 1'b0                                                                      ;
        end
      endcase
    end
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_pc_src       = pc_src_out                                                                ;
  assign o_reg_write    = reg_write_out                                                             ;
  assign o_flush        = flush_out                                                                 ;

endmodule