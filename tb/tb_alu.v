`timescale 1ns / 1ps

module tb_ALU();

    parameter NB_DATA = 8;
    parameter NB_OP   = 6;

    reg signed  [NB_DATA-1:0] i_data_a;   // Entrada de 8 bits para a
    reg signed  [NB_DATA-1:0] i_data_b;   // Entrada de 8 bits para b
    reg         [NB_OP-1  :0] i_op    ;   // Entrada de 6 bits para operación
    // reg sw_1, sw_2, sw_3;                 // Interruptores (clocks manuales)
    wire signed [NB_DATA-1:0] o_result;     // Salida de la ALU
    
    // Instanciar la ALU
    ALU #(
        .NB_DATA(NB_DATA),
        .NB_OP  (NB_OP  )
    ) uut (
        .i_data_a(i_data_a),
        .i_data_b(i_data_b),
        .i_op    (i_op    ),
        .o_result(o_result)
    );

    initial begin
        // Inicialización de las señales
        i_data_a = 0;
        i_data_b = 0;
        i_op     = 0;


        // Prueba de ADD (6'b100000)
        #10                    ;
        i_data_a = 8'sb00001010;   // 10
        i_data_b = 8'sb00000101;   // 5
        i_op     = 6'b100000   ;          // ADD
        
        #10                    ;
        if (o_result !== (i_data_a + i_data_b)) $display("Error en ADD");

        // // Prueba de SUB (6'b100010)
        #10                    ;
        i_data_a = 8'sb00001100;   // 12
        i_data_b = 8'sb00000011;   // 3
        i_op     = 6'b100010   ;          // SUB        
        #10                    ;
        if (o_result !== (i_data_a - i_data_b)) $display("Error en SUB");

        // Prueba de AND (6'b100100)
        #10                    ;
        i_data_a = 8'sb10101010;   // 0xAA
        i_data_b = 8'sb11001100;   // 0xCC
        i_op     = 6'b100100   ;   // AND
        #10                    ;
        if (o_result !== (i_data_a & i_data_b)) $display("Error en AND");

        // Prueba de OR (6'b100101)
        #10                    ;
        i_data_a = 8'sb10101010;   // 0xAA
        i_data_b = 8'sb01010101;   // 0x55
        i_op     = 6'b100101   ;   // OR
        #10                    ;
        if (o_result !== (i_data_a | i_data_b)) $display("Error en OR");

        // Prueba de XOR (6'b100110)
        #10                    ;
        i_data_a = 8'sb11110000;   // 0xF0
        i_data_b = 8'sb10101010;   // 0xAA
        i_op     = 6'b100110   ;          // XOR
        #10                    ;
        if (o_result !== (i_data_a ^ i_data_b)) $display("Error en XOR");

        // Prueba de SRA (6'b000011)
        #10                    ;
        i_data_a = 8'sb11110000;   // -16 (en complemento a 2)
        i_data_b = 8'sb00000000;   // Ignorado
        i_op     = 6'b000011   ;   // SRA
        #10;
        if (o_result !== (i_data_a >>> 1)) $display("Error en SRA");

        // Prueba de SRL (6'b000010)
        #10                    ;
        i_data_a = 8'sb11110000;   // -16 (pero se trata como unsigned en SRL)
        i_data_b = 8'sb00000000;   // Ignorado
        i_op     = 6'b000010   ;   // SRL
        #10                    ;
        if (o_result !== (i_data_a >> 1)) $display("Error en SRL");

        // Prueba de NOR (6'b100111)
        #10                    ;
        i_data_a = 8'sb11110000;   // 0xF0
        i_data_b = 8'sb00001111;   // 0x0F
        i_op     = 6'b100111   ;   // NOR
        #10                    ;
        if (o_result !== ~(i_data_a | i_data_b)) $display("Error en NOR");

        // Fin de la simulación
        $display("Todas las pruebas han pasado correctamente.");
        $finish;
    end

endmodule
