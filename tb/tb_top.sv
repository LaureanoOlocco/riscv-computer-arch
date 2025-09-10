// File name   : tb_top_alu.sv
// Date        : 2025-10-09
// Author      : Sofía Avalos - Laureano Olocco
// Description : Self-checking testbench for the top-level ALU wrapper.
//                - Parameters:
//                    * NB_DATA_OUT     = 10 // LED/output width (result + flags)
//                    * NB_DATA_IN      = 8  // input data width
//                    * NB_OP_CODE_IN   = 6  // opcode width
//                    * NB_INPUT_SELECT = 3  // selector width for button-driven input
//                    * N_ITERATIONS    = 300 // randomized test iterations
//                    * MAX_NUMBER      = 255 // maximum input value
//                - Instantiates the top_alu DUT and drives its inputs via emulated
//                  button presses (i_btn) and switch data (i_sw_data).
//                - Reference model implemented in function apply_op_code,
//                  which mirrors ALU operations (ADD, SUB, AND, OR, XOR, SRA, SRL, NOR).
//                - Tasks:
//                    * press_btn_and_load: simulates user pressing buttons to load operands/opcode.
//                    * check_expected: compares DUT output (o_led) against expected LED vector.
//                - Random stimulus generation for data_a_in and data_b_in using $urandom_range.
//                - Simulation flow:
//                    * Reset and initialization sequence
//                    * Iteratively test all ALU operations for N_ITERATIONS
//                    * Each operation is validated against the reference model
//                - Clock generation: 10 ns period (always #5ns).
//                - Reports "TEST PASSED" if all iterations complete successfully;
//                  mismatches trigger diagnostic $display and terminate simulation.
//--------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_top_alu()                                                                                 ;

//---------------------------------------- local params ------------------------------------------//
// General
    localparam                               NB_DATA_OUT    = 10                                    ;
    localparam                               NB_DATA_IN     = 8                                     ;
    localparam                               NB_OP_CODE_IN  = 6                                     ;
    localparam                               NB_INPUT_SELECT= 3                                     ;

// OP CODES                     
    localparam [NB_OP_CODE_IN       - 1 : 0] ADD_OP         = 6'b100000                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SUB_OP         = 6'b100010                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] AND_OP         = 6'b100100                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] OR_OP          = 6'b100101                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] XOR_OP         = 6'b100110                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SRA_OP         = 6'b000011                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SRL_OP         = 6'b000010                             ;
    localparam [NB_OP_CODE_IN       - 1 : 0] NOR_OP         = 6'b100111                             ;

// Btns         
    localparam                               DATA_A         = 2'b00                                 ; // i_btn[0]
    localparam                               DATA_B         = 2'b01                                 ; // i_btn[1]
    localparam                               OP_CODE        = 2'b10                                 ; // i_btn[2]

// Test         
    localparam                               N_ITERATIONS = 300;            
    localparam                               MAX_NUMBER   = (1<<NB_DATA_IN)-1                       ;

//------------------------------------------- Logics ---------------------------------------------// 
    logic       [NB_DATA_OUT        - 1 : 0] o_led                                                  ;
    logic       [NB_INPUT_SELECT    - 1 : 0] i_btn                                                  ;
    logic       [NB_DATA_IN         - 1 : 0] i_sw_data                                              ;
    logic                                    i_rst                                                  ;
    logic                                    clock                                                  ;

//-------------------------------------------- Clock ---------------------------------------------// 
    always #5ns clock = ~clock                                                                      ;

//---------------------------------------- Functions & Tasks -------------------------------------// 
    function automatic logic [NB_DATA_IN : 0] apply_op_code(
        input logic [NB_DATA_IN   - 1 : 0] data_a_in                                                ,
        input logic [NB_DATA_IN   - 1 : 0] data_b_in                                                ,
        input logic [NB_OP_CODE_IN- 1 : 0] op_code
    )                                                                                               ;
        case (op_code)
            ADD_OP : apply_op_code = {1'b0, data_a_in} + {1'b0, data_b_in}                          ;
            SUB_OP : apply_op_code = {1'b0, data_a_in} - {1'b0, data_b_in}                          ;
            AND_OP : apply_op_code = {1'b0, (data_a_in & data_b_in)}                                ;
            OR_OP  : apply_op_code = {1'b0, (data_a_in | data_b_in)}                                ;
            XOR_OP : apply_op_code = {1'b0, (data_a_in ^ data_b_in)}                                ;
            SRA_OP : apply_op_code = {1'b0, ($signed(data_a_in) >>> data_b_in[$clog2(NB_DATA_IN)-1:0])};
            SRL_OP : apply_op_code = {1'b0, (data_a_in >>  data_b_in[$clog2(NB_DATA_IN)-1:0])}      ;
            NOR_OP : apply_op_code = {1'b0, ~(data_a_in | data_b_in)}                               ;
            default: apply_op_code = {(NB_DATA_IN + 1){1'b0}}                                       ;
        endcase 
    endfunction

    task automatic press_btn_and_load(
        input logic [NB_DATA_IN     - 1 : 0] data_a_in                                              ,
        input logic [NB_DATA_IN     - 1 : 0] data_b_in                                              ,
        input logic [NB_OP_CODE_IN  - 1 : 0] op_code
    );
    begin
        // Cargar data_a_in
        i_sw_data = data_a_in                                                                       ;  
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b001                                                                          ;     
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b000                                                                          ;      
        repeat(10)@(posedge clock)                                                                  ;

        // Cargar data_b_in         
        i_sw_data = data_b_in                                                                       ;  
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b010                                                                          ;     
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b000                                                                          ;     
        repeat(10)@(posedge clock)                                                                  ;

        // Cargar op_code (zero-extend data_a_in NB_DATA_IN)            
        i_sw_data = {{(NB_DATA_IN-NB_OP_CODE_IN){1'b0}}, op_code};          
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b100                                                                          ;
        repeat(10)@(posedge clock)                                                                  ;
        i_btn     = 3'b000                                                                          ;
        repeat(10)@(posedge clock)                                                                  ;
    end
    endtask

    task automatic check_expected(
        input string                         name                                                   ,
        input logic [NB_DATA_IN     - 1 : 0] data_a_in                                              ,
        input logic [NB_DATA_IN     - 1 : 0] data_b_in                                              ,
        input logic [NB_OP_CODE_IN  - 1 : 0] op_code        
    );      
        logic       [NB_DATA_IN         : 0] ext                                                    ;
        logic                                cz, cc                                                 ;
        logic       [NB_DATA_OUT    - 1 : 0] expected_led                                           ;
    begin       
        ext         = apply_op_code(data_a_in, data_b_in, op_code)                                  ;
        cz          = ~(|ext)                                                                       ; 
        cc          = ((op_code==ADD_OP) &&  ext[NB_DATA_IN]) ||        
                      ((op_code==SUB_OP) && ~ext[NB_DATA_IN])                                       ;
        expected_led= {cz, cc, ext[NB_DATA_IN-1:0]}                                                 ;
            
        if (o_led !== expected_led)     
         begin      
            $display("TEST FAILED! %s ERROR", name)                                                 ;
            $display("Expected: %0h", expected_led)                                                 ;
            $display("Obtained: %0h", o_led)                                                        ;
            $finish(2);
        end
    end
    endtask

//----------------------------------------- Test logic -------------------------------------------// 
    initial 
    begin
        logic [NB_DATA_IN    - 1 : 0] data_a_in, data_b_in                                          ;
        logic [NB_OP_CODE_IN - 1 : 0] op_code                                                       ;

        // Init     
        clock     = 1'b0                                                                            ; 
        i_btn     = {NB_INPUT_SELECT{1'b0}}                                                         ; 
        i_sw_data = {NB_DATA_IN{1'b0}}                                                              ;
        i_rst     = 1'b1                                                                            ;
        repeat(3) @(posedge clock)                                                                  ; 
        i_rst = 1'b0                                                                                ;
        repeat(2) @(posedge clock)                                                                  ;

        repeat(N_ITERATIONS)        
        begin       
            // ADD      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, ADD_OP)                                        ;
            check_expected("ADD", data_a_in, data_b_in, ADD_OP)                                     ;

            // SUB      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, SUB_OP)                                        ;
            check_expected("SUB", data_a_in, data_b_in, SUB_OP)                                     ;

            // AND      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, AND_OP)                                        ;
            check_expected("AND", data_a_in, data_b_in, AND_OP)                                     ;

            // OR       
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, OR_OP)                                         ;
            check_expected("OR", data_a_in, data_b_in, OR_OP)                                       ;

            // XOR      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, XOR_OP)                                        ;
            check_expected("XOR", data_a_in, data_b_in, XOR_OP)                                     ;

            // SRA      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, SRA_OP)                                        ;
            check_expected("SRA", data_a_in, data_b_in, SRA_OP)                                     ;

            // SRL      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, SRL_OP)                                        ;
            check_expected("SRL", data_a_in, data_b_in, SRL_OP)                                     ;

            // NOR      
            data_a_in = $urandom_range(0, MAX_NUMBER)                                               ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                               ;
            press_btn_and_load(data_a_in, data_b_in, NOR_OP)                                        ;
            check_expected("NOR", data_a_in, data_b_in, NOR_OP)                                     ;
        end     

        $display("TEST PASSED")                                                                     ;
        $finish(2)                                                                                  ;
    end
//---------------------------------------------Instances -----------------------------------------// 
    top_alu #(
    .NB_DATA_OUT     (NB_DATA_OUT                                                                   ),
    .NB_DATA_IN      (NB_DATA_IN                                                                    ),
    .NB_OP_CODE_IN   (NB_OP_CODE_IN                                                                 ),
    .NB_INPUT_SELECT (NB_INPUT_SELECT                                                               )
) u_top (               
    .o_led           (o_led                                                                         ),
    .i_btn           (i_btn                                                                         ),
    .i_sw_data       (i_sw_data                                                                     ),
    .i_rst           (i_rst                                                                         ),
    .clock           (clock                                                                         )
                                                                                                    ;

endmodule
