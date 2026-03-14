//--------------------------------------------------------------------------------------------------
// Project      : RISC-V Computer Architecture
// Module name  : immediate_generator.v
// Date         : 2025-12-13
// Author       : Sofía Avalos - Laureano Olocco
// Description  : Immediate Generator module for RISC-V instructions.
//                 - Extracts and sign-extends immediate values from various RISC-V instruction formats:
//                     * R-Type: No immediate
//                     * I-Type: 12-bit immediate
//                     * S-Type: 12-bit immediate
//                     * B-Type: 13-bit immediate (branch offset)
//                     * U-Type: 20-bit immediate
//                     * J-Type: 21-bit immediate (jump offset)
//                 - Parameterizable data width (NB_DATA).
//--------------------------------------------------------------------------------------------------

`default nettype none

module imm_gen
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  
) 
(
//----------------------------------------- OUTPUTS PORTS ----------------------------------------//
  // Immediate Generator Output Ports
  output wire [NB_DATA                                - 1 : 0]  o_immediate                        ,
//------------------------------------------ INPUTS PORTS ----------------------------------------//
  // Immediate Generator Input Ports
  input wire  [NB_DATA                                - 1 : 0]  i_instruction 
)                                                                                                   ;

//---------------------------------------- Local Params ------------------------------------------//
  localparam                                                    NB_OPCODE = 7                       ;

  localparam                                                    R_TYPE    = 7'b0110011              ;  // Opcode for R-Type instructions (e.g., ADD, SUB)
  localparam                                                    I_TYPE_1  = 7'b0010011              ;  // Opcode for I-Type Immediate instructions (e.g., ADDI)
  localparam                                                    I_TYPE_2  = 7'b0000011              ;  // Opcode for I-Type Load instructions (e.g., LW)
  localparam                                                    I_TYPE_3  = 7'b1100111              ;  // Opcode for I-Type JALR instruction
  localparam                                                    S_TYPE    = 7'b0100011              ;  // Opcode for S-Type Store instructions (e.g., SW)
  localparam                                                    B_TYPE    = 7'b1100011              ;  // Opcode for B-Type Branch instructions (e.g., BEQ)
  localparam                                                    U_TYPE    = 7'b0110111              ;  // Opcode for U-Type LUI instruction
  localparam                                                    J_TYPE    = 7'b1101111              ;  // Opcode for J-Type JAL instruction
  
//--------------------------------------- Internal Signals ---------------------------------------//
  reg       [NB_DATA                                  - 1 : 0]  output_immediate                    ;   
  
//---------------------------------- Extract the Immediate Field --------------------------------//
  always @(*) 
  begin
    case (i_instruction[NB_OPCODE - 1 : 0])
        R_TYPE                                                                                      :
        begin
          // R-Type Instructions do not have an immediate value
          output_immediate = {NB_DATA{1'b0}}                                                        ; 
        end
        I_TYPE_1, I_TYPE_2, I_TYPE_3                                                                : 
        begin
          // I-Type Instructions: | Imm[11:0] | rs1 | funct3 | rd | opcode |
          output_immediate = {{20{i_instruction[31]}}, i_instruction[31:20]}                        ;
        end
        S_TYPE                                                                                      : 
        begin
          // S-Type Instructions: | Imm[11:5] | rs2 | rs1 | funct3 | Imm[4:0] | opcode |
          output_immediate = {{20{i_instruction[31]}}, i_instruction[31:25], i_instruction[11:7]}   ;
        end
        B_TYPE                                                                                      : 
        begin
          // B-Type Instructions: | Imm[12] | Imm[10:5] | rs2 | rs1 | funct3 | Imm[4:1] | Imm[11] | opcode |
          output_immediate = {{19{i_instruction[31]}}, i_instruction[31], i_instruction[7], i_instruction[30:25], i_instruction[11:8], 1'b0}; 
        end
        U_TYPE                                                                                      :
        begin
          // U-Type Instructions: | Imm[31:12] | rd | opcode |
          output_immediate = {i_instruction[31:12], 12'b0}                                          ; 
        end
        J_TYPE                                                                                      :
        begin
          // J-Type Instructions: | Imm[20] | Imm[10:1] | Imm[11] | Imm[19:12] | rd | opcode |
          output_immediate = {{11{i_instruction[31]}}, i_instruction[31], i_instruction[19:12], i_instruction[20], i_instruction[30:21], 1'b0} ; // J-Type: | Imm[20] | Imm[10:1] | Imm[11] | Imm[19:12] | rd | opcode |
        end
        default: 
        begin
          // Default case for unrecognized opcodes
          output_immediate = {NB_DATA{1'b0}}                                                        ; 
        end
    endcase
  end

//-------------------------------------------- Outputs -------------------------------------------//
  assign o_immediate = output_immediate                                                             ;

endmodule