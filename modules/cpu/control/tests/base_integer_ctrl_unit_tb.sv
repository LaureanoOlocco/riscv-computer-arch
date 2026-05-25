//--------------------------------------------------------------------------------------------------
// Project Name: RISC-V Computer Architecture
// Module Name : base_integer_ctrl_unit_tb.sv
// Date        : 2025-12-13
// Author      : Sofía Avalos - Laureano Olocco
// Description : SystemVerilog testbench for the Base Integer Control Unit.
//                - Covers: all opcodes, data size from func3, default (unknown opcode), random.
//--------------------------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module base_integer_ctrl_unit_tb                                                                    ;

//----------------------------------------- PARAMETERS -------------------------------------------//
  localparam int unsigned                                        NB_CTRL     = 9                   ;
  localparam int unsigned                                        NB_OPCODE   = 7                   ;
  localparam int unsigned                                        NB_FUNC3    = 3                   ;
  localparam int unsigned                                        N_RANDOM    = 500                 ;
  localparam int unsigned                                        CLK_PERIOD  = 10                  ;

//----> Opcodes
  localparam logic [NB_OPCODE - 1 : 0]                           R_TYPE      = 7'b0110011          ;
  localparam logic [NB_OPCODE - 1 : 0]                           I_TYPE_1    = 7'b0010011          ;
  localparam logic [NB_OPCODE - 1 : 0]                           I_TYPE_2    = 7'b0000011          ;
  localparam logic [NB_OPCODE - 1 : 0]                           S_TYPE      = 7'b0100011          ;
  localparam logic [NB_OPCODE - 1 : 0]                           U_TYPE      = 7'b0110111          ;

//----> Control word bit indices
  localparam int unsigned                                        REG_WRITE_IDX  = 0                ;
  localparam int unsigned                                        MEM_READ_IDX   = 1                ;
  localparam int unsigned                                        MEM_WRITE_IDX  = 2                ;
  localparam int unsigned                                        ALU_SRC_IDX    = 3                ;
  localparam int unsigned                                        MEM_TO_REG_IDX = 4                ;
  localparam int unsigned                                        ALU_OP_IDX     = 5                ;
  localparam int unsigned                                        DATA_SIZE_IDX  = 7                ;

//------------------------------------------ DUT SIGNALS -----------------------------------------//
  logic          [NB_CTRL   - 1 : 0]                             o_ctrl                             ;
  logic          [NB_OPCODE - 1 : 0]                             i_opcode                           ;
  logic          [NB_FUNC3  - 1 : 0]                             i_func3                            ;

//---------------------------------------- REFERENCE CLOCK ----------------------------------------//
  logic                                                         clk                               ;
  initial  clk = 1'b0                                                                               ;
  always #(CLK_PERIOD / 2)                                      clk = ~clk                         ;

//----------------------------------------- DUT INSTANCE -----------------------------------------//
  base_integer_ctrl_unit
  #(
    .NB_CTRL   ( NB_CTRL   ),
    .NB_OPCODE ( NB_OPCODE ),
    .NB_FUNC3  ( NB_FUNC3  )
  ) u_ctrl_unit (
    .o_ctrl   ( o_ctrl   ),
    .i_opcode ( i_opcode ),
    .i_func3  ( i_func3  )
  )                                                                                                 ;

//------------------------------------------- FUNCTIONS ------------------------------------------//
  // Check individual control bits by name
  function automatic logic f_reg_write  (); f_reg_write  = o_ctrl[REG_WRITE_IDX ]; endfunction
  function automatic logic f_mem_read   (); f_mem_read   = o_ctrl[MEM_READ_IDX  ]; endfunction
  function automatic logic f_mem_write  (); f_mem_write  = o_ctrl[MEM_WRITE_IDX ]; endfunction
  function automatic logic f_alu_src    (); f_alu_src    = o_ctrl[ALU_SRC_IDX   ]; endfunction
  function automatic logic f_mem_to_reg (); f_mem_to_reg = o_ctrl[MEM_TO_REG_IDX]; endfunction

//---------------------------------------- SVA ASSERTIONS ----------------------------------------//
  // R-Type: RegWrite=1, ALUSrc=0, MemRead=0, MemWrite=0
  property p_r_type_ctrl                                                                            ;
    @(posedge clk) (i_opcode == R_TYPE) |->
      (o_ctrl[REG_WRITE_IDX] == 1'b1 && o_ctrl[ALU_SRC_IDX]   == 1'b0 &&
       o_ctrl[MEM_READ_IDX]  == 1'b0 && o_ctrl[MEM_WRITE_IDX] == 1'b0)                             ;
  endproperty
  a_r_type_ctrl : assert property (p_r_type_ctrl)
    else $error("[ASSERT FAIL] a_r_type_ctrl | ctrl=%0b", o_ctrl)                                  ;

  // Load: MemRead=1, RegWrite=1, MemToReg=1, ALUSrc=1
  property p_load_ctrl                                                                              ;
    @(posedge clk) (i_opcode == I_TYPE_2) |->
      (o_ctrl[REG_WRITE_IDX]  == 1'b1 && o_ctrl[MEM_READ_IDX]   == 1'b1 &&
       o_ctrl[MEM_TO_REG_IDX] == 1'b1 && o_ctrl[ALU_SRC_IDX]    == 1'b1)                           ;
  endproperty
  a_load_ctrl : assert property (p_load_ctrl)
    else $error("[ASSERT FAIL] a_load_ctrl | ctrl=%0b", o_ctrl)                                    ;

  // Store: MemWrite=1, RegWrite=0
  property p_store_ctrl                                                                             ;
    @(posedge clk) (i_opcode == S_TYPE) |->
      (o_ctrl[MEM_WRITE_IDX] == 1'b1 && o_ctrl[REG_WRITE_IDX] == 1'b0)                             ;
  endproperty
  a_store_ctrl : assert property (p_store_ctrl)
    else $error("[ASSERT FAIL] a_store_ctrl | ctrl=%0b", o_ctrl)                                   ;

  // Default: all zero for unknown opcodes
  property p_default_zero                                                                           ;
    @(posedge clk)
    (i_opcode != R_TYPE && i_opcode != I_TYPE_1 && i_opcode != I_TYPE_2 &&
     i_opcode != S_TYPE && i_opcode != U_TYPE)
    |-> (o_ctrl[REG_WRITE_IDX] == 1'b0 && o_ctrl[MEM_WRITE_IDX] == 1'b0)                          ;
  endproperty
  a_default_zero : assert property (p_default_zero)
    else $error("[ASSERT FAIL] a_default_zero | opcode=%0b ctrl=%0b", i_opcode, o_ctrl)            ;

//------------------------------------------ TASK: CHECK -----------------------------------------//
  task automatic check (
    input  logic   [NB_OPCODE - 1 : 0]                           opcode                             ,
    input  logic   [NB_FUNC3  - 1 : 0]                           func3                              ,
    input  logic   [NB_CTRL   - 1 : 0]                           expected                           ,
    input  string                                                test_name
  )                                                                                                 ;
    i_opcode = opcode                                                                               ;
    i_func3  = func3                                                                                ;
    #1                                                                                              ;
    if (o_ctrl !== expected)
      $error  ("[FAIL] %s | opcode=%0b f3=%0b | got=%0b exp=%0b"                                   ,
                test_name, opcode, func3, o_ctrl, expected)                                        ;
    else
      $display("[PASS] %s | ctrl=%0b", test_name, o_ctrl)                                          ;
    @(posedge clk)                                                                                  ;
  endtask

//----------------------------------------- TEST STIMULUS ----------------------------------------//
  initial begin : stimulus
    i_opcode = '0; i_func3 = '0                                                                     ;
    @(posedge clk)                                                                                  ;

    $display("\n===== BASE INTEGER CTRL UNIT TB — START =====\n")                                   ;

    // Expected ctrl word: [8:7]=DataSize [6:5]=ALUOp [4]=MemToReg [3]=ALUSrc [2]=MemWrite [1]=MemRead [0]=RegWrite
    // R-Type: rw=1 mr=0 mw=0 as=0 m2r=0 aluop=11 dsz=00
    check( R_TYPE,  3'b010, 9'b00_11_0_0_0_0_1, "R-Type"       )                                   ;
    // I-Type arith: rw=1 mr=0 mw=0 as=1 m2r=0 aluop=10
    check( I_TYPE_1,3'b010, 9'b00_10_0_1_0_0_1, "I-Type arith" )                                   ;
    // Load LW (func3=010): rw=1 mr=1 mw=0 as=1 m2r=1 aluop=00 dsz=11
    check( I_TYPE_2,3'b010, 9'b11_00_1_1_1_0_1, "Load LW"      )                                   ;
    // Load LB (func3=000): dsz=01
    check( I_TYPE_2,3'b000, 9'b01_00_1_1_1_0_1, "Load LB"      )                                   ;
    // Load LH (func3=001): dsz=10
    check( I_TYPE_2,3'b001, 9'b10_00_1_1_1_0_1, "Load LH"      )                                   ;
    // Store SW (func3=010): rw=0 mr=0 mw=1 as=1 dsz=11
    check( S_TYPE,  3'b010, 9'b11_00_0_1_0_0_0, "Store SW"     )                                   ;
    // Store SB (func3=000): dsz=01
    check( S_TYPE,  3'b000, 9'b01_00_0_1_0_0_0, "Store SB"     )                                   ;
    // U-Type: rw=1 as=1
    check( U_TYPE,  3'b000, 9'b00_00_0_1_0_0_1, "U-Type"       )                                   ;
    // Unknown opcode
    check( 7'b1111111, 3'b000, 9'b00_00_0_0_0_0_0, "Unknown opcode → 0" )                         ;

    //-- Random (just check no X/Z propagation) -------------------------------------------//
    $display("\n--- Random vectors (%0d) ---", N_RANDOM)                                            ;
    begin
      logic [NB_OPCODE - 1 : 0] rop                                                                ;
      logic [NB_FUNC3  - 1 : 0] rf3                                                                ;
      for (int i = 0; i < N_RANDOM; i++) begin
        rop = $urandom(); rf3 = $urandom()                                                          ;
        i_opcode = rop; i_func3 = rf3; #1                                                          ;
        if ($isunknown(o_ctrl))
          $error("[FAIL] Random[%0d] X/Z in output | opcode=%0b f3=%0b ctrl=%0b",
                  i, rop, rf3, o_ctrl)                                                             ;
        @(posedge clk)                                                                              ;
      end
      $display("[PASS] Random stimulus — no X/Z propagation")                                      ;
    end

    $display("\n===== BASE INTEGER CTRL UNIT TB — DONE  =====\n")                                   ;
    $finish                                                                                         ;
  end

//--------------------------------------- TIMEOUT WATCHDOG ----------------------------------------//
  initial begin
    #(CLK_PERIOD * (N_RANDOM + 200))                                                                ;
    $fatal(1, "[TIMEOUT] Testbench exceeded maximum simulation time.")                              ;
  end

//----------------------------------------- WAVEFORM DUMP ----------------------------------------//
  initial begin
    $dumpfile("base_integer_ctrl_unit_tb.vcd")                                                      ;
    $dumpvars(0, base_integer_ctrl_unit_tb)                                                         ;
  end

endmodule
