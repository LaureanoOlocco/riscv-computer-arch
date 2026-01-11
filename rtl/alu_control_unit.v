//--------------------------------------------------------------------------------------------------
// Project      : RISC-V Computer Architecture
// Module name  : alu_control_unit.v
// Date         : 2025-12-20
// Author       : Sofía Avalos - Laureano Olocco
// Description  : ALU Control Unit for RISC-V architecture.
//                 - Determines the specific ALU operation based on ALUOp from the Control Unit
//                   and the funct7 and funct3 fields from the instruction.
//                 - Outputs a 6-bit ALU operation code to control the ALU module.
//--------------------------------------------------------------------------------------------------
`default nettype none

module alu_ctrl_unit
(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_ALU_OP     = 2                   ,
  parameter                                                     NB_OP_CODE    = 6                   , 
  parameter                                                     NB_FUNCT7     = 7                   ,
  parameter                                                     NB_FUNCT3     = 3
)
(
//------------------------------------------ OUTPUTS --------------------------------------------//
  // ALU Control Unit Output Ports
  output wire [NB_ALU_OP                              - 1 : 0]  o_alu_op_code                       ,  
//------------------------------------------- INPUTS ---------------------------------------------//                         
  // ALU Control Unit Input Ports                   
  input  wire [NB_ALU_OP                              - 1 : 0] i_alu_op                             ,  
  input  wire [NB_FUNCT7                              - 1 : 0] i_funct7                             ,  
  input  wire [NB_FUNCT3                              - 1 : 0] i_funct3                                
)                                                                                                   ;                                                                                       

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    ADD_OP      = 6'b100000             ;   
  localparam                                                    SUB_OP      = 6'b100010             ;
  localparam                                                    AND_OP      = 6'b100100             ;
  localparam                                                    OR_OP       = 6'b100101             ;
  localparam                                                    XOR_OP      = 6'b100110             ;
  localparam                                                    SRA_OP      = 6'b000011             ;
  localparam                                                    SRL_OP      = 6'b000010             ;
  localparam                                                    NOR_OP      = 6'b100111             ;

  localparam                                                    LD_ST_INSTR = 2'b00                 ;
  localparam                                                    BEQ_INSTR   = 2'b01                 ;
  localparam                                                    R_TYPE_INSTR= 2'b10                 ;

//--------------------------------------- Internal Signals ---------------------------------------//
  reg       [NB_OP_CODE                               - 1 : 0] output_alu_op                        ;

//----------------------------------- Calculate the ALU Operation --------------------------------//  
  always @(*) 
  begin
    case (i_alu_op)
      LD_ST_INSTR                                                                                   : 
      begin 
       output_alu_op  = ADD_OP                                                                      ;
      end
      BEQ_INSTR                                                                                     :
      begin 
       output_alu_op  = SUB_OP                                                                      ;
      end
      R_TYPE_INSTR                                                                                  : 
      begin // R-Type Instructions
          case ({i_funct7, i_funct3})
              10'b0000000000 : o_alu_op = ALU_ADD   ;
              10'b0100000000 : o_alu_op = ALU_SUB   ;
              10'b0000000100 : o_alu_op = ALU_XOR   ;
              10'b0000000110 : o_alu_op = ALU_OR    ;
              10'b0000000111 : o_alu_op = ALU_AND   ;
              10'b0000000001 : o_alu_op = ALU_SLL   ;
              10'b0000000101 : o_alu_op = ALU_SRL   ;
              10'b0100000101 : o_alu_op = ALU_SRA   ;
              10'b0000000010 : o_alu_op = ALU_SLT   ;
              10'b0000000011 : o_alu_op = ALU_SLTU  ;
              default        : o_alu_op = ALU_ADD   ;
          endcase
      end
      default: o_alu_op = ALU_ADD;
    endcase
  end

endmodule