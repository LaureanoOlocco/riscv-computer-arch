//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : tb_alu.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the parameterizable ALU module.
//                - Covers: all opcodes, zero flag, carry flag, overflow, random stimulus.
//                - Uses SVA assertions to verify combinational behavior.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module alu_tb                                                                                       ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_DATA     = 32                   ;
  localparam int unsigned                                        NB_OP_CODE  = 6                    ;
  localparam int unsigned                                        N_RANDOM    = 1000                 ;
  localparam int unsigned                                        CLK_PERIOD  = 10                   ;

//----------------------------------------- OP CODES --------------------------------------------//
  localparam logic [NB_OP_CODE - 1 : 0]                          ADD_OP      = 6'b100000            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          SUB_OP      = 6'b100010            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          AND_OP      = 6'b100100            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          OR_OP       = 6'b100101            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          XOR_OP      = 6'b100110            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          SRA_OP      = 6'b000011            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          SRL_OP      = 6'b000010            ;
  localparam logic [NB_OP_CODE - 1 : 0]                          NOR_OP      = 6'b100111            ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_DATA                             - 1 : 0]  o_result                            ;
  logic                                                         o_zero                              ;
  logic                                                         o_carry                             ;
  logic          [NB_DATA                             - 1 : 0]  i_data_a                            ;
  logic          [NB_DATA                             - 1 : 0]  i_data_b                            ;
  logic          [NB_OP_CODE                          - 1 : 0]  i_op_code                           ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                               ;
  initial  clock = 1'b0                                                                             ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                      ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  alu
  #(
    .NB_DATA                                                     ( NB_DATA    )                     ,
    .NB_OP_CODE                                                  ( NB_OP_CODE )                     
  ) u_alu (                     
    .o_result                                                    ( o_result   )                     ,
    .o_zero                                                      ( o_zero     )                     ,
    .o_carry                                                     ( o_carry    )                     ,
    .i_data_a                                                    ( i_data_a   )                     ,
    .i_data_b                                                    ( i_data_b   )                     ,
    .i_op_code                                                   ( i_op_code  )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_DATA - 1 : 0] f_result (
    input  logic   [NB_DATA     - 1 : 0]                         a                                  ,
    input  logic   [NB_DATA     - 1 : 0]                         b                                  ,
    input  logic   [NB_OP_CODE  - 1 : 0]                         op
  )                                                                                                 ;
    case (op)
      ADD_OP  : f_result = a + b                                                                    ;
      SUB_OP  : f_result = a - b                                                                    ;
      AND_OP  : f_result = a & b                                                                    ;
      OR_OP   : f_result = a | b                                                                    ;
      XOR_OP  : f_result = a ^ b                                                                    ;
      SRA_OP  : f_result = $signed(a) >>> b[$clog2(NB_DATA) - 1 : 0]                                ;
      SRL_OP  : f_result = a >> b[$clog2(NB_DATA) - 1 : 0]                                          ;
      NOR_OP  : f_result = ~(a | b)                                                                 ;
      default : f_result = '0                                                                       ;
    endcase
  endfunction

  function automatic logic f_zero (
    input  logic   [NB_DATA     - 1 : 0]                         result
  )                                                                                                 ;
    f_zero = ~(|result)                                                                             ;
  endfunction

  function automatic logic f_carry (
    input  logic   [NB_DATA     - 1 : 0]                         a                                  ,
    input  logic   [NB_DATA     - 1 : 0]                         b                                  ,
    input  logic   [NB_OP_CODE  - 1 : 0]                         op
  )                                                                                                 ;
    logic [NB_DATA : 0] ext                                                                         ;
    case (op)
      ADD_OP  : begin ext = {1'b0, a} + {1'b0, b}; f_carry = ext[NB_DATA];  end
      SUB_OP  : begin ext = {1'b0, a} - {1'b0, b}; f_carry = ~ext[NB_DATA]; end
      default : f_carry = 1'b0                                                                      ;
    endcase
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  // 1. Result matches golden model
  property p_correct_result                                                                         ;
    @(posedge clock) o_result == f_result(i_data_a, i_data_b, i_op_code)                            ;
  endproperty
  a_correct_result : assert property (p_correct_result)
    else $error("[ASSERT FAIL] a_correct_result | op=%0b a=%0h b=%0h | got=%0h expected=%0h"        ,
                 i_op_code, i_data_a, i_data_b, o_result,
                 f_result(i_data_a, i_data_b, i_op_code))                                           ;

  // 2. Zero flag correctness
  property p_zero_flag                                                                              ;
    @(posedge clock) o_zero == f_zero(o_result)                                                     ;
  endproperty
  a_zero_flag : assert property (p_zero_flag)
    else $error("[ASSERT FAIL] a_zero_flag | result=%0h o_zero=%0b", o_result, o_zero)              ;

  // 3. Zero flag high when both inputs zero and op is ADD
  property p_zero_on_zero_inputs                                                                    ;
    @(posedge clock) (i_data_a == '0 && i_data_b == '0 && i_op_code == ADD_OP) |-> o_zero           ;
  endproperty
  a_zero_on_zero_inputs : assert property (p_zero_on_zero_inputs)
    else $error("[ASSERT FAIL] a_zero_on_zero_inputs")                                              ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_DATA    - 1 : 0]                          a                                  ,
    input  logic   [NB_DATA    - 1 : 0]                          b                                  ,
    input  logic   [NB_OP_CODE - 1 : 0]                          op                                 ,
    input  string                                                test_name
  )                                                                                                 ;
    logic          [NB_DATA    - 1 : 0]                          exp_result                         ;
    logic                                                        exp_zero                           ;
    logic                                                        exp_carry                          ;
    i_data_a  = a                                                                                   ;
    i_data_b  = b                                                                                   ;
    i_op_code = op                                                                                  ;
    #1                                                                                              ;
    exp_result = f_result(a, b, op)                                                                 ;
    exp_zero   = f_zero(exp_result)                                                                 ;
    exp_carry  = f_carry(a, b, op)                                                                  ;
    if (o_result !== exp_result || o_zero !== exp_zero || o_carry !== exp_carry)
      $error  ("[FAIL] %s | op=%0b a=%0h b=%0h | got=(%0h,z%0b,c%0b) exp=(%0h,z%0b,c%0b)"           ,
                test_name, op, a, b, o_result, o_zero, o_carry,
                exp_result, exp_zero, exp_carry)                                                    ;
    else
      $display("[PASS] %s | op=%0b a=%0h b=%0h | result=%0h z=%0b c=%0b"                            ,
                test_name, op, a, b, o_result, o_zero, o_carry)                                     ;
    @(posedge clock)                                                                                ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_data_a  = '0                                                                                  ;
    i_data_b  = '0                                                                                  ;
    i_op_code = ADD_OP                                                                              ;
    @(posedge clock)                                                                                ;

    $display("\n===== TB ALU — START =====\n")                                                      ;

    //-- ADD corner cases ------------------------------------------------------------------//
    check( '0,                   '0,                  ADD_OP, "ADD  0+0"         )                  ;
    check( '1,                   '0,                  ADD_OP, "ADD  1+0"         )                  ;
    check( {NB_DATA{1'b1}},      '1,                  ADD_OP, "ADD  MAX+1 (ovf)" )                  ;
    check( {NB_DATA{1'b1}},      {NB_DATA{1'b1}},     ADD_OP, "ADD  MAX+MAX"     )                  ;

    //-- SUB corner cases ------------------------------------------------------------------//
    check( '0,                   '0,                  SUB_OP, "SUB  0-0"         )                  ;
    check( '1,                   '1,                  SUB_OP, "SUB  1-1=0"       )                  ;
    check( '0,                   '1,                  SUB_OP, "SUB  0-1 (borrow)")                  ;
    check( {NB_DATA{1'b1}},      {NB_DATA{1'b1}},     SUB_OP, "SUB  MAX-MAX=0"   )                  ;

    //-- Logic ops corner cases ------------------------------------------------------------//
    check( {NB_DATA{1'b1}},      {NB_DATA{1'b1}},     AND_OP, "AND  MAX&MAX"      )                 ;
    check( '0,                   {NB_DATA{1'b1}},     AND_OP, "AND  0&MAX=0"      )                 ;
    check( '0,                   '0,                  OR_OP,  "OR   0|0=0"        )                 ;
    check( {NB_DATA{1'b1}},      '0,                  OR_OP,  "OR   MAX|0=MAX"    )                 ;
    check( {NB_DATA{1'b1}},      {NB_DATA{1'b1}},     XOR_OP, "XOR  MAX^MAX=0"   )                  ;
    check( {NB_DATA{1'b1}},      '0,                  XOR_OP, "XOR  MAX^0=MAX"   )                  ;
    check( '0,                   '0,                  NOR_OP, "NOR  0 NOR 0=MAX" )                  ;
    check( {NB_DATA{1'b1}},      '0,                  NOR_OP, "NOR  MAX NOR 0=0" )                  ;

    //-- Shift corner cases ----------------------------------------------------------------//
    check( 32'h8000_0000,        32'h1,               SRA_OP, "SRA  MSB>>1"       )                 ;
    check( 32'h8000_0000,        32'h1f,              SRA_OP, "SRA  MSB>>31"      )                 ;
    check( 32'h8000_0000,        32'h1,               SRL_OP, "SRL  MSB>>1"       )                 ;
    check( 32'hFFFF_FFFF,        32'h0,               SRL_OP, "SRL  MAX>>0"       )                 ;

    //-- Random stimulus -------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d per opcode) ---", N_RANDOM)                                 ;
    begin
      logic [NB_DATA    - 1 : 0] ra                                                                 ;
      logic [NB_DATA    - 1 : 0] rb                                                                 ;
      foreach ({ADD_OP, SUB_OP, AND_OP, OR_OP, XOR_OP, SRA_OP, SRL_OP, NOR_OP}[i]) begin
        automatic logic [NB_OP_CODE-1:0] op = {ADD_OP, SUB_OP, AND_OP, OR_OP,
                                                XOR_OP, SRA_OP, SRL_OP, NOR_OP}[i]                  ;
        for (int j = 0; j < N_RANDOM; j++) begin
          ra = $urandom()                                                                           ;
          rb = $urandom()                                                                           ;
          check(ra, rb, op, $sformatf("Random[op=%0b][%0d]", op, j))                                ;
        end
      end
    end

    $display("\n===== TB ALU — DONE  =====\n")                                                      ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM * 8 + 200))                                                            ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("alu_tb.vcd")                                                                         ;
    $dumpvars(0, alu_tb)                                                                            ;
  end

endmodule
