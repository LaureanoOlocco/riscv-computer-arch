`timescale 1ns/1ps

module uart_rx_tb;

    // Parámetros
    localparam CLK_FREQ = 100000000; // 100 MHz clock
    localparam BAUD_RATE = 115200;   // 115200 baud rate
    localparam NB_DATA = 8;          // 8 bits de datos

    // Señales
    reg clk;
    reg i_rst;
    reg i_rx;
    wire baud_tick;
    wire [NB_DATA-1:0] rx_data_out;
    wire rx_done;
    wire o_valid;

    // Instancia del módulo baud_rate_gen
    baud_rate_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_gen_inst (
        .i_clk(clk),
        .i_valid(o_valid),  // Comienza a generar ticks cuando o_valid es 1
        .o_baud_tick(baud_tick)
    );

    // Instancia del módulo uart_rx
    uart_rx #(
        .NB_DATA(NB_DATA),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .i_rst(i_rst),
        .i_rx(i_rx),
        .i_baud_tick(baud_tick),
        .o_rx_data(rx_data_out),
        .o_rx_done(rx_done),
        .o_valid(o_valid)
    );

    // Reloj de sistema (clock) de 100 MHz
    always #5 clk = ~clk;  // Periodo de 10ns -> 100 MHz

    // Estímulos del testbench
    initial begin
        // Inicialización de señales
        clk = 0;
        i_rst = 1;
        i_rx = 1;           // Línea de RX inicialmente en reposo (alta)
        #100;
        
        // Desactivar reset
        i_rst = 0;
        
        #1000;
        

        // Enviar trama UART con 8 bits de datos (0x55 = 01010101)
        // Start bit (0), data bits (0x55), stop bit (1)
        send_uart_byte(8'h55);  // Enviar el byte 0x55
        
        // Esperar a que el receptor UART procese el byte
        #20000; // Esperar tiempo suficiente para que el byte sea recibido
        
        // Verificar el resultado
        if (rx_data_out == 8'h55 && rx_done) begin
            $display("Test passed: byte 0x55 received correctly.");
        end else begin
            $display("Test failed: byte 0x55 not received correctly.");
        end

        // Finaliza la simulación
        $finish;
    end

    // Tarea para enviar una trama UART (start bit, data bits, stop bit)
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // Enviar el bit de inicio (start bit, 0)
            i_rx = 0;
            #(8680);  // Tiempo para un bit a 115200 baud rate (~8680ns por bit)

            // Enviar los 8 bits de datos (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                i_rx = data[i];
                #(8680);  // Tiempo de un bit
            end

            // Enviar el bit de parada (stop bit, 1)
            i_rx = 1;
            #(8680);  // Tiempo de un bit
        end
    endtask

endmodule
