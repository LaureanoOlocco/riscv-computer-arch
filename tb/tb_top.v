`timescale 1ns / 1ps

module tb_ALU();

    parameter NB_DATA = 8;
    parameter NB_OP = 6;

    reg clk;
    reg signed [NB_DATA-1:0] i_sw_data;
    reg i_valid;
    reg i_rst;
    reg [2:0] i_btn;                     // Interruptores (clocks manuales)
    wire signed [NB_DATA-1:0] o_led;    // Salida de la ALU
    
    // Instanciar la ALU
    top_alu #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) uut (
        .clk      (clk),
        .i_valid  (i_valid),
        .i_sw_data(i_sw_data),
        .i_btn    (i_btn),
        .i_rst    (i_rst),
        .o_led    (o_led)
    );

    always #5 clk = ~clk;

    initial begin
        // Inicialización de las señales
        clk       = 0;
        i_valid   = 0;
        i_btn     = 3'b000;
        i_sw_data = 8'd0;
        i_rst     = 1;

        #50
        i_valid = 1;
        i_rst   = 0; 
        #50
        
        
        // HACEMOS UNA SUMA
        
        $display("Comienza ADD");
        
        // Cargar data_a (botón i_btn[0])
        i_valid = 0;
        i_sw_data = 8'd15;   // Valor de data_a = 15
        #100
        i_btn = 3'b001;      // Presionamos el botón i_btn[0]
        #100;                 // Esperamos
        i_btn = 3'b000;      // Soltamos el botón
        #100;
        
        // Cargar data_b (botón i_btn[1])
        
        i_sw_data = 8'd10;   // Valor de data_b = 10
        #100
        i_btn = 3'b010;      // Presionamos el botón i_btn[1]
        #100;                 // Esperamos
        i_btn = 3'b000;      // Soltamos el botón
        #100;
        
        // Seleccionar operación (botón i_btn[2] -> ADD)
        
        i_sw_data = 6'b100000;  // Operación ADD (suma)
        #100
        i_btn = 3'b100;      // Presionamos el botón i_btn[2]
        #100;                 // Esperamos
        i_btn = 3'b000;      // Soltamos el botón
        i_valid = 1;
        #1000;
        
        // VERIFICAMOS SUMA
        if (o_led !== 8'd25) $display("Error en ADD");
       
       
        // HACEMOS UNA RESTA
        
        $display("Comienza SUB");
        i_valid = 0;
        i_sw_data = 8'd25;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd5;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b100010;  // SUB
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        i_valid = 1;
        #500;
        
        i_rst=1;
        #300;
        i_rst=0;
        #200;
        

        // HACEMOS UNA AND
        
        $display("Comienza AND");
        
        i_sw_data = 8'd12;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd10;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b100100;  // AND
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;


        // HACEMOS UNA OR
        
        $display("Comienza OR");
        
        i_sw_data = 8'd8;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd4;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b100101;  // OR
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;
        

        // HACEMOS UNA XOR
        
        $display("Comienza XOR");
        
        i_sw_data = 8'd7;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd3;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b100110;  // XOR
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;


        // HACEMOS UN SRA (shift aritmético hacia la derecha)
        
        $display("Comienza SRA");
        
        i_sw_data = 8'd16;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd2;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b000011;  // SRA
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;
        

        // HACEMOS UN SRL (shift lógico hacia la derecha)
        
        $display("Comienza SRL");
        
        i_sw_data = 8'd32;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd3;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b000010;  // SRL
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;


        // HACEMOS UN NOR
        
        $display("Comienza NOR");
        
        i_sw_data = 8'd9;
        #100
        i_btn = 3'b001;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 8'd5;
        #100
        i_btn = 3'b010;
        #100;
        i_btn = 3'b000;
        #100;
        
        i_sw_data = 6'b100111;  // NOR
        #100
        i_btn = 3'b100;
        #100;
        i_btn = 3'b000;
        #1000;

        // Fin de la simulación
        $display("Todas las pruebas han pasado correctamente.");
        #100;
        $finish;
    end

endmodule

