//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : tb_ex_forwarding_unit.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the EX Forwarding Unit module.
//                - Covers: MEM forward, WB forward, priority, no-forward, x0 guard, random.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module ex_forwarding_unit_tb                                                                       ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_ADDR     = 5                   ;
  localparam int unsigned                                        NB_FORWARD  = 2                   ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_FORWARD                          - 1 : 0]  o_forward_a                        ;
  logic          [NB_FORWARD                          - 1 : 0]  o_forward_b                        ;
  logic          [NB_ADDR                             - 1 : 0]  i_ex_rs1                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_ex_rs2                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_mem_rd                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_wb_rd                            ;
  logic                                                         i_mem_reg_write                    ;
  logic                                                         i_wb_reg_write                     ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                               ;
  initial  clock = 1'b0                                                                             ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                      ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  ex_forwarding_unit
  #(
    .NB_ADDR                                                     ( NB_ADDR        )                 ,
    .NB_FORWARD                                                  ( NB_FORWARD     )                 
  ) 
  u_ex_forwarding_unit 
  (                 
    .o_forward_a                                                 ( o_forward_a    )                 ,
    .o_forward_b                                                 ( o_forward_b    )                 ,
    .i_ex_rs1                                                    ( i_ex_rs1       )                 ,
    .i_ex_rs2                                                    ( i_ex_rs2       )                 ,
    .i_mem_rd                                                    ( i_mem_rd       )                 ,
    .i_wb_rd                                                     ( i_wb_rd        )                 ,
    .i_mem_reg_write                                             ( i_mem_reg_write)                 ,
    .i_wb_reg_write                                              ( i_wb_reg_write )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_FORWARD - 1 : 0] f_forward (
    input  logic   [NB_ADDR - 1 : 0]                             rs                                 ,
    input  logic   [NB_ADDR - 1 : 0]                             mem_rd                             ,
    input  logic   [NB_ADDR - 1 : 0]                             wb_rd                              ,
    input  logic                                                 mem_rw                             ,
    input  logic                                                 wb_rw
  )                                                                                                 ;
    if (mem_rw && (mem_rd != '0) && (mem_rd == rs))
      f_forward = 2'b01                                                                             ;
    else if (wb_rw && (wb_rd != '0) && !(mem_rw && (mem_rd != '0) && (mem_rd == rs)) && (wb_rd == rs))
      f_forward = 2'b10                                                                             ;
    else
      f_forward = 2'b00                                                                             ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_forward_a_correct                                                                      ;
    @(posedge clock)
    o_forward_a == f_forward(i_ex_rs1, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write)          ;
  endproperty
  a_forward_a_correct : assert property (p_forward_a_correct)
    else $error("[ASSERT FAIL] a_forward_a | got=%0b exp=%0b"                                       ,
                 o_forward_a,
                 f_forward(i_ex_rs1, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write))           ;

  property p_forward_b_correct                                                                      ;
    @(posedge clock)
    o_forward_b == f_forward(i_ex_rs2, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write)          ;
  endproperty
  a_forward_b_correct : assert property (p_forward_b_correct)
    else $error("[ASSERT FAIL] a_forward_b | got=%0b exp=%0b"                                       ,
                 o_forward_b,
                 f_forward(i_ex_rs2, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write))           ;

  // x0 must never be forwarded
  property p_no_forward_x0                                                                          ;
    @(posedge clock)
    (i_mem_rd == '0 && i_wb_rd == '0) |-> (o_forward_a == 2'b00 && o_forward_b == 2'b00)            ;
  endproperty
  a_no_forward_x0 : assert property (p_no_forward_x0)
    else $error("[ASSERT FAIL] a_no_forward_x0 | fwd_a=%0b fwd_b=%0b", o_forward_a, o_forward_b)    ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_ADDR - 1 : 0]                             rs1, rs2, mem_rd, wb_rd            ,
    input  logic                                                 mem_rw, wb_rw                      ,
    input  string                                                test_name
  )                                                                                                 ;
    logic [NB_FORWARD - 1 : 0]                                   exp_a, exp_b                       ;
    i_ex_rs1       = rs1   ; i_ex_rs2       = rs2                                                   ;
    i_mem_rd       = mem_rd; i_wb_rd        = wb_rd                                                 ;
    i_mem_reg_write= mem_rw; i_wb_reg_write = wb_rw                                                 ;
    #1                                                                                              ;
    exp_a = f_forward(rs1, mem_rd, wb_rd, mem_rw, wb_rw)                                            ;
    exp_b = f_forward(rs2, mem_rd, wb_rd, mem_rw, wb_rw)                                            ;
    if (o_forward_a !== exp_a || o_forward_b !== exp_b)
      $error  ("[FAIL] %s | fwd_a=%0b(exp %0b) fwd_b=%0b(exp %0b)", test_name,
                o_forward_a, exp_a, o_forward_b, exp_b)                                             ;
    else
      $display("[PASS] %s | fwd_a=%0b fwd_b=%0b", test_name, o_forward_a, o_forward_b)              ;
    @(posedge clock)                                                                                ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    {i_ex_rs1, i_ex_rs2, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write} = '0                   ;
    @(posedge clock)                                                                                ;

    $display("\n===== TB EX FORWARDING UNIT — START =====\n")                                       ;

    //-- No forwarding -------------------------------------------------------------------//
    check( 5'd1, 5'd2, 5'd3, 5'd4, 1'b0, 1'b0, "no fwd: reg_write=0"         )                      ;
    check( 5'd1, 5'd2, 5'd0, 5'd0, 1'b1, 1'b1, "no fwd: rd=x0"               )                      ;
    check( 5'd1, 5'd2, 5'd3, 5'd4, 1'b1, 1'b1, "no fwd: no match"            )                      ;

    //-- MEM forwarding (priority) -------------------------------------------------------//
    check( 5'd5, 5'd6, 5'd5, 5'd5, 1'b1, 1'b1, "MEM fwd A (priority over WB)")                      ;
    check( 5'd3, 5'd5, 5'd5, 5'd3, 1'b1, 1'b1, "MEM fwd B, WB fwd A"         )                      ;

    //-- WB forwarding -------------------------------------------------------------------//
    check( 5'd7, 5'd8, 5'd3, 5'd7, 1'b1, 1'b1, "WB fwd A"                    )                      ;
    check( 5'd1, 5'd9, 5'd3, 5'd9, 1'b1, 1'b1, "WB fwd B"                    )                      ;

    //-- Random stimulus -----------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_ADDR-1:0] rs1, rs2, mrd, wrd                                                        ;
      logic               mrw, wrw                                                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rs1 = $urandom_range(0,31); rs2 = $urandom_range(0,31)                                      ;
        mrd = $urandom_range(0,31); wrd = $urandom_range(0,31)                                      ;
        mrw = $urandom_range(0,1);  wrw = $urandom_range(0,1)                                       ;
        check(rs1, rs2, mrd, wrd, mrw, wrw, $sformatf("Random[%0d]", i))                            ;
      end
    end

    $display("\n===== TB EX FORWARDING UNIT — DONE  =====\n")                                       ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("ex_forwarding_unit_tb.vcd")                                                          ;
    $dumpvars(0, ex_forwarding_unit_tb)                                                             ;
  end

endmodule
