//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : mem_forwarding_unit_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the MEM Stage Forwarding Unit.
//                - Covers: WB forward on rs2, no-forward, x0 guard, random stimulus.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module mem_forwarding_unit_tb                                                                      ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_ADDR     = 5                   ;
  localparam int unsigned                                        NB_FORWARD  = 2                   ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_FORWARD                          - 1 : 0]  o_forward_b                        ;
  logic          [NB_ADDR                             - 1 : 0]  i_mem_rs2                          ;
  logic          [NB_ADDR                             - 1 : 0]  i_wb_rd                            ;
  logic                                                         i_wb_reg_write                     ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                              ;
  initial  clock = 1'b0                                                                            ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                     ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  mem_forwarding_unit
  #(
    .NB_ADDR        ( NB_ADDR        )                                                             ,
    .NB_FORWARD     ( NB_FORWARD     )                                                             
  )                                                              
  u_mem_forwarding_unit                                                              
  (                                                            
    .o_forward_b    ( o_forward_b    )                                                             ,
    .i_mem_rs2      ( i_mem_rs2      )                                                             ,
    .i_wb_rd        ( i_wb_rd        )                                                             ,
    .i_wb_reg_write ( i_wb_reg_write )                                                             
  )                                                                                                ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_FORWARD - 1 : 0] f_expected (
    input  logic   [NB_ADDR - 1 : 0]                             rs2                               ,
    input  logic   [NB_ADDR - 1 : 0]                             wb_rd                             ,
    input  logic                                                 wb_rw
  )                                                                                                ;
    if (wb_rw && (wb_rd != '0) && (wb_rd == rs2))
      f_expected = 2'b01                                                                           ;
    else
      f_expected = 2'b00                                                                           ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_forward_b_correct                                                                     ;
    @(posedge clock) o_forward_b == f_expected(i_mem_rs2, i_wb_rd, i_wb_reg_write)                 ;
  endproperty
  a_forward_b_correct : assert property (p_forward_b_correct)
    else $error("[ASSERT FAIL] a_forward_b | got=%0b exp=%0b",
                 o_forward_b, f_expected(i_mem_rs2, i_wb_rd, i_wb_reg_write))                      ;

  // x0 must never be forwarded
  property p_no_forward_x0                                                                         ;
    @(posedge clock) (i_wb_rd == '0) |-> (o_forward_b == 2'b00)                                    ;
  endproperty
  a_no_forward_x0 : assert property (p_no_forward_x0)
    else $error("[ASSERT FAIL] a_no_forward_x0 | fwd_b=%0b", o_forward_b)                          ;

  // No forward when reg_write disabled
  property p_no_forward_when_disabled                                                              ;
    @(posedge clock) (~i_wb_reg_write) |-> (o_forward_b == 2'b00)                                  ;
  endproperty
  a_no_forward_when_disabled : assert property (p_no_forward_when_disabled)
    else $error("[ASSERT FAIL] a_no_forward_when_disabled")                                        ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_ADDR - 1 : 0]                             rs2, wb_rd                        ,
    input  logic                                                 wb_rw                             ,
    input  string                                                test_name
  )                                                                                                ;
    logic [NB_FORWARD - 1 : 0]                                   expected                          ;
    i_mem_rs2      = rs2                                                                           ;
    i_wb_rd        = wb_rd                                                                         ;
    i_wb_reg_write = wb_rw                                                                         ;
    #1                                                                                             ;
    expected = f_expected(rs2, wb_rd, wb_rw)                                                       ;
    if (o_forward_b !== expected)
      $error  ("[FAIL] %s | rs2=%0d wb_rd=%0d wb_rw=%0b | got=%0b exp=%0b"                         ,
                test_name, rs2, wb_rd, wb_rw, o_forward_b, expected)                               ;
    else
      $display("[PASS] %s | fwd_b=%0b", test_name, o_forward_b)                                    ;
    @(posedge clock)                                                                               ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    {i_mem_rs2, i_wb_rd, i_wb_reg_write} = '0                                                      ;
    @(posedge clock)                                                                               ;

    $display("\n===== MEM FORWARDING UNIT TB — START =====\n")                                     ;

    //-- No forwarding -------------------------------------------------------------------//
    check( 5'd1, 5'd2,  1'b0, "no fwd: wb_rw=0"          )                                         ;
    check( 5'd1, 5'd0,  1'b1, "no fwd: wb_rd=x0"         )                                         ;
    check( 5'd1, 5'd5,  1'b1, "no fwd: rs2!=wb_rd"       )                                         ;
    check( 5'd0, 5'd0,  1'b1, "no fwd: both x0"          )                                         ;

    //-- WB forward ----------------------------------------------------------------------//
    check( 5'd3,  5'd3,  1'b1, "WB fwd: rs2==wb_rd"      )                                         ;
    check( 5'd15, 5'd15, 1'b1, "WB fwd: high reg"        )                                         ;
    check( 5'd31, 5'd31, 1'b1, "WB fwd: max reg"         )                                         ;
    check( 5'd1,  5'd1,  1'b1, "WB fwd: reg 1"           )                                         ;

    //-- Random stimulus -----------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                           ;
    begin
      logic [NB_ADDR - 1 : 0] rs2, wrd                                                             ;
      logic                   wrw                                                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rs2 = $urandom_range(0, 31)                                                                ;
        wrd = $urandom_range(0, 31)                                                                ;
        wrw = $urandom_range(0, 1)                                                                 ;
        check(rs2, wrd, wrw, $sformatf("Random[%0d]", i))                                          ;
      end
    end

    $display("\n===== MEM FORWARDING UNIT TB — DONE  =====\n")                                     ;
    $finish                                                                                        ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                               ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                             ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("mem_forwarding_unit_tb.vcd")                                                        ;
    $dumpvars(0, mem_forwarding_unit_tb)                                                           ;
  end

endmodule
