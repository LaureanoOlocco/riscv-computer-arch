`timescale 1ns / 1ps

module tb_top_alu()                                                                     ;

    // -------- Parámetros del TOP --------
    localparam                               NB_DATA_OUT    = 10                        ;
    localparam                               NB_DATA_IN     = 8                         ;
    localparam                               NB_OP_CODE_IN  = 6                         ;
    localparam                               NB_INPUT_SELECT= 3                         ;

    // -------- OpCodes --------
    localparam [NB_OP_CODE_IN       - 1 : 0] ADD_OP         = 6'b100000                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SUB_OP         = 6'b100010                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] AND_OP         = 6'b100100                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] OR_OP          = 6'b100101                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] XOR_OP         = 6'b100110                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SRA_OP         = 6'b000011                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] SRL_OP         = 6'b000010                 ;
    localparam [NB_OP_CODE_IN       - 1 : 0] NOR_OP         = 6'b100111                 ;

    // -------- Botones (índices) --------
    localparam                               DATA_A         = 2'b00                     ; // i_btn[0]
    localparam                               DATA_B         = 2'b01                     ; // i_btn[1]
    localparam                               OP_CODE        = 2'b10                     ; // i_btn[2]

    localparam                               N_ITERATIONS = 300;
    localparam                               MAX_NUMBER   = (1<<NB_DATA_IN)-1           ;

    // -------- I/O del DUT --------
    logic       [NB_DATA_OUT        - 1 : 0] o_led                                      ;
    logic       [NB_INPUT_SELECT    - 1 : 0] i_btn                                      ;
    logic       [NB_DATA_IN         - 1 : 0] i_sw_data                                  ;
    logic                                    i_rst                                      ;
    logic                                    clock                                      ;

    // -------- Instancia del TOP --------
    top_alu #(
        .NB_DATA_OUT     (NB_DATA_OUT                                                   ),
        .NB_DATA_IN      (NB_DATA_IN                                                    ),
        .NB_OP_CODE_IN   (NB_OP_CODE_IN                                                 ),
        .NB_INPUT_SELECT (NB_INPUT_SELECT                                               )
    ) u_top (
        .o_led           (o_led                                                         ),
        .i_btn           (i_btn                                                         ),
        .i_sw_data       (i_sw_data                                                     ),
        .i_rst           (i_rst                                                         ),
        .clock           (clock                                                         )
    );

    // -------- Reloj --------
    always #5 clock = ~clock                                                            ;

    // -------- Función de operación esperada --------
    function automatic logic [NB_DATA_IN : 0] apply_op_code(
        input logic [NB_DATA_IN   - 1 : 0] data_a_in                                    ,
        input logic [NB_DATA_IN   - 1 : 0] data_b_in                                    ,
        input logic [NB_OP_CODE_IN- 1 : 0] op_code
    );
        logic [NB_DATA_IN:0] a_ext = {1'b0, data_a_in}                                  ;
        logic [NB_DATA_IN:0] b_ext = {1'b0, data_b_in}                                  ;
        case (op_code)
            ADD_OP : apply_op_code = a_ext + b_ext                                      ;
            SUB_OP : apply_op_code = a_ext - b_ext                                      ;
            AND_OP : apply_op_code = {1'b0, (data_a_in & data_b_in)}                    ;
            OR_OP  : apply_op_code = {1'b0, (data_a_in | data_b_in)}                    ;
            XOR_OP : apply_op_code = {1'b0, (data_a_in ^ data_b_in)}                    ;
            SRA_OP : apply_op_code = {1'b0, ($signed(data_a_in) >>> data_b_in[$clog2(NB_DATA_IN)-1:0])};
            SRL_OP : apply_op_code = {1'b0, (data_a_in >>  data_b_in[$clog2(NB_DATA_IN)-1:0])};
            NOR_OP : apply_op_code = {1'b0, ~(data_a_in | data_b_in)}                   ;
            default: apply_op_code = {(NB_DATA_IN + 1){1'b0}}                           ;
        endcase 
    endfunction

    // -------- Apretar botones y cargar data_a_in, data_b_in y op_code --------
    task automatic press_btn_and_load(
        input logic [NB_DATA_IN     - 1 : 0] data_a_in                                  ,
        input logic [NB_DATA_IN     - 1 : 0] data_b_in                                  ,
        input logic [NB_OP_CODE_IN  - 1 : 0] op_code
    );
    begin
        // Cargar data_a_in
        i_sw_data = data_a_in                                                           ;  
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b001                                                              ;     
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b000                                                              ;      
        repeat(10)@(posedge clock)                                                      ;

        // Cargar data_b_in
        i_sw_data = data_b_in                                                           ;  
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b010                                                              ;     
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b000                                                              ;     
        repeat(10)@(posedge clock)                                                      ;

        // Cargar op_code (zero-extend data_a_in NB_DATA_IN)
        i_sw_data = {{(NB_DATA_IN-NB_OP_CODE_IN){1'b0}}, op_code}; 
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b100                                                              ;
        repeat(10)@(posedge clock)                                                      ;
        i_btn     = 3'b000                                                              ;
        repeat(10)@(posedge clock)                                                      ;
    end
    endtask

    // --------comparar esperado vs o_led --------
    task automatic check_expected(
        input string                         name                                           ,
        input logic [NB_DATA_IN     - 1 : 0] data_a_in                                      ,
        input logic [NB_DATA_IN     - 1 : 0] data_b_in                                      ,
        input logic [NB_OP_CODE_IN  - 1 : 0] op_code
    );
        logic       [NB_DATA_IN         : 0] ext                                            ;
        logic                                cz, cc                                         ;
        logic       [NB_DATA_OUT    - 1 : 0] expected_led                                   ;
    begin
        ext         = apply_op_code(data_a_in, data_b_in, op_code)                          ;
        cz          = ~(|ext)                                                               ; 
        cc          = ((op_code==ADD_OP) &&  ext[NB_DATA_IN]) ||
                      ((op_code==SUB_OP) && ~ext[NB_DATA_IN])                               ;
        expected_led= {cz, cc, ext[NB_DATA_IN-1:0]}                                         ;

        if (o_led !== expected_led)
         begin
            $display("Error en %s", name)                                                   ;
            $display("Expected: %0h", expected_led)                                         ;
            $display("Obtained: %0h", o_led)                                                ;
            $finish(2);
        end
    end
    endtask

    // -------- Test principal --------
    initial 
    begin
        logic [NB_DATA_IN    - 1 : 0] data_a_in, data_b_in                                  ;
        logic [NB_OP_CODE_IN - 1 : 0] op_code                                               ;

        // Init
        clock     = 1'b0                                                                    ; 
        i_btn     = {NB_INPUT_SELECT{1'b0}}                                                 ; 
        i_sw_data = {NB_DATA_IN{1'b0}}                                                      ;
        i_rst     = 1'b1                                                                    ;
        repeat(3) @(posedge clock)                                                          ; 
        i_rst = 1'b0                                                                        ;
        repeat(2) @(posedge clock)                                                          ;

        repeat(N_ITERATIONS) 
        begin
            // ADD
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, ADD_OP)                                ;
            check_expected("ADD", data_a_in, data_b_in, ADD_OP)                             ;

            // SUB
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, SUB_OP)                                ;
            check_expected("SUB", data_a_in, data_b_in, SUB_OP)                             ;

            // AND
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, AND_OP)                                ;
            check_expected("AND", data_a_in, data_b_in, AND_OP)                             ;

            // OR
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, OR_OP)                                 ;
            check_expected("OR", data_a_in, data_b_in, OR_OP)                               ;

            // XOR
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, XOR_OP)                                ;
            check_expected("XOR", data_a_in, data_b_in, XOR_OP)                             ;

            // SRA 
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, SRA_OP)                                ;
            check_expected("SRA", data_a_in, data_b_in, SRA_OP)                             ;

            // SRL 
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, SRL_OP)                                ;
            check_expected("SRL", data_a_in, data_b_in, SRL_OP)                             ;

            // NOR
            data_a_in = $urandom_range(0, MAX_NUMBER)                                       ;               
            data_b_in = $urandom_range(0, MAX_NUMBER)                                       ;
            press_btn_and_load(data_a_in, data_b_in, NOR_OP)                                ;
            check_expected("NOR", data_a_in, data_b_in, NOR_OP)                             ;
        end

        $display("TEST PASSED")                                                             ;
        $finish(2)                                                                          ;
    end

endmodule
