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
#(
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
//----> ALU operation codes
  localparam                                                    ADD_OP            = 6'b100000       ;   
  localparam                                                    SUB_OP            = 6'b100010       ;
  localparam                                                    AND_OP            = 6'b100100       ;
  localparam                                                    OR_OP             = 6'b100101       ;
  localparam                                                    XOR_OP            = 6'b100110       ;
  localparam                                                    SRA_OP            = 6'b000011       ;
  localparam                                                    SRL_OP            = 6'b000010       ;
  localparam                                                    NOR_OP            = 6'b100111       ;
  localparam                                                    SLL_OP            = 6'b000000       ;
  localparam                                                    SLT_OP            = 6'b000100       ;
  localparam                                                    SLTU_OP           = 6'b000101       ;

//----> ALU Operations
  localparam                                                    LD_ST_INSTR       = 2'b00           ;
  localparam                                                    BEQ_INSTR         = 2'b01           ;
  localparam                                                    R_TYPE_INSTR      = 2'b10           ;
  localparam                                                    I_TYPE_INSTR      = 2'b11           ;

//----> R-Type funct3 codes
  localparam                                                    FUNCT3R_ADD_SUB   = 3'b000          ;
  localparam                                                    FUNCT3R_SLL       = 3'b001          ;
  localparam                                                    FUNCT3R_SLT       = 3'b010          ;
  localparam                                                    FUNCT3R_SLTU      = 3'b011          ;
  localparam                                                    FUNCT3R_XOR       = 3'b100          ;
  localparam                                                    FUNCT3R_SRL_SRA   = 3'b101          ;
  localparam                                                    FUNCT3R_OR        = 3'b110          ;
  localparam                                                    FUNCT3R_AND       = 3'b111          ;

//----> R-Type funct7 codes
  localparam                                                    FUNCT7R_ADD_SRL   = 7'b0000000      ;
  localparam                                                    FUNCT7R_SUB_SRA   = 7'b0100000      ;

//----> I-Type funct3 codes
  localparam                                                    FUNCT3I_ADDI      = 3'b000          ;
  localparam                                                    FUNCT3I_SLTI      = 3'b010          ;
  localparam                                                    FUNCT3I_SLTIU     = 3'b011          ;
  localparam                                                    FUNCT3I_XORI      = 3'b100          ;
  localparam                                                    FUNCT3I_ORI       = 3'b110          ;
  localparam                                                    FUNCT3I_ANDI      = 3'b111          ;
  localparam                                                    FUNCT3I_SLLI      = 3'b001          ;
  localparam                                                    FUNCT3I_SRLI_SRAI = 3'b101          ;

//----> I-Type funct7 codes
  localparam                                                    FUNCT7I_SRLI      = 7'b0000000      ;
  localparam                                                    FUNCT7I_SRAI      = 7'b0100000      ;

//--------------------------------------- Internal Signals ---------------------------------------//
  reg       [NB_OP_CODE                               - 1 : 0] output_alu_op                        ;

//----------------------------------- Calculate the ALU Operation --------------------------------//  
  always @(*) 
  begin
    output_alu_op     = ADD_OP                                                                      ; // Default operation
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
        case (i_funct3)
           FUNCT3R_ADD_SUB : output_alu_op = (i_funct7 == FUNCT7R_ADD_SRL) ? ADD_OP : SUB_OP        ;
           FUNCT3R_SLL     : output_alu_op = SLL_OP                                                 ;
           FUNCT3R_SLT     : output_alu_op = SLT_OP                                                 ;  
           FUNCT3R_SLTU    : output_alu_op = SLTU_OP                                                ;
           FUNCT3R_XOR     : output_alu_op = XOR_OP                                                 ;
           FUNCT3R_SRL_SRA : output_alu_op = (i_funct7 == FUNCT7R_ADD_SRL) ? SRL_OP : SRA_OP        ;
           FUNCT3R_OR      : output_alu_op = OR_OP                                                  ;
           FUNCT3R_AND     : output_alu_op = AND_OP                                                 ;
        endcase
      end
      I_TYPE_INSTR                                                                                  :
      begin // I-Type Instructions
        case (i_funct3)
          FUNCT3I_ADDI      : output_alu_op = ADD_OP                                                ;
          FUNCT3I_SLTI      : output_alu_op = SLT_OP                                                ;
          FUNCT3I_SLTIU     : output_alu_op = SLTU_OP                                               ;
          FUNCT3I_XORI      : output_alu_op = XOR_OP                                                ;
          FUNCT3I_ORI       : output_alu_op = OR_OP                                                 ;
          FUNCT3I_ANDI      : output_alu_op = AND_OP                                                ;
          FUNCT3I_SLLI      : output_alu_op = SLL_OP                                                ;
          FUNCT3I_SRLI_SRAI : output_alu_op = (i_funct7 == FUNCT7I_SRLI) ? SRL_OP : SRA_OP          ;
        endcase
      end
    endcase
  end

//-------------------------------------------- Outputs -------------------------------------------//
  assign o_alu_op_code = output_alu_op                                                               ;

endmodule