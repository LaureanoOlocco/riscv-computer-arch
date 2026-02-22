//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : base_integer_ctrl_unit.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Base integer control unit for a RISC-V processor. 
//               This module generates the control signals based on the opcode and func3 fields of the 
//               instruction. It handles the main instruction types (R, I, S, B, U, J) and sets the 
//               appropriate control signals for each instruction type.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module base_integer_ctrl_unit
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_CTRL       = 9                   , // Number of control signals (e.g., RegWrite, MemRead, MemWrite, ALUSrc, MemToReg, Branch, ALUOp, DataSize)
  parameter                                                     NB_OPCODE     = 7                   , // Number of bits for opcode field in RISC-V instructions
  parameter                                                     NB_FUNC3      = 3                     // Number of bits for func3 field in RISC-V instructions                         
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  output wire [NB_CTRL                                - 1 : 0]  o_ctrl                              ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  input wire  [NB_OPCODE                              - 1 : 0]  i_opcode                            ,
  input wire  [NB_FUNC3                               - 1 : 0]  i_func3                                
)                                                                                                   ;

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    I_TYPE_1          = 7'b0010011      ; // OpCode for I-type instructions (e.g., addi, lui)
  localparam                                                    I_TYPE_2          = 7'b0000011      ; // OpCode for load instructions (e.g., lw, lh, lb)
  localparam                                                    I_TYPE_3          = 7'b1100111      ; // OpCode for jalr instruction
  localparam                                                    R_TYPE            = 7'b0110011      ; // OpCode for R-type instructions (e.g., add, sub, etc.)
  localparam                                                    J_TYPE            = 7'b1101111      ; // OpCode for J-type instructions (e.g., jal)
  localparam                                                    S_TYPE            = 7'b0100011      ; // OpCode for S-type instructions (e.g., sw, sh, sb)
  localparam                                                    B_TYPE            = 7'b1100011      ; // OpCode for B-type instructions (e.g., beq, bne, etc.)
  localparam                                                    U_TYPE            = 7'b0110111      ; // OpCode for U-type instructions (e.g., lui)

  localparam                                                    REG_WRITE_INDEX   = 0               ; 
  localparam                                                    MEM_READ_INDEX    = 1               ;
  localparam                                                    MEM_WRITE_INDEX   = 2               ;
  localparam                                                    ALU_SRC_INDEX     = 3               ;
  localparam                                                    MEM_TO_REG_INDEX  = 4               ;
  localparam                                                    ALU_OP_INDEX      = 5               ;
  localparam                                                    DATA_SIZE_INDEX   = 7               ;

  localparam                                                    LB_SB            = 3'b000           ;
  localparam                                                    LH_SH            = 3'b001           ;
  localparam                                                    LW_SW            = 3'b010           ;
  localparam                                                    LBU              = 3'b100           ;
  localparam                                                    LHU              = 3'b101           ;

  localparam                                                    BYTE             = 2'b01            ;
  localparam                                                    HALF             = 2'b10            ;
  localparam                                                    WORD             = 2'b11            ;
  localparam                                                    NONE             = 2'b00            ;
//------------------------------------------- Registers ------------------------------------------//
  reg       [NB_CTRL                                  - 1 : 0]  ctrl_out                            ;

//--------------------------------------- Combinational Logic ------------------------------------//

  always @(*) 
  begin
    ctrl_out = {NB_CTRL{1'b0}}                                                                      ;
    case (i_func3)
      LB_SB   : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = BYTE                              ; // Load/Store Byte
      LH_SH   : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = HALF                              ; // Load/Store Half-word
      LW_SW   : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = WORD                              ; // Load/Store Word
      LBU     : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = BYTE                              ; // Load Byte Unsigned
      LHU     : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = HALF                              ; // Load Half-word Unsigned
      default : ctrl_out[DATA_SIZE_INDEX + 1 : DATA_SIZE_INDEX] = NONE                              ; // Default case: no data size for unsupported instructions
    endcase 
    case (i_opcode)
      R_TYPE                                                                                        : 
      begin
        ctrl_out[REG_WRITE_INDEX                ] = 1'b1                                            ; // Enable register write for R-type instructions
        ctrl_out[ALU_OP_INDEX + 1 : ALU_OP_INDEX] = 2'b11                                           ; // ALU operation code for R-type instructions (e.g., add, sub, etc.)
      end
      I_TYPE_1                                                                                      : 
      begin
        ctrl_out[REG_WRITE_INDEX                ] = 1'b1                                            ; // Enable register write for I-type instructions (e.g., addi, lui)
        ctrl_out[ALU_SRC_INDEX                  ] = 1'b1                                            ; // Select immediate value as ALU source
        ctrl_out[ALU_OP_INDEX + 1 : ALU_OP_INDEX] = 2'b10                                           ; // ALU operation code for I-type instructions (e.g., addi)
      end
      I_TYPE_2                                                                                      : 
      begin
        ctrl_out[REG_WRITE_INDEX                ] = 1'b1                                            ; // Enable register write for load instructions (e.g., lw, lh, lb)
        ctrl_out[MEM_READ_INDEX                 ] = 1'b1                                            ; // Enable memory read for load instructions
        ctrl_out[ALU_SRC_INDEX                  ] = 1'b1                                            ; // Select immediate value as ALU source for address calculation
        ctrl_out[MEM_TO_REG_INDEX               ] = 1'b1                                            ; // Select memory data to write back to register for load instructions
      end
      S_TYPE                                                                                        : 
      begin
        ctrl_out[MEM_WRITE_INDEX                ] = 1'b1                                            ; // Enable memory write for store instructions (e.g., sw, sh, sb)
        ctrl_out[ALU_SRC_INDEX                  ] = 1'b1                                            ; // Select immediate value as ALU source for address calculation in store instructions
      end
      U_TYPE_1, U_TYPE_2                                                                            : 
      begin
        ctrl_out[REG_WRITE_INDEX                ] = 1'b1                                            ; // Enable register write for U-type instructions (e.g., lui, auipc)
        ctrl_out[ALU_SRC_INDEX                  ] = 1'b1                                            ; // Enable register write for U-type instructions (e.g., lui, auipc)
      end
      default                                                                                       : 
      begin
        ctrl_out                                  = {NB_CTRL{1'b0}}                                 ; // Default case: all control signals are set to 0 for unsupported instructions
      end
    endcase
  end

//-------------------------------------------- Outputs ------------------------------------------//
  assign o_ctrl           = ctrl_out                                                                ;

endmodule