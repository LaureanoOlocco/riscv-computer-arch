`timescale 1ns / 1ps

 module tb_ALU()                                                             ;

    localparam                                 NB_DATA      = 8             ;   // Tamaño del bus de datos
    localparam                                 NB_OP_CODE   = 6             ;   // Número de bits del código de operación  

    localparam                                 ADD_OP       = 6'b100000     ;
    localparam                                 SUB_OP       = 6'b100010     ;
    localparam                                 AND_OP       = 6'b100100     ;
    localparam                                 OR_OP        = 6'b100101     ;
    localparam                                 XOR_OP       = 6'b100110     ;
    localparam                                 SRA_OP       = 6'b000011     ;
    localparam                                 SRL_OP       = 6'b000010     ;
    localparam                                 NOR_OP       = 6'b100111     ;      
    
    localparam                                 N_ITERATIONS = 1000          ;
    localparam                                 MAX_NUMBER   = 255           ;

    logic                                      o_zero                       ;
    logic                                      o_carry                      ;
    logic       [NB_DATA             - 1 : 0]  o_result                     ;  // Salida de la alu
    logic       [NB_DATA             - 1 : 0]  i_data_a                     ;  // 8 bits para a
    logic       [NB_DATA             - 1 : 0]  i_data_b                     ;  // 8 bits para b
    logic       [NB_OP_CODE          - 1 : 0]  i_op_code                    ;  // 8 bits para operador
    logic                                      clock                        ;
    
    ALU#(
    .NB_DATA    (NB_DATA                                                   ),
    .NB_OP_CODE (NB_OP_CODE                                                )
    )  
    u_alu          
    (              
    .o_zero     (o_zero                                                    ),
    .o_carry    (o_carry                                                   ),
    .o_result   (o_result                                                  ),  // Salida de la alu
    .i_data_a   (i_data_a                                                  ),  // 8 bits para a
    .i_data_b   (i_data_b                                                  ),  // 8 bits para b
    .i_op_code  (i_op_code                                                 )   // 8 bits para operador
    )                                                                       ;

    always #5 clock = ~clock                                                ;

    function automatic logic [NB_DATA : 0] apply_op_code(
        input logic [NB_OP_CODE - 1 : 0] op_code
    );
    begin
        logic [NB_DATA : 0] a_ext = {1'b0, i_data_a}                        ;
        logic [NB_DATA : 0] b_ext = {1'b0, i_data_b}                        ;
        case (op_code)
            ADD_OP : apply_op_code = a_ext + b_ext                          ;
            SUB_OP : apply_op_code = a_ext - b_ext                          ;
            AND_OP : apply_op_code = {1'b0, (i_data_a & i_data_b)}          ;
            OR_OP  : apply_op_code = {1'b0, (i_data_a | i_data_b)}          ;
            XOR_OP : apply_op_code = {1'b0, (i_data_a ^ i_data_b)}          ;
            SRA_OP : apply_op_code = {1'b0, ($signed(i_data_a) >>> i_data_b[$clog2(NB_DATA)-1:0])};
            SRL_OP : apply_op_code = {1'b0, (i_data_a >>  i_data_b[$clog2(NB_DATA)-1:0])};
            NOR_OP : apply_op_code = {1'b0, ~(i_data_a | i_data_b)}         ;
            default: apply_op_code = {(NB_DATA + 1){1'b0}}                  ;
        endcase
    end
    endfunction


    task automatic check_op(input logic [NB_OP_CODE - 1 : 0] op_code_in)    ;
    begin
        logic [NB_DATA:0] exp = apply_op_code(op_code_in)                   ;
        logic             cz  = ~(|exp)                                     ;
        logic             cc  = ((op_code_in == ADD_OP) &&  exp[NB_DATA])  ||
                                ((op_code_in == SUB_OP) && ~exp[NB_DATA])   ;

        if (o_result !== exp[NB_DATA-1:0]) 
        begin
            $error("Resultado incorrecto!")                                 ;
            $display("op_code: %b  expected: %0h  obtained: %0h"            ,
                     op_code_in, exp[NB_DATA-1:0], o_result)                ;
            $finish(2)                                                      ;
        end

        if (o_zero !== cz) 
        begin
            $error("ZERO incorrecto!")                                      ;
            $display("op_code: %b  expected_zero: %0b  obtained_zero: %0b"  ,
                     op_code_in, cz, o_zero)                                ;
            $finish(2)                                                      ;
        end

        if (o_carry !== cc) 
        begin
            $error("CARRY incorrecto!")                                     ;
            $display("op_code: %b  expected_carry: %0b  obtained_carry: %0b",
                     op_code_in, cc, o_carry)                               ;
            $finish(2)                                                      ;
        end
    end
    endtask

    initial 
    begin
        // Inicialización de las señales
        i_data_a = {NB_DATA{1'b0}}                                          ;
        i_data_b = {NB_DATA{1'b0}}                                          ;
        i_op_code= {NB_OP_CODE{1'b0}}                                       ;
        clock    = 1'b0                                                     ;

        repeat(N_ITERATIONS)
        begin
            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= ADD_OP                                               ;
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ;              

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= SUB_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code     = AND_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= OR_OP                                                ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= XOR_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= SRA_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= SRL_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 

            i_data_a = $urandom_range(0, MAX_NUMBER)                        ;   
            i_data_b = $urandom_range(0, MAX_NUMBER)                        ;  
            i_op_code= NOR_OP                                               ;        
            @(posedge clock)                                                ;        
            check_op(i_op_code)                                             ; 
        end
        $display("TEST PASSED");
        $finish(2);
    end

endmodule
