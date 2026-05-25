//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : tb_hazard_detection_unit.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the Hazard Detection Unit module.
//                - Covers: load-use hazard on rs1, on rs2, on both, no-hazard cases, x0 edge cases.
//                - Uses SVA assertions and a golden model.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module hazard_detection_unit_tb                                                                    ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_ADDR     = 5                   ;
  localparam int unsigned                                        N_RANDOM    = 1000                ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic                                                         o_write_enable                     ;
  logic                                                         o_control_mux                      ;
  logic                                                         i_id_ex_mem_read                   ;
  logic          [NB_ADDR                             - 1 : 0]  i_id_ex_rd                         ;
  logic          [NB_ADDR                             - 1 : 0]  i_if_id_rs1                        ;
  logic          [NB_ADDR                             - 1 : 0]  i_if_id_rs2                        ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clock                              ;
  initial  clock = 1'b0                                                                            ;
  always #(CLK_PERIOD / 2)                                      clock = ~clock                     ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  hazard_detection_unit
  #(
    .NB_ADDR                                                     ( NB_ADDR            )
  ) 
  u_hazard_detection_unit 
  (
    .o_write_enable                                              ( o_write_enable     )             ,
    .o_control_mux                                               ( o_control_mux      )             ,
    .i_id_ex_mem_read                                            ( i_id_ex_mem_read   )             ,
    .i_id_ex_rd                                                  ( i_id_ex_rd         )             ,
    .i_if_id_rs1                                                 ( i_if_id_rs1        )             ,
    .i_if_id_rs2                                                 ( i_if_id_rs2        )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  function automatic logic f_hazard (
    input  logic                                                 mem_read                           ,
    input  logic   [NB_ADDR - 1 : 0]                             rd                                 ,
    input  logic   [NB_ADDR - 1 : 0]                             rs1                                ,
    input  logic   [NB_ADDR - 1 : 0]                             rs2
  )                                                                                                 ;
    f_hazard = mem_read && ((rd == rs1) || (rd == rs2))                                             ;
  endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  // write_enable is LOW when hazard detected
  property p_write_enable_correct                                                                   ;
    @(posedge clock)
    o_write_enable == ~f_hazard(i_id_ex_mem_read, i_id_ex_rd, i_if_id_rs1, i_if_id_rs2)             ;
  endproperty
  a_write_enable_correct : assert property (p_write_enable_correct)
    else $error("[ASSERT FAIL] a_write_enable_correct | mem_read=%0b rd=%0d rs1=%0d rs2=%0d"        ,
                 i_id_ex_mem_read, i_id_ex_rd, i_if_id_rs1, i_if_id_rs2)                            ;

  // control_mux mirrors hazard
  property p_control_mux_correct                                                                    ;
    @(posedge clock)
    o_control_mux == f_hazard(i_id_ex_mem_read, i_id_ex_rd, i_if_id_rs1, i_if_id_rs2)               ;
  endproperty
  a_control_mux_correct : assert property (p_control_mux_correct)
    else $error("[ASSERT FAIL] a_control_mux_correct")                                              ;

  // No hazard when mem_read is low
  property p_no_hazard_without_load                                                                 ;
    @(posedge clock) (~i_id_ex_mem_read) |-> (o_write_enable && ~o_control_mux)                     ;
  endproperty
  a_no_hazard_without_load : assert property (p_no_hazard_without_load)
    else $error("[ASSERT FAIL] a_no_hazard_without_load")                                           ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic                                                 mem_read                           ,
    input  logic   [NB_ADDR - 1 : 0]                             rd                                 ,
    input  logic   [NB_ADDR - 1 : 0]                             rs1                                ,
    input  logic   [NB_ADDR - 1 : 0]                             rs2                                ,
    input  string                                                test_name
  )                                                                                                 ;
    logic                                                        exp_hazard                         ;
    i_id_ex_mem_read = mem_read                                                                     ;
    i_id_ex_rd       = rd                                                                           ;
    i_if_id_rs1      = rs1                                                                          ;
    i_if_id_rs2      = rs2                                                                          ;
    #1                                                                                              ;
    exp_hazard       = f_hazard(mem_read, rd, rs1, rs2)                                             ;
    if (o_write_enable !== ~exp_hazard || o_control_mux !== exp_hazard)
      $error  ("[FAIL] %s | mem_read=%0b rd=%0d rs1=%0d rs2=%0d | we=%0b mux=%0b exp_hz=%0b"        ,
                test_name, mem_read, rd, rs1, rs2, o_write_enable, o_control_mux, exp_hazard)       ;
    else
      $display("[PASS] %s | hazard=%0b we=%0b mux=%0b", test_name, exp_hazard,
                o_write_enable, o_control_mux)                                                      ;
    @(posedge clock)                                                                                ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_id_ex_mem_read = '0; i_id_ex_rd = '0; i_if_id_rs1 = '0; i_if_id_rs2 = '0                      ;
    @(posedge clock)                                                                                ;

    $display("\n===== TB HAZARD DETECTION UNIT — START =====\n")                                    ;

    //-- No hazard cases -------------------------------------------------------------------//
    check( 1'b0, 5'd1,  5'd1,  5'd1,  "no hazard: mem_read=0 match"    )                            ;
    check( 1'b0, 5'd5,  5'd5,  5'd5,  "no hazard: mem_read=0"          )                            ;
    check( 1'b1, 5'd0,  5'd0,  5'd0,  "no hazard: rd=x0 (hardwired 0)" )                            ;
    check( 1'b1, 5'd3,  5'd4,  5'd5,  "no hazard: no match"            )                            ;

    //-- Hazard on rs1 ---------------------------------------------------------------------//
    check( 1'b1, 5'd1,  5'd1,  5'd2,  "hazard: rd==rs1"                )                            ;
    check( 1'b1, 5'd15, 5'd15, 5'd8,  "hazard: rd==rs1 high reg"       )                            ;

    //-- Hazard on rs2 ---------------------------------------------------------------------//
    check( 1'b1, 5'd2,  5'd3,  5'd2,  "hazard: rd==rs2"                )                            ;
    check( 1'b1, 5'd31, 5'd0,  5'd31, "hazard: rd==rs2 max reg"        )                            ;

    //-- Hazard on both --------------------------------------------------------------------//
    check( 1'b1, 5'd7,  5'd7,  5'd7,  "hazard: rd==rs1==rs2"           )                            ;

    //-- Random stimulus -------------------------------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic                        rm                                                               ;
      logic [NB_ADDR - 1 : 0]      rrd, rrs1, rrs2                                                  ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rm   = $urandom_range(0, 1)                                                                 ;
        rrd  = $urandom_range(0, 31)                                                                ;
        rrs1 = $urandom_range(0, 31)                                                                ;
        rrs2 = $urandom_range(0, 31)                                                                ;
        check(rm, rrd, rrs1, rrs2, $sformatf("Random[%0d]", i))                                     ;
      end
    end

    $display("\n===== TB HAZARD DETECTION UNIT — DONE  =====\n")                                    ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("hazard_detection_unit_tb.vcd")                                                       ;
    $dumpvars(0, hazard_detection_unit_tb)                                                          ;
  end

endmodule
