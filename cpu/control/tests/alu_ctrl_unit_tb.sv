//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : tb_alu_ctrl_unit.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the ALU Control Unit module.
//                - Covers: all ALUOp classes, all funct3/funct7 combinations for R and I types.
//                - Uses SVA assertions and a golden model lookup table.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module alu_ctrl_unit_tb                                                                           ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                       NB_ALU_OP   = 2                   ;
  localparam int unsigned                                       NB_OP_CODE  = 6                   ;
  localparam int unsigned                                       NB_FUNCT7   = 7                   ;
  localparam int unsigned                                       NB_FUNCT3   = 3                   ;
  localparam int unsigned                                       CLK_PERIOD  = 10                  ;

//----> ALUOp classes
  localparam logic [NB_ALU_OP  - 1 : 0]                         LD_ST       = 2'b00               ;
  localparam logic [NB_ALU_OP  - 1 : 0]                         BEQ         = 2'b01               ;
  localparam logic [NB_ALU_OP  - 1 : 0]                         R_TYPE      = 2'b10               ;
  localparam logic [NB_ALU_OP  - 1 : 0]                         I_TYPE      = 2'b11               ;

//----> Expected op codes
  localparam logic [NB_OP_CODE - 1 : 0]                         ADD_OP      = 6'b100000           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SUB_OP      = 6'b100010           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         AND_OP      = 6'b100100           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         OR_OP       = 6'b100101           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         XOR_OP      = 6'b100110           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SRA_OP      = 6'b000011           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SRL_OP      = 6'b000010           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SLL_OP      = 6'b000000           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SLT_OP      = 6'b000100           ;
  localparam logic [NB_OP_CODE - 1 : 0]                         SLTU_OP     = 6'b000101           ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_OP_CODE                          - 1 : 0]  o_alu_op_code                     ;
  logic          [NB_ALU_OP                           - 1 : 0]  i_alu_op                          ;
  logic          [NB_FUNCT7                           - 1 : 0]  i_funct7                          ;
  logic          [NB_FUNCT3                           - 1 : 0]  i_funct3                          ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                             ;
  initial  clock = 1'b0                                                                           ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                    ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  alu_ctrl_unit
  #(
    .NB_ALU_OP                                                   ( NB_ALU_OP     ),
    .NB_OP_CODE                                                  ( NB_OP_CODE    ),
    .NB_FUNCT7                                                   ( NB_FUNCT7     ),
    .NB_FUNCT3                                                   ( NB_FUNCT3     )
  ) 
  u_alu_ctrl_unit 
  (
    .o_alu_op_code                                               ( o_alu_op_code ),
    .i_alu_op                                                    ( i_alu_op      ),
    .i_funct7                                                    ( i_funct7      ),
    .i_funct3                                                    ( i_funct3      )
  )                                                                                               ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_OP_CODE - 1 : 0] f_expected (
    input  logic   [NB_ALU_OP  - 1 : 0]                         alu_op                            ,
    input  logic   [NB_FUNCT7  - 1 : 0]                         funct7                            ,
    input  logic   [NB_FUNCT3  - 1 : 0]                         funct3
  )                                                                                               ;
    case (alu_op)
      LD_ST   : f_expected = ADD_OP                                                               ;
      BEQ     : f_expected = SUB_OP                                                               ;
      R_TYPE  :
        case (funct3)
          3'b000  : f_expected = (funct7 == 7'b0000000) ? ADD_OP  : SUB_OP                        ;
          3'b001  : f_expected = SLL_OP                                                           ;
          3'b010  : f_expected = SLT_OP                                                           ;
          3'b011  : f_expected = SLTU_OP                                                          ;
          3'b100  : f_expected = XOR_OP                                                           ;
          3'b101  : f_expected = (funct7 == 7'b0000000) ? SRL_OP  : SRA_OP                        ;
          3'b110  : f_expected = OR_OP                                                            ;
          3'b111  : f_expected = AND_OP                                                           ;
          default : f_expected = ADD_OP                                                           ;
        endcase
      I_TYPE  :
        case (funct3)
          3'b000  : f_expected = ADD_OP                                                           ;
          3'b010  : f_expected = SLT_OP                                                           ;
          3'b011  : f_expected = SLTU_OP                                                          ;
          3'b100  : f_expected = XOR_OP                                                           ;
          3'b110  : f_expected = OR_OP                                                            ;
          3'b111  : f_expected = AND_OP                                                           ;
          3'b001  : f_expected = SLL_OP                                                           ;
          3'b101  : f_expected = (funct7 == 7'b0000000) ? SRL_OP  : SRA_OP                        ;
          default : f_expected = ADD_OP                                                           ;
        endcase
      default : f_expected = ADD_OP                                                               ;
    endcase
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_correct_decode                                                                       ;
    @(posedge clock) o_alu_op_code == f_expected(i_alu_op, i_funct7, i_funct3)                    ;
  endproperty
  a_correct_decode : assert property (p_correct_decode)
    else $error("[ASSERT FAIL] a_correct_decode | alu_op=%0b f3=%0b f7=%0b | got=%0b exp=%0b"     ,
                 i_alu_op, i_funct3, i_funct7, o_alu_op_code,
                 f_expected(i_alu_op, i_funct7, i_funct3))                                        ;

  // LD/ST always produces ADD
  property p_ldst_is_add                                                                          ;
    @(posedge clock) (i_alu_op == LD_ST) |-> (o_alu_op_code == ADD_OP)                            ;
  endproperty
  a_ldst_is_add : assert property (p_ldst_is_add)
    else $error("[ASSERT FAIL] a_ldst_is_add | got=%0b", o_alu_op_code)                           ;

  // BEQ always produces SUB
  property p_beq_is_sub                                                                           ;
    @(posedge clock) (i_alu_op == BEQ) |-> (o_alu_op_code == SUB_OP)                              ;
  endproperty
  a_beq_is_sub : assert property (p_beq_is_sub)
    else $error("[ASSERT FAIL] a_beq_is_sub | got=%0b", o_alu_op_code)                            ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_ALU_OP  - 1 : 0]                         alu_op                            ,
    input  logic   [NB_FUNCT7  - 1 : 0]                         funct7                            ,
    input  logic   [NB_FUNCT3  - 1 : 0]                         funct3                            ,
    input  string                                               test_name
  )                                                                                               ;
    logic          [NB_OP_CODE - 1 : 0]                          expected                         ;
    i_alu_op  = alu_op                                                                            ;
    i_funct7  = funct7                                                                            ;
    i_funct3  = funct3                                                                            ;
    #1                                                                                            ;
    expected  = f_expected(alu_op, funct7, funct3)                                                ;
    if (o_alu_op_code !== expected)
      $error  ("[FAIL] %s | alu_op=%0b f3=%0b f7=%0b | got=%0b exp=%0b"                           ,
                test_name, alu_op, funct3, funct7, o_alu_op_code, expected)                       ;
    else
      $display("[PASS] %s | alu_op=%0b f3=%0b f7=%0b | opcode=%0b"                                ,
                test_name, alu_op, funct3, funct7, o_alu_op_code)                                 ;
    @(posedge clock)                                                                              ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_alu_op = '0; i_funct7 = '0; i_funct3 = '0                                                   ;
    @(posedge clock)                                                                              ;

    $display("\n===== TB ALU CTRL UNIT — START =====\n")                                          ;

    //-- LD/ST and BEQ (funct3/funct7 don't matter) ----------------------------------------//
    check( LD_ST,  7'b0, 3'b000, "LD/ST → ADD"          )                                         ;
    check( LD_ST,  7'b1, 3'b111, "LD/ST funct ignored"  )                                         ;
    check( BEQ,    7'b0, 3'b000, "BEQ  → SUB"           )                                         ;
    check( BEQ,    7'b1, 3'b111, "BEQ  funct ignored"   )                                         ;

    //-- R-Type exhaustive -----------------------------------------------------------------//
    check( R_TYPE, 7'b0000000, 3'b000, "R ADD"  )                                                 ;
    check( R_TYPE, 7'b0100000, 3'b000, "R SUB"  )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b001, "R SLL"  )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b010, "R SLT"  )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b011, "R SLTU" )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b100, "R XOR"  )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b101, "R SRL"  )                                                 ;
    check( R_TYPE, 7'b0100000, 3'b101, "R SRA"  )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b110, "R OR"   )                                                 ;
    check( R_TYPE, 7'b0000000, 3'b111, "R AND"  )                                                 ;

    //-- I-Type exhaustive -----------------------------------------------------------------//
    check( I_TYPE, 7'b0,       3'b000, "I ADDI"      )                                            ;
    check( I_TYPE, 7'b0,       3'b010, "I SLTI"      )                                            ;
    check( I_TYPE, 7'b0,       3'b011, "I SLTIU"     )                                            ;
    check( I_TYPE, 7'b0,       3'b100, "I XORI"      )                                            ;
    check( I_TYPE, 7'b0,       3'b110, "I ORI"       )                                            ;
    check( I_TYPE, 7'b0,       3'b111, "I ANDI"      )                                            ;
    check( I_TYPE, 7'b0,       3'b001, "I SLLI"      )                                            ;
    check( I_TYPE, 7'b0000000, 3'b101, "I SRLI"      )                                            ;
    check( I_TYPE, 7'b0100000, 3'b101, "I SRAI"      )                                            ;

    $display("\n===== TB ALU CTRL UNIT — DONE  =====\n")                                          ;
    $finish                                                                                       ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * 200)                                                                           ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                            ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("alu_ctrl_unit_tb.vcd")                                                             ;
    $dumpvars(0, alu_ctrl_unit_tb)                                                                ;
  end

endmodule
