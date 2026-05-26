//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : jump_hazard_detection_unit_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the Jump Hazard Detection Unit.
//                - Covers: JALR hazard on rs1, B-Type hazard on rs1/rs2,
//                  no-hazard cases, double-stall prevention, random stimulus.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module jump_hazard_detection_unit_tb                                                               ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_OPCODE   = 7                   ;
  localparam int unsigned                                        NB_ADDR     = 5                   ;
  localparam int unsigned                                        N_RANDOM    = 500                 ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

  localparam logic [NB_OPCODE - 1 : 0]                           I_TYPE_3    = 7'b1100111          ;
  localparam logic [NB_OPCODE - 1 : 0]                           B_TYPE      = 7'b1100011          ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic                                                         o_write_enable                     ;
  logic          [NB_OPCODE                           - 1 : 0]  i_opcode                           ;
  logic                                                         i_ex_reg_write                     ;
  logic          [NB_ADDR                             - 1 : 0]  i_ex_rd                            ;
  logic          [NB_ADDR                             - 1 : 0]  i_id_rs1                           ;
  logic          [NB_ADDR                             - 1 : 0]  i_id_rs2                           ;
  logic                                                         clock                              ;

//---------------------------------------- CLOCK GENERATION ----------------------------------------//
  initial  clock = 1'b0                                                                            ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                     ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  jump_hazard_detection_unit
  #(
    .NB_OPCODE      ( NB_OPCODE      )                                                             ,
    .NB_ADDR        ( NB_ADDR        )                                                             
  )                                                              
  u_jump_hazard_detection_unit                                                             
  (                                                            
    .o_write_enable ( o_write_enable )                                                             ,
    .i_opcode       ( i_opcode       )                                                             ,
    .i_ex_reg_write ( i_ex_reg_write )                                                             ,
    .i_ex_rd        ( i_ex_rd        )                                                             ,
    .i_id_rs1       ( i_id_rs1       )                                                             ,
    .i_id_rs2       ( i_id_rs2       )                                                             ,
    .clock          ( clock          )
  )                                                                                                ;

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  // No stall when reg_write=0
  property p_no_stall_without_regwrite                                                             ;
    @(posedge clock) (~i_ex_reg_write) |-> (o_write_enable == 1'b1)                                ;
  endproperty
  a_no_stall_without_regwrite : assert property (p_no_stall_without_regwrite)
    else $error("[ASSERT FAIL] a_no_stall_without_regwrite")                                       ;

  // No stall for non-jump/branch opcodes
  property p_no_stall_other_opcodes                                                                ;
    @(posedge clock)
    (i_opcode != I_TYPE_3 && i_opcode != B_TYPE) |-> (o_write_enable == 1'b1)                      ;
  endproperty
  a_no_stall_other : assert property (p_no_stall_other_opcodes)
    else $error("[ASSERT FAIL] a_no_stall_other_opcodes | opcode=%0b we=%0b", i_opcode, o_write_enable);

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_OPCODE - 1 : 0]                           opcode                            ,
    input  logic                                                 ex_rw                             ,
    input  logic   [NB_ADDR   - 1 : 0]                           ex_rd, rs1, rs2                   ,
    input  logic                                                 expected_we                       ,
    input  string                                                test_name
  )                                                                                                ;
    i_opcode       = opcode                                                                        ;
    i_ex_reg_write = ex_rw                                                                         ;
    i_ex_rd        = ex_rd                                                                         ;
    i_id_rs1       = rs1                                                                           ;
    i_id_rs2       = rs2                                                                           ;
    #1                                                                                             ;
    if (o_write_enable !== expected_we)
      $error  ("[FAIL] %s | opcode=%0b exrw=%0b rd=%0d rs1=%0d rs2=%0d | we=%0b exp=%0b"           ,
                test_name, opcode, ex_rw, ex_rd, rs1, rs2, o_write_enable, expected_we)            ;
    else
      $display("[PASS] %s | we=%0b", test_name, o_write_enable)                                    ;
    @(posedge clock)                                                                               ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    {i_opcode, i_ex_reg_write, i_ex_rd, i_id_rs1, i_id_rs2} = '0                                   ;
    @(posedge clock)                                                                               ;

    $display("\n===== JUMP HAZARD DETECTION UNIT TB — START =====\n")                              ;

    // Note: first check after reset — not_stall=0, so no stall issued even with hazard.
    // We need one clean cycle first so not_stall gets set.
    check( 7'b0, 1'b0, 5'd0, 5'd0, 5'd0, 1'b1, "Init cycle (no hazard)")                           ;

    //-- JALR hazards (rs1) ----------------------------------------------------------------//
    check( I_TYPE_3, 1'b1, 5'd5, 5'd5, 5'd0, 1'b0, "JALR hazard rd==rs1"          )                ;
    check( I_TYPE_3, 1'b1, 5'd5, 5'd5, 5'd0, 1'b1, "JALR double-stall prevented"  )                ;
    check( I_TYPE_3, 1'b1, 5'd5, 5'd5, 5'd0, 1'b0, "JALR hazard again after gap"  )                ;
    check( I_TYPE_3, 1'b1, 5'd5, 5'd6, 5'd0, 1'b1, "JALR no hazard rd!=rs1"       )                ;
    check( I_TYPE_3, 1'b0, 5'd5, 5'd5, 5'd0, 1'b1, "JALR no hazard rw=0"          )                ;

    //-- B-Type hazards (rs1 or rs2) -------------------------------------------------------//
    check( B_TYPE,   1'b1, 5'd3, 5'd3, 5'd7, 1'b0, "BEQ hazard rd==rs1"           )                ;
    check( B_TYPE,   1'b1, 5'd3, 5'd3, 5'd7, 1'b1, "BEQ double-stall prevented"   )                ;
    check( B_TYPE,   1'b1, 5'd4, 5'd1, 5'd4, 1'b0, "BEQ hazard rd==rs2"           )                ;
    check( B_TYPE,   1'b1, 5'd4, 5'd1, 5'd4, 1'b1, "BEQ double-stall prevented"   )                ;
    check( B_TYPE,   1'b1, 5'd2, 5'd5, 5'd6, 1'b1, "BEQ no hazard rd no match"    )                ;

    //-- Other opcodes (no stall) ----------------------------------------------------------//
    check( 7'b0110011, 1'b1, 5'd5, 5'd5, 5'd5, 1'b1, "R-Type no stall"            )                ;
    check( 7'b0000011, 1'b1, 5'd5, 5'd5, 5'd5, 1'b1, "Load no stall"              )                ;

    //-- Random stimulus -------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                           ;
    begin
      logic [NB_OPCODE - 1 : 0] rop                                                                ;
      logic [NB_ADDR   - 1 : 0] rrd, rrs1, rrs2                                                    ;
      logic                     rrw                                                                ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rop  = $urandom(); rrw  = $urandom_range(0,1)                                              ;
        rrd  = $urandom_range(0,31); rrs1 = $urandom_range(0,31); rrs2 = $urandom_range(0,31)      ;
        i_opcode = rop; i_ex_reg_write = rrw                                                       ;
        i_ex_rd = rrd; i_id_rs1 = rrs1; i_id_rs2 = rrs2; #1                                        ;
        if ($isunknown(o_write_enable))
          $error("[FAIL] Random[%0d] X/Z in we", i)                                                ;
        @(posedge clock)                                                                           ;
      end
      $display("[PASS] Random stimulus — no X/Z propagation")                                      ;
    end

    $display("\n===== JUMP HAZARD DETECTION UNIT TB — DONE  =====\n")                              ;
    $finish                                                                                        ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                               ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                             ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("jump_hazard_detection_unit_tb.vcd")                                                 ;
    $dumpvars(0, jump_hazard_detection_unit_tb)                                                    ;
  end

endmodule
