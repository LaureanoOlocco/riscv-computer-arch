//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : jump_ctrl_unit_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the Jump Control Unit.
//                - Covers: JAL, JALR, stall suppression, other opcodes, random stimulus.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module jump_ctrl_unit_tb                                                                            ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_PC       = 32                  ;
  localparam int unsigned                                        NB_OPCODE   = 7                   ;
  localparam int unsigned                                        NB_PC_SRC   = 2                   ;
  localparam int unsigned                                        N_RANDOM    = 500                 ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

  localparam logic [NB_OPCODE - 1 : 0]                           J_TYPE      = 7'b1101111          ;
  localparam logic [NB_OPCODE - 1 : 0]                           I_TYPE_3    = 7'b1100111          ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_PC_SRC                           - 1 : 0]  o_pc_src                           ;
  logic                                                         o_reg_write                        ;
  logic                                                         o_flush                            ;
  logic          [NB_OPCODE                           - 1 : 0]  i_opcode                           ;
  logic                                                         i_stall                            ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clk                               ;
  initial  clk = 1'b0                                                                               ;
  always #(CLK_PERIOD / 2)                                      clk = ~clk                         ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  jump_ctrl_unit
  #(
    .NB_PC     ( NB_PC     ),
    .NB_OPCODE ( NB_OPCODE ),
    .NB_PC_SRC ( NB_PC_SRC )
  ) u_jump_ctrl (
    .o_pc_src    ( o_pc_src   ),
    .o_reg_write ( o_reg_write),
    .o_flush     ( o_flush    ),
    .i_opcode    ( i_opcode   ),
    .i_stall     ( i_stall    )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  typedef struct {
    logic [NB_PC_SRC - 1 : 0] pc_src  ;
    logic                     reg_wr  ;
    logic                     flush   ;
  } ctrl_t                                                                                          ;

  function automatic ctrl_t f_expected (
    input  logic   [NB_OPCODE - 1 : 0]                           opcode                             ,
    input  logic                                                 stall
  )                                                                                                 ;
    f_expected.pc_src = 2'b00; f_expected.reg_wr = 1'b0; f_expected.flush = 1'b0                   ;
    if (~stall) begin
      case (opcode)
        J_TYPE   : begin f_expected.pc_src=2'b01; f_expected.reg_wr=1'b1; f_expected.flush=1'b1; end
        I_TYPE_3 : begin f_expected.pc_src=2'b10; f_expected.reg_wr=1'b1; f_expected.flush=1'b1; end
        default  : ;
      endcase
    end
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  property p_jal_outputs                                                                            ;
    @(posedge clk) (i_opcode == J_TYPE && ~i_stall) |->
      (o_pc_src == 2'b01 && o_reg_write == 1'b1 && o_flush == 1'b1)                                ;
  endproperty
  a_jal_outputs : assert property (p_jal_outputs)
    else $error("[ASSERT FAIL] a_jal_outputs | pc_src=%0b rw=%0b fl=%0b", o_pc_src, o_reg_write, o_flush);

  property p_jalr_outputs                                                                           ;
    @(posedge clk) (i_opcode == I_TYPE_3 && ~i_stall) |->
      (o_pc_src == 2'b10 && o_reg_write == 1'b1 && o_flush == 1'b1)                                ;
  endproperty
  a_jalr_outputs : assert property (p_jalr_outputs)
    else $error("[ASSERT FAIL] a_jalr_outputs | pc_src=%0b rw=%0b fl=%0b", o_pc_src, o_reg_write, o_flush);

  property p_stall_suppresses                                                                       ;
    @(posedge clk) (i_stall) |-> (o_pc_src == 2'b00 && o_reg_write == 1'b0 && o_flush == 1'b0)    ;
  endproperty
  a_stall_suppresses : assert property (p_stall_suppresses)
    else $error("[ASSERT FAIL] a_stall_suppresses")                                                 ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_OPCODE - 1 : 0]                           opcode                             ,
    input  logic                                                 stall                              ,
    input  string                                                test_name
  )                                                                                                 ;
    ctrl_t exp                                                                                      ;
    i_opcode = opcode; i_stall = stall; #1                                                          ;
    exp = f_expected(opcode, stall)                                                                 ;
    if (o_pc_src !== exp.pc_src || o_reg_write !== exp.reg_wr || o_flush !== exp.flush)
      $error  ("[FAIL] %s | opcode=%0b stall=%0b | pc_src=%0b(exp %0b) rw=%0b fl=%0b"              ,
                test_name, opcode, stall, o_pc_src, exp.pc_src, o_reg_write, o_flush)              ;
    else
      $display("[PASS] %s | pc_src=%0b rw=%0b fl=%0b", test_name, o_pc_src, o_reg_write, o_flush)  ;
    @(posedge clk)                                                                                  ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_opcode = '0; i_stall = '0                                                                     ;
    @(posedge clk)                                                                                  ;

    $display("\n===== JUMP CTRL UNIT TB — START =====\n")                                           ;

    //-- JAL -------------------------------------------------------------------------------//
    check( J_TYPE,    1'b0, "JAL  no stall → pc_src=01 rw=1 fl=1" )                               ;
    check( J_TYPE,    1'b1, "JAL  stall    → all zero"             )                               ;

    //-- JALR ------------------------------------------------------------------------------//
    check( I_TYPE_3,  1'b0, "JALR no stall → pc_src=10 rw=1 fl=1" )                               ;
    check( I_TYPE_3,  1'b1, "JALR stall    → all zero"             )                               ;

    //-- Other opcodes (no jump) -----------------------------------------------------------//
    check( 7'b0110011, 1'b0, "R-Type  → all zero"   )                                              ;
    check( 7'b1100011, 1'b0, "B-Type  → all zero"   )                                              ;
    check( 7'b0000000, 1'b0, "Unknown → all zero"   )                                              ;

    //-- Random stimulus -------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_OPCODE - 1 : 0] rop                                                                ;
      logic                     rs                                                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rop = $urandom(); rs = $urandom_range(0, 1)                                                 ;
        check(rop, rs, $sformatf("Random[%0d]", i))                                                ;
      end
    end

    $display("\n===== JUMP CTRL UNIT TB — DONE  =====\n")                                           ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("jump_ctrl_unit_tb.vcd")                                                              ;
    $dumpvars(0, jump_ctrl_unit_tb)                                                                 ;
  end

endmodule
