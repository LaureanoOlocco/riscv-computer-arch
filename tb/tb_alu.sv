`timescale 1ns / 1ps
// File name   : tb_ALU.sv
// Date        : 2025-10-09
// Author      : Sofía Avalos - Laureano Olocco
// Description : Self-checking testbench for the parameterizable ALU.
//                - Parameters:
//                    * NB_DATA    = 8  // datapath width
//                    * NB_OP_CODE = 6  // opcode width
//                    * N_ITERATIONS = 1000 // number of randomized test iterations
//                    * MAX_NUMBER   = 255  // maximum random value for operands
//                - Instantiates the ALU DUT with NB_DATA and NB_OP_CODE.
//                - Clock generation: 10 ns period (always #5ns).
//                - Reference model implemented in function apply_op_code, which mirrors
//                  the ALU operations (ADD, SUB, AND, OR, XOR, SRA, SRL, NOR).
//                - Task check_op:
//                    * Compares DUT outputs (o_result, o_zero, o_carry) against expected.
//                    * Reports mismatches with $error/$display and terminates simulation.
//                - Stimulus generation:
//                    * Randomized operands i_data_a, i_data_b using $urandom_range.
//                    * Iterates through all supported operations per iteration.
//                - Simulation flow:
//                    * Initialize inputs and clock
//                    * Repeat randomized tests for N_ITERATIONS
//                    * Apply each opcode and validate outputs
//                    * Display "TEST PASSED" upon successful completion.
//                - Purpose: Validate functional correctness of ALU operations prior to synthesis.
//--------------------------------------------------------------------------------------------------

module tb_ALU()                                                                                    ;

//---------------------------------------- local params ------------------------------------------// 
// General
    localparam                                 NB_DATA      = 8                                     ;   // Tamaño del bus de datos
    localparam                                 NB_OP_CODE   = 6                                     ;   // Número de bits del código de operación  
// OP CODES                     
    localparam                                 ADD_OP       = 6'b100000                             ;
    localparam                                 SUB_OP       = 6'b100010                             ;
    localparam                                 AND_OP       = 6'b100100                             ;
    localparam                                 OR_OP        = 6'b100101                             ;
    localparam                                 XOR_OP       = 6'b100110                             ;
    localparam                                 SRA_OP       = 6'b000011                             ;
    localparam                                 SRL_OP       = 6'b000010                             ;
    localparam                                 NOR_OP       = 6'b100111                             ;      
// Test
    localparam                                 N_ITERATIONS = 1000                                  ;
    localparam                                 MAX_NUMBER   = 255                                   ;

//------------------------------------------- Logics ---------------------------------------------// 
    logic                                      o_zero                                               ;
    logic                                      o_carry                                              ;
    logic       [NB_DATA             - 1 : 0]  o_result                                             ;  // Salida de la alu
    logic       [NB_DATA             - 1 : 0]  i_data_a                                             ;  // 8 bits para a
    logic       [NB_DATA             - 1 : 0]  i_data_b                                             ;  // 8 bits para b
    logic       [NB_OP_CODE          - 1 : 0]  i_op_code                                            ;  // 8 bits para operador
    logic                                      clock                                                ;

//-------------------------------------------- Clock ---------------------------------------------// 
    always #5ns clock = ~clock                                                                      ;

//---------------------------------------- Functions & Tasks -------------------------------------// 
    function automatic logic [NB_DATA : 0] apply_op_code(
        input logic [NB_OP_CODE - 1 : 0] op_code
    );
    begin
        case (op_code)          
            ADD_OP : apply_op_code = {1'b0, i_data_a} + {1'b0, i_data_b}                            ;
            SUB_OP : apply_op_code = {1'b0, i_data_a} - {1'b0, i_data_b}                            ;
            AND_OP : apply_op_code = {1'b0, (i_data_a & i_data_b)}                                  ;
            OR_OP  : apply_op_code = {1'b0, (i_data_a | i_data_b)}                                  ;
            XOR_OP : apply_op_code = {1'b0, (i_data_a ^ i_data_b)}                                  ;
            SRA_OP : apply_op_code = {1'b0, ($signed(i_data_a) >>> i_data_b[$clog2(NB_DATA)-1:0])}  ;
            SRL_OP : apply_op_code = {1'b0, (i_data_a >>  i_data_b[$clog2(NB_DATA)-1:0])}           ;
            NOR_OP : apply_op_code = {1'b0, ~(i_data_a | i_data_b)}                                 ;
            default: apply_op_code = {(NB_DATA + 1){1'b0}}                                          ;
        endcase
    end
    endfunction


    task automatic check_op(input logic [NB_OP_CODE - 1 : 0] op_code_in)                            ;
    begin                              
        logic [NB_DATA:0] exp = apply_op_code(op_code_in)                                           ;
        logic             cz  = ~(|exp)                                                             ;
        logic             cc  = ((op_code_in == ADD_OP) &&  exp[NB_DATA])                          ||
                                ((op_code_in == SUB_OP) && ~exp[NB_DATA])                           ;

        if (o_result !== exp[NB_DATA-1:0]) 
        begin
            $error("TEST FAILED: RESULT ERROR")                                                     ;
            $display("OP code: %b, Expected: %0h, Obtained: %0h"                                    ,
                     op_code_in, exp[NB_DATA-1:0], o_result)                                        ;
            $finish(2)                                                                              ;
        end

        if (o_zero !== cz) 
        begin
            $error("TEST FAILED: ZERO ERROR")                                                       ;
            $display("OP code: %b, Expected zero: %0b, Obtained_zero: %0b"                          ,
                     op_code_in, cz, o_zero)                                                        ;
            $finish(2)                                                                              ;
        end

        if (o_carry !== cc) 
        begin
            $error("TEST FAILED: CARRY ERROR")                                                      ;    
            $display("OP code: %b, Expected carry: %0b,  Obtained carry: %0b"                       ,
                     op_code_in, cc, o_carry)                                                       ;
            $finish(2)                                                                              ;
        end
    end
    endtask

//----------------------------------------- Test logic -------------------------------------------// 
    initial 
    begin
        // Inicialización de las señales
        i_data_a = {NB_DATA{1'b0}}                                                                  ;
        i_data_b = {NB_DATA{1'b0}}                                                                  ;
        i_op_code= {NB_OP_CODE{1'b0}}                                                               ;
        clock    = 1'b0                                                                             ;

        repeat(N_ITERATIONS)                        
        begin                       
            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= ADD_OP                                                                       ;
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ;              

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= SUB_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code     = AND_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= OR_OP                                                                        ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= XOR_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= SRA_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= SRL_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                                                ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                                                ;  
            i_op_code= NOR_OP                                                                       ;        
            @(posedge clock)                                                                        ;        
            check_op(i_op_code)                                                                     ; 
        end
        $display("TEST PASSED")                                                                     ;
        $finish(2)                                                                                  ;
    end

//---------------------------------------------Instances -----------------------------------------// 
     ALU#(
        .NB_DATA    (NB_DATA                                                                        ),
        .NB_OP_CODE (NB_OP_CODE                                                                     )
        )                       
        u_alu                               
        (                                   
        .o_zero     (o_zero                                                                         ),
        .o_carry    (o_carry                                                                        ),
        .o_result   (o_result                                                                       ),  // Salida de la alu
        .i_data_a   (i_data_a                                                                       ),  // 8 bits para a
        .i_data_b   (i_data_b                                                                       ),  // 8 bits para b
        .i_op_code  (i_op_code                                                                      )   // 8 bits para operador
    )                                                                                               ;

endmodule
