//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : mux2to1_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the 2-to-1 Multiplexer module.
//                - Covers: both select values, corner data, random stimulus.
//                - Uses SVA assertions to verify combinational behavior.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module mux2to1_tb                                                                                   ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_MUX      = 32                  ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_MUX                              - 1 : 0]  o_mux                              ;
  logic          [NB_MUX                              - 1 : 0]  i_data_a                           ;
  logic          [NB_MUX                              - 1 : 0]  i_data_b                           ;
  logic                                                         i_data_sel                         ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clk                               ;
  initial  clk = 1'b0                                                                               ;
  always #(CLK_PERIOD / 2)                                      clk = ~clk                         ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  mux_2to1
  #(
    .NB_MUX                                                      ( NB_MUX )
  ) u_mux2to1 (
    .o_mux                                                       ( o_mux      ),
    .i_data_a                                                    ( i_data_a   ),
    .i_data_b                                                    ( i_data_b   ),
    .i_data_sel                                                  ( i_data_sel )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_MUX - 1 : 0] f_expected (
    input  logic   [NB_MUX - 1 : 0]                              a                                  ,
    input  logic   [NB_MUX - 1 : 0]                              b                                  ,
    input  logic                                                 sel
  )                                                                                                 ;
    f_expected = sel ? b : a                                                                        ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_correct_output                                                                         ;
    @(posedge clk) o_mux == f_expected(i_data_a, i_data_b, i_data_sel)                             ;
  endproperty
  a_correct_output : assert property (p_correct_output)
    else $error("[ASSERT FAIL] a_correct_output | sel=%0b a=%0h b=%0h | got=%0h exp=%0h"            ,
                 i_data_sel, i_data_a, i_data_b, o_mux,
                 f_expected(i_data_a, i_data_b, i_data_sel))                                        ;

  property p_sel0_passes_a                                                                          ;
    @(posedge clk) (~i_data_sel) |-> (o_mux == i_data_a)                                            ;
  endproperty
  a_sel0_passes_a : assert property (p_sel0_passes_a)
    else $error("[ASSERT FAIL] a_sel0_passes_a | got=%0h a=%0h", o_mux, i_data_a)                  ;

  property p_sel1_passes_b                                                                          ;
    @(posedge clk) (i_data_sel) |-> (o_mux == i_data_b)                                             ;
  endproperty
  a_sel1_passes_b : assert property (p_sel1_passes_b)
    else $error("[ASSERT FAIL] a_sel1_passes_b | got=%0h b=%0h", o_mux, i_data_b)                  ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_MUX - 1 : 0]                              a                                  ,
    input  logic   [NB_MUX - 1 : 0]                              b                                  ,
    input  logic                                                 sel                                ,
    input  string                                                test_name
  )                                                                                                 ;
    logic          [NB_MUX - 1 : 0]                              expected                           ;
    i_data_a   = a                                                                                  ;
    i_data_b   = b                                                                                  ;
    i_data_sel = sel                                                                                ;
    #1                                                                                              ;
    expected   = f_expected(a, b, sel)                                                              ;
    if (o_mux !== expected)
      $error  ("[FAIL] %s | sel=%0b a=%0h b=%0h | got=%0h exp=%0h"                                 ,
                test_name, sel, a, b, o_mux, expected)                                             ;
    else
      $display("[PASS] %s | sel=%0b out=%0h", test_name, sel, o_mux)                               ;
    @(posedge clk)                                                                                  ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_data_a = '0; i_data_b = '0; i_data_sel = '0                                                  ;
    @(posedge clk)                                                                                  ;

    $display("\n===== MUX2TO1 TB — START =====\n")                                                  ;

    //-- Corner cases -------------------------------------------------------------------------//
    check( 32'hAAAA_AAAA, 32'h5555_5555, 1'b0, "sel=0 → A"            )                           ;
    check( 32'hAAAA_AAAA, 32'h5555_5555, 1'b1, "sel=1 → B"            )                           ;
    check( '0,            {NB_MUX{1'b1}}, 1'b0, "sel=0 zero"          )                           ;
    check( '0,            {NB_MUX{1'b1}}, 1'b1, "sel=1 max"           )                           ;
    check( {NB_MUX{1'b1}},{NB_MUX{1'b1}}, 1'b0, "same inputs sel=0"  )                            ;
    check( {NB_MUX{1'b1}},{NB_MUX{1'b1}}, 1'b1, "same inputs sel=1"  )                            ;
    check( '0,            '0,             1'b0, "both zero sel=0"      )                           ;
    check( '0,            '0,             1'b1, "both zero sel=1"      )                           ;

    //-- Random stimulus ----------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_MUX - 1 : 0] ra, rb                                                                ;
      logic                   rs                                                                    ;
      for (int i = 0; i < N_RANDOM; i++) begin
        ra = $urandom(); rb = $urandom(); rs = $urandom_range(0, 1)                                 ;
        check(ra, rb, rs, $sformatf("Random[%0d]", i))                                             ;
      end
    end

    $display("\n===== MUX2TO1 TB — DONE  =====\n")                                                  ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 100))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("mux2to1_tb.vcd")                                                                     ;
    $dumpvars(0, mux2to1_tb)                                                                        ;
  end

endmodule
