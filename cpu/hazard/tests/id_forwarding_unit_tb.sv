//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : id_forwarding_unit_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the ID Stage Forwarding Unit.
//                - Covers: MEM forward (non-load), WB forward, load block, x0 guard, random.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module id_forwarding_unit_tb                                                                       ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_ADDR     = 5                   ;
  localparam int unsigned                                        NB_FORWARD  = 2                   ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_FORWARD                          - 1 : 0]  o_forward_a                        ;
  logic          [NB_FORWARD                          - 1 : 0]  o_forward_b                        ;
  logic          [NB_ADDR                             - 1 : 0]  i_id_rs1                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_id_rs2                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_mem_rd                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_wb_rd                            ;
  logic                                                         i_mem_reg_write                    ;
  logic                                                         i_wb_reg_write                     ;
  logic                                                         i_mem_mem_read                     ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                              ;
  initial  clock = 1'b0                                                                            ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                     ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  id_forwarding_unit
  #(
    .NB_ADDR          ( NB_ADDR         )                                                           ,
    .NB_FORWARD       ( NB_FORWARD      )
  ) 
  u_id_forwarding_unit 
  (
    .o_forward_a      ( o_forward_a     )                                                           ,
    .o_forward_b      ( o_forward_b     )                                                           ,
    .i_id_rs1         ( i_id_rs1        )                                                           ,
    .i_id_rs2         ( i_id_rs2        )                                                           ,
    .i_mem_rd         ( i_mem_rd        )                                                           ,
    .i_wb_rd          ( i_wb_rd         )                                                           ,
    .i_mem_reg_write  ( i_mem_reg_write )                                                           ,
    .i_wb_reg_write   ( i_wb_reg_write  )                                                           ,
    .i_mem_mem_read   ( i_mem_mem_read  )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic [NB_FORWARD - 1 : 0] f_forward (
    input  logic   [NB_ADDR - 1 : 0]                             rs                                 ,
    input  logic   [NB_ADDR - 1 : 0]                             mem_rd                             ,
    input  logic   [NB_ADDR - 1 : 0]                             wb_rd                              ,
    input  logic                                                 mem_rw                             ,
    input  logic                                                 wb_rw                              ,
    input  logic                                                 mem_mr
  )                                                                                                 ;
    if (mem_rw && (mem_rd != '0) && (mem_rd == rs) && ~mem_mr)
      f_forward = 2'b01                                                                             ;
    else if (wb_rw && (wb_rd != '0) && (wb_rd == rs))
      f_forward = 2'b10                                                                             ;
    else
      f_forward = 2'b00                                                                             ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_forward_a_correct                                                                      ;
    @(posedge clock)
    o_forward_a == f_forward(i_id_rs1, i_mem_rd, i_wb_rd,
                              i_mem_reg_write, i_wb_reg_write, i_mem_mem_read)                      ;
  endproperty
  a_forward_a_correct : assert property (p_forward_a_correct)
    else $error("[ASSERT FAIL] a_forward_a | got=%0b exp=%0b", o_forward_a,
                 f_forward(i_id_rs1, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write, i_mem_mem_read));

  property p_forward_b_correct                                                                      ;
    @(posedge clock)
    o_forward_b == f_forward(i_id_rs2, i_mem_rd, i_wb_rd,
                              i_mem_reg_write, i_wb_reg_write, i_mem_mem_read)                      ;
  endproperty
  a_forward_b_correct : assert property (p_forward_b_correct)
    else $error("[ASSERT FAIL] a_forward_b | got=%0b exp=%0b", o_forward_b,
                 f_forward(i_id_rs2, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write, i_mem_mem_read));

  // MEM load must NOT forward (blocked by mem_mem_read)
  property p_load_blocked                                                                           ;
    @(posedge clock)
    (i_mem_reg_write && i_mem_mem_read && i_mem_rd == i_id_rs1 && i_mem_rd != '0)
    |-> (o_forward_a != 2'b01)                                                                      ;
  endproperty
  a_load_blocked : assert property (p_load_blocked)
    else $error("[ASSERT FAIL] a_load_blocked — load forwarded to ID when it should not be")        ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_ADDR - 1 : 0]                             rs1, rs2, mem_rd, wb_rd            ,
    input  logic                                                 mem_rw, wb_rw, mem_mr              ,
    input  string                                                test_name
  )                                                                                                 ;
    logic [NB_FORWARD - 1 : 0]                                   exp_a, exp_b                       ;
    i_id_rs1       = rs1;   i_id_rs2       = rs2                                                    ;
    i_mem_rd       = mem_rd; i_wb_rd        = wb_rd                                                 ;
    i_mem_reg_write= mem_rw; i_wb_reg_write = wb_rw; i_mem_mem_read = mem_mr                        ;
    #1                                                                                              ;
    exp_a = f_forward(rs1, mem_rd, wb_rd, mem_rw, wb_rw, mem_mr)                                    ;
    exp_b = f_forward(rs2, mem_rd, wb_rd, mem_rw, wb_rw, mem_mr)                                    ;
    if (o_forward_a !== exp_a || o_forward_b !== exp_b)
      $error  ("[FAIL] %s | fwd_a=%0b(exp %0b) fwd_b=%0b(exp %0b)",
                test_name, o_forward_a, exp_a, o_forward_b, exp_b)                                  ;
    else
      $display("[PASS] %s | fwd_a=%0b fwd_b=%0b", test_name, o_forward_a, o_forward_b)              ;
    @(posedge clock)                                                                                ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    {i_id_rs1, i_id_rs2, i_mem_rd, i_wb_rd, i_mem_reg_write, i_wb_reg_write, i_mem_mem_read} = '0   ;
    @(posedge clock)                                                                                ;

    $display("\n===== ID FORWARDING UNIT TB — START =====\n")                                       ;

    //-- No forwarding -------------------------------------------------------------------//
    check( 5'd1, 5'd2, 5'd3, 5'd4, 1'b0, 1'b0, 1'b0, "no fwd: rw=0"               )                 ;
    check( 5'd1, 5'd2, 5'd0, 5'd0, 1'b1, 1'b1, 1'b0, "no fwd: rd=x0"              )                 ;
    check( 5'd1, 5'd2, 5'd5, 5'd6, 1'b1, 1'b1, 1'b0, "no fwd: no match"           )                 ;

    //-- MEM forward (non-load) ----------------------------------------------------------//
    check( 5'd3, 5'd4, 5'd3, 5'd9, 1'b1, 1'b0, 1'b0, "MEM fwd A (not load)"       )                 ;
    check( 5'd9, 5'd5, 5'd5, 5'd9, 1'b1, 1'b0, 1'b0, "MEM fwd B (not load)"       )                 ;

    //-- MEM forward BLOCKED (load) -------------------------------------------------------//
    check( 5'd3, 5'd4, 5'd3, 5'd9, 1'b1, 1'b0, 1'b1, "MEM fwd blocked (load)"     )                 ;

    //-- WB forward ----------------------------------------------------------------------//
    check( 5'd7, 5'd8, 5'd3, 5'd7, 1'b0, 1'b1, 1'b0, "WB fwd A"                   )                 ;
    check( 5'd1, 5'd9, 5'd3, 5'd9, 1'b0, 1'b1, 1'b0, "WB fwd B"                   )                 ;

    //-- WB takes over when MEM is a load ------------------------------------------------//
    check( 5'd5, 5'd6, 5'd5, 5'd5, 1'b1, 1'b1, 1'b1, "WB fwd when MEM blocked"    )                 ;

    //-- Random stimulus -----------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_ADDR-1:0] rs1, rs2, mrd, wrd                                                        ;
      logic               mrw, wrw, mmr                                                             ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rs1 = $urandom_range(0,31); rs2 = $urandom_range(0,31)                                      ;
        mrd = $urandom_range(0,31); wrd = $urandom_range(0,31)                                      ;
        mrw = $urandom_range(0,1);  wrw = $urandom_range(0,1); mmr = $urandom_range(0,1)            ;
        check(rs1, rs2, mrd, wrd, mrw, wrw, mmr, $sformatf("Random[%0d]", i))                       ;
      end
    end

    $display("\n===== ID FORWARDING UNIT TB — DONE  =====\n")                                       ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("id_forwarding_unit_tb.vcd")                                                          ;
    $dumpvars(0, id_forwarding_unit_tb)                                                             ;
  end

endmodule
