//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : adder_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the parameterizable adder module.
//                - Covers: zero operands, max values, overflow, random stimulus.
//                - Uses SVA assertions to verify combinational behavior.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module adder_tb                                                                                    ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_ADDER    = 32                  ; // bit width — must match DUT
  localparam int unsigned                                        N_RANDOM    = 1000                ; // number of random test vectors
  localparam int unsigned                                        clock_PERIOD  = 10                ; // ns — reference clock for assertions

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_ADDER                            - 1 : 0]  o_result                           ;
  logic          [NB_ADDER                            - 1 : 0]  i_data_a                           ;
  logic          [NB_ADDER                            - 1 : 0]  i_data_b                           ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  // Combinational DUT — clock is only used to give assertions a sampling edge.
  logic                                                          clock                             ;
  initial  clock = 1'b0                                                                            ;
  always #(clock_PERIOD / 2)                                       clock = ~clock                  ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  adder
  #(
    .NB_ADDER                                                    ( NB_ADDER  )
  ) u_adder (
    .o_result                                                    ( o_result  ),
    .i_data_a                                                    ( i_data_a  ),
    .i_data_b                                                    ( i_data_b  )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  // Golden model: truncated unsigned addition
  function automatic logic [NB_ADDER - 1 : 0] f_expected (
    input  logic   [NB_ADDER                          - 1 : 0]  a                                   ,
    input  logic   [NB_ADDER                          - 1 : 0]  b
  )                                                                                                 ;
    f_expected = a + b                                                                              ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  // 1. Output must always equal the sum of both inputs
  property p_correct_sum                                                                            ;
    @(posedge clock) o_result == (i_data_a + i_data_b)                                              ;
  endproperty

  a_correct_sum : assert property (p_correct_sum)
    else $error("[ASSERT FAIL] a_correct_sum | a=%0h  b=%0h | got=%0h  expected=%0h"                ,
                 i_data_a, i_data_b, o_result, i_data_a + i_data_b)                                 ;

  // 2. Zero inputs must produce zero output
  property p_zero_inputs                                                                            ;
    @(posedge clock) (i_data_a == '0 && i_data_b == '0) |-> (o_result == '0)                        ;
  endproperty

  a_zero_inputs : assert property (p_zero_inputs)
    else $error("[ASSERT FAIL] a_zero_inputs | expected o_result == 0")                             ;

  // 3. Cover: non-equal operands must be exercised
  cover property (@(posedge clock) i_data_a != i_data_b)                                            ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_ADDER                          - 1 : 0]  a                                   ,
    input  logic   [NB_ADDER                          - 1 : 0]  b                                   ,
    input  string                                               test_name
  )                                                                                                 ;
    logic          [NB_ADDER                          - 1 : 0]  expected                            ;
    i_data_a  = a                                                                                   ;
    i_data_b  = b                                                                                   ;
    #1                                                                                              ; // allow combinational propagation
    expected  = f_expected(a, b)                                                                    ;
    if (o_result !== expected)
      $error  ("[FAIL] %s | a=%0h  b=%0h | got=%0h  expected=%0h"                                   ,
                test_name, a, b, o_result, expected)                                                ;
    else
      $display("[PASS] %s | a=%0h  b=%0h | result=%0h"                                              ,
                test_name, a, b, o_result)                                                          ;
    @(posedge clock)                                                                                ; // realign to clock edge
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_data_a = '0                                                                                   ;
    i_data_b = '0                                                                                   ;
    @(posedge clock)                                                                                ;

    $display("\n===== TB ADDER — START =====\n")                                                    ;

    //-- Corner cases -------------------------------------------------------------------------//
    check( '0                        , '0                         , "Zero + Zero"      )            ;
    check( '1                        , '0                         , "One  + Zero"      )            ;
    check( '0                        , '1                         , "Zero + One"       )            ;
    check( {NB_ADDER{1'b1}}          , '0                         , "MAX  + Zero"      )            ;
    check( '0                        , {NB_ADDER{1'b1}}           , "Zero + MAX"       )            ;
    check( {NB_ADDER{1'b1}}          , {NB_ADDER{1'b1}}           , "MAX  + MAX (ovf)" )            ;
    check( {NB_ADDER{1'b1}}          , 1                          , "MAX  + 1   (ovf)" )            ;
    check( 1                         , {NB_ADDER{1'b1}}           , "1    + MAX (ovf)" )            ;
    check( 1 << (NB_ADDER - 1)       , 1  << (NB_ADDER - 1)       , "MSB  + MSB (ovf)" )            ;
    check( 1 << (NB_ADDER - 1)       , (1 << (NB_ADDER - 1)) - 1 ,  "MSB  + (MSB-1)"   )            ;

    //-- Random stimulus ----------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic        [NB_ADDER                          - 1 : 0]  ra                                  ;
      logic        [NB_ADDER                          - 1 : 0]  rb                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        ra = $urandom()                                                                             ;
        rb = $urandom()                                                                             ;
        check(ra, rb, $sformatf("Random[%0d]", i))                                                  ;
      end
    end

    $display("\n===== TB ADDER — DONE  =====\n")                                                    ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(clock_PERIOD * (N_RANDOM + 100))                                                              ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("adder_tb.vcd")                                                                       ;
    $dumpvars(0, adder_tb)                                                                          ;
  end

endmodule