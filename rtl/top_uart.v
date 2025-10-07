module top_uart
#(
    parameter NB_DATA   = 8,            // Bits de datos de uart y cant. bits para operandos
    parameter NB_OP     = 6,            // Bits para una operación
    
    parameter CLK_FREQ  = 100000000,    // Frecuencia del reloj del sistema 100 MHz
    parameter BAUD_RATE = 115200   ,    // Baud rate establecido
        // (FLAGS DE RX A IMPLEMENTAR FUNCIONAMIENTO)
    parameter F_RX_PARITY    = 2'b00,   // 00 = sin paridad, 01 = paridad par, 10 = paridad impar
    parameter F_RX_STOP_BITS = 1'b1 ,   // 0 = sin bit de stop, 1 = con bit de stop
    parameter F_RX_SYNC      = 1'b1     // 1 = asíncrono, 0 = síncrono
)
(
    input  wire       clk      ,    // Clock interno
    input  wire       i_rst    ,    // Entrada de reset
    input  wire       i_uart_rx,    // Conexión de entrada de datos uart
    output wire       o_uart_tx,    // Conexión de salida de datos uart
    output wire [2:0] o_uart_led    // Leds de comunicación uart    (AGREGO DE ESTADOS? PARA INTERFAZ)
);


    // ACÁ CREAR LOS REGISTROS PARA INTERCONECTAR LOS MÓDULOS
    // PARA LOS REG QUE INTERCONECTAN, USAR w_... para un wire
    
    wire [NB_DATA-1:0] w_data_a;  // Wire para conectar data a de interface a entrada de alu
    wire [NB_DATA-1:0] w_data_b;  // Wire para conectar data b de interface a entrada de alu
    wire [NB_OP  -1:0] w_op;      // Wire para conectar op de interface a alu
    wire [NB_DATA-1:0] w_rx_data; // Wire para conectar info de rx a la interface
    wire               w_rx_done; // Wire para la flag de recepción lista
    wire [NB_DATA-1:0] w_tx_data; // Wire para conectar info de la interface a tx
    wire               w_tx_done; // Wire para la flag de transmisión lista 
    wire [NB_DATA-1:0] w_result;  // Conecta salida de la ALU con entrada de la interface
    wire               w_new_data;// Informa a TX que la interface tiene un nuevo valor


    // Instancia RX

    uart_rx #(
        .NB_DATA        (NB_DATA)       ,
        //.NB_OP          (NB_OP)         ,
        .F_RX_PARITY    (F_RX_PARITY)   ,
        .F_RX_STOP_BITS (F_RX_STOP_BITS),
        .F_RX_SYNC      (F_RX_SYNC)
    )
    rx_instance (
        .clk       (clk)      ,
        .i_rst     (i_rst)    ,
        .i_rx      (i_uart_rx),     // Pin de entrada de recepción uart
        .o_rx_data (w_rx_data),
        .o_rx_done (w_rx_done)
    );
    

    // Instancia TX
    
    uart_tx #(
        .NB_DATA        (NB_DATA)       ,
        //.NB_OP          (NB_OP)         ,
        .F_RX_PARITY    (F_RX_PARITY)   ,
        .F_RX_STOP_BITS (F_RX_STOP_BITS),
        .F_RX_SYNC      (F_RX_SYNC)
    )
    tx_instance (
        .clk            (clk)      ,
        .i_rst          (i_rst)    ,
        .o_tx           (o_uart_tx),
        .o_tx_done      (w_tx_done),
        .i_data         (w_tx_data),
        .i_new_data     (w_new_data)
    );

    // Instancia Interface

    interface #(
        .NB_DATA(NB_DATA),
        .NB_OP  (NB_OP)
    )
    interface_instance (
        .clk            (clk)      ,
        .i_rst          (i_rst)    ,
        .i_rx_uart_data (w_rx_data),
        .i_rx_uart_done (w_rx_done),
        .o_leds         (o_uart_led),
        .o_update_alu   (w_valid)  ,
        .o_data_a       (w_data_a) ,
        .o_data_b       (w_data_b) ,
        .o_op           (w_op),
        .o_tx_uart_data (w_tx_data),
        .i_result       (w_result),
        .o_new_data     (w_new_data),
        .i_tx_done      (w_tx_done)
    );

    // Instancia ALU
    
    ALU #(
        .NB_DATA(NB_DATA),
        .NB_OP  (NB_OP)
    )
    alu_instance (
        .clk      (clk),
        .i_rst    (i_rst),
        .i_valid  (w_valid)  ,          // CREAR VALID ENTRE INTERFAZ Y ALU
        .i_data_a (w_data_a) ,          // SALIDA DE INTERFAZ DE 8 BITS, ENTRADA DE ALU DE 8 BITS
        .i_data_b (w_data_b) ,          // SALIDA DE INTERFAZ DE 8 BITS, ENTRADA DE ALU DE 8 BITS
        .i_op     (w_op)     ,          // Operación a realizar, recibida también por UART
        .o_result (w_result)            // Resultado de la ALU, salida de 8 bits, se conecta a una entrada en la interface
    );

    // Instancia Baud Rate Generator
    
//    baud_rate_gen #(
//        .CLK_FREQ(CLK_FREQ),
//        .BAUD_RATE(BAUD_RATE)
//    )
//    baud_rate_instance (
//        
//    );

    
        
endmodule

