//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : mux3to1_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the 3-to-1 Multiplexer module.
//                - Covers: all 3 select values, corner data, invalid select, random stimulus.
//                - Uses SVA assertions to verify combinational behavior.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module mux3to1_tb                                                                                   ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_MUX      = 32                  ;
  localparam int unsigned                                        NB_SELECT   = 2                   ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_MUX                              - 1 : 0]  o_mux                              ;
  logic          [NB_MUX                              - 1 : 0]  i_data_a                           ;
  logic          [NB_MUX                              - 1 : 0]  i_data_b                           ;
  logic          [NB_MUX                              - 1 : 0]  i_data_c                           ;
  logic          [NB_SELECT                           - 1 : 0]  i_data_sel                         ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clk                               ;
  initial  clk = 1'b0                                                                               ;
  always #(CLK_PERIOD / 2)                                      clk = ~clk                         ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  mux_3to1
  #(
    .NB_MUX                                                      ( NB_MUX    ),
    .NB_SELECT                                                   ( NB_SELECT )
  ) u_mux3to1 (
    .o_mux                                                       ( o_mux      ),
    .i_data_a                                                    ( i_data_a   ),
    .i_data_b                                                    ( i_data_b   ),
    .i_data_c                                                    ( i_data_c   ),
    .i_data_sel                                                  ( i_data_sel )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_MUX - 1 : 0] f_expected (
    input  logic   [NB_MUX    - 1 : 0]                           a, b, c                            ,
    input  logic   [NB_SELECT - 1 : 0]                           sel
  )                                                                                                 ;
    case (sel)
      2'b00   : f_expected = a                                                                      ;
      2'b01   : f_expected = b                                                                      ;
      2'b10   : f_expected = c                                                                      ;
      default : f_expected = '0                                                                     ;
    endcase
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_correct_output                                                                         ;
    @(posedge clk) o_mux == f_expected(i_data_a, i_data_b, i_data_c, i_data_sel)                   ;
  endproperty
  a_correct_output : assert property (p_correct_output)
    else $error("[ASSERT FAIL] sel=%0b | got=%0h exp=%0h"                                           ,
                 i_data_sel, o_mux, f_expected(i_data_a, i_data_b, i_data_c, i_data_sel))          ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_MUX    - 1 : 0]                           a, b, c                            ,
    input  logic   [NB_SELECT - 1 : 0]                           sel                                ,
    input  string                                                test_name
  )                                                                                                 ;
    logic          [NB_MUX    - 1 : 0]                            expected                          ;
    i_data_a   = a; i_data_b = b; i_data_c = c; i_data_sel = sel                                   ;
    #1                                                                                              ;
    expected   = f_expected(a, b, c, sel)                                                           ;
    if (o_mux !== expected)
      $error  ("[FAIL] %s | sel=%0b | got=%0h exp=%0h", test_name, sel, o_mux, expected)            ;
    else
      $display("[PASS] %s | sel=%0b out=%0h", test_name, sel, o_mux)                               ;
    @(posedge clk)                                                                                  ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    {i_data_a, i_data_b, i_data_c, i_data_sel} = '0                                                ;
    @(posedge clk)                                                                                  ;

    $display("\n===== MUX3TO1 TB — START =====\n")                                                  ;

    //-- Corner cases -------------------------------------------------------------------------//
    check( 32'hA, 32'hB, 32'hC, 2'b00, "sel=0 → A"                )                               ;
    check( 32'hA, 32'hB, 32'hC, 2'b01, "sel=1 → B"                )                               ;
    check( 32'hA, 32'hB, 32'hC, 2'b10, "sel=2 → C"                )                               ;
    check( '0,   '0,    '0,    2'b00,  "all zero sel=0"            )                               ;
    check( {NB_MUX{1'b1}},{NB_MUX{1'b1}},{NB_MUX{1'b1}},2'b10,"all-one sel=2")                    ;
    check( 32'hFFFF_FFFF, 32'h0, 32'h5555_5555, 2'b00, "max→A"    )                               ;
    check( 32'hFFFF_FFFF, 32'h0, 32'h5555_5555, 2'b01, "zero→B"   )                               ;
    check( 32'hFFFF_FFFF, 32'h0, 32'h5555_5555, 2'b10, "pat→C"    )                               ;

    //-- Random stimulus ----------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_MUX    - 1 : 0] ra, rb, rc                                                         ;
      logic [NB_SELECT - 1 : 0] rs                                                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        ra = $urandom(); rb = $urandom(); rc = $urandom()                                           ;
        rs = $urandom_range(0, 2)                                                                   ;
        check(ra, rb, rc, rs, $sformatf("Random[%0d]", i))                                         ;
      end
    end

    $display("\n===== MUX3TO1 TB — DONE  =====\n")                                                  ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 100))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("mux3to1_tb.vcd")                                                                     ;
    $dumpvars(0, mux3to1_tb)                                                                        ;
  end

endmodule
