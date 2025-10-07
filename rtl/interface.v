module interface
#(
    parameter NB_DATA = 8,
    parameter NB_OP   = 6
)
(
    input  wire clk,                                    // Clock del sistema
    input  wire i_rst,                                  // Señal de reset
    input  wire [NB_DATA-1:0] i_rx_uart_data,           // Información recibida de UART RX
    input  wire i_rx_uart_done,                         // Flag de trama nueva      REVISAR COMO APAGARLO, SI LE MANDO SEÑAL DE INTERFACE A RX O COMO
    output wire [NB_DATA-1:0] o_data_a,                 // Valor 1 para la ALU
    output wire [NB_DATA-1:0] o_data_b,                 // Valor 2 para la ALU
    output wire [NB_DATA-1:0] o_op,                     // Operador para la ALU
    output wire [2:0]         o_leds,                   // Leds de estado
    output wire o_update_alu,       // SERIA EL VALID????
    
    input  wire [NB_DATA-1:0] i_result,                 // Resultado de la ALU
    input  wire               i_tx_done   ,             // Flag de transmisión lista
    output wire               o_new_data,               // Flag para avisarle al transmisor que hay un nuevo dato
    output wire [NB_DATA-1:0] o_tx_uart_data            // Información a transmitir por UART TX

);

    localparam [1:0]
        S_WAIT_A        = 2'b00,  // Esperando el primer operando
        S_WAIT_B        = 2'b01,  // Esperando el segundo operando
        S_WAIT_OP       = 2'b10,  // Esperando el operador        CONVIENE QUE SEA OPERANDO 1, 2 Y OP, O QUE SEA 1, OP Y 2? USAR LEDS PARA MOSTRAR ESTADO
        S_SHOW_RES      = 2'b11;  // Envía el resultado por uart tx
        
        //REVISAR
    localparam
        S_NEW_DATA      = 1'b0,   // Estado que cambia con un nuevo resultado de la ALU
        S_WAIT_RES      = 1'b1;   // Estado que espera a TX a que transmita
        
    reg [1:0] r_state, r_next_state;    // Estado actual y próximo de la recepción
    reg [1:0] t_state, t_next_state;    // Estado actual y próximo de la recepción

    reg signed [NB_DATA - 1 : 0] data_a;   // Registro para almacenar el primer operando
    reg signed [NB_DATA - 1 : 0] data_b;   // Registro para almacenar el segundo operando
    reg        [NB_OP   - 1 : 0] op    ;   // Registro para almacenar el operador
    reg signed [NB_DATA - 1 : 0] result;   // Registro para almacenar el resultado de la ALU
    
    reg f_show_rx;      // Flag para alternar el valid en la alu
    reg f_last_rx;      // Estado anterior de rx_done
    reg [2:0] leds;     // Estado de leds
    reg f_new_data;     // Flag para informarle al transmisor que hay un nuevo dato
    reg f_prev_tx_done; // Flag para almacenar el último estado de tx done


    always @(posedge clk or posedge i_rst) begin
        if (i_rst) begin
            r_state <= S_WAIT_A;
            r_next_state <= S_WAIT_A;
            t_state <= S_NEW_DATA;
            t_next_state <= S_NEW_DATA;
            
            data_a <= 0;        // {NB_DATA{1'b0}};
            data_b <= 0;        // {NB_DATA{1'b0}};
            op <= 0;            // {NB_OP{1'b0}};
            leds <= 0;
            result <= 0;        // {NB_DATA{1'b0}};
            
            f_show_rx <= 0;
            f_last_rx <= 0;
            f_new_data <= 0;
            f_prev_tx_done <= 0;
        end
        
        else begin
            if (i_rx_uart_done && !f_last_rx) begin     // Detecta flanco de subida de recepción
                r_state <= r_next_state;                // Permito el cambio de estado
            end
            
            f_last_rx <= i_rx_uart_done;    // Almacena el estado anterior de recepción
        end
        
    end
    
    
    
// Always para el RX

    always @(posedge clk) begin
        r_state <= r_next_state;
        
        case(r_state)
        
        // Esperando el primer operando
            S_WAIT_A: begin
                f_show_rx <= 0;     // Valid deshabilitado
                leds <= 3'b001;
                // Implementar métodos de verificación de valores correctos (en op mas que nada)
                if (i_rx_uart_done && !f_last_rx) begin     // Vino flanco de subida de recepción lista
                    data_a <= i_rx_uart_data;               // La info va al primer valor
                    r_next_state <= S_WAIT_B;                    // Paso al siguiente
                end
            end
           
        // Esperando el segundo operando
            S_WAIT_B: begin
                f_show_rx <= 0;     // Valid deshabilitado
                leds <= 3'b010;
                if (i_rx_uart_done && !f_last_rx) begin     // Vino flanco de subida de recepción lista
                    data_b <= i_rx_uart_data;               // La info va al primer valor
                    r_next_state <= S_WAIT_OP;                   // Paso al siguiente
                end
            end
            
        // Esperando la operación
            S_WAIT_OP: begin
                f_show_rx <= 0;     // Valid deshabilitado
                leds <= 3'b100;
                if (i_rx_uart_done && !f_last_rx) begin     // Vino flanco de subida de recepción lista
                    op <= i_rx_uart_data;
                    r_next_state <= S_SHOW_RES;
                end
            end
            
        // Cargo los valores a la ALU
            S_SHOW_RES: begin
                f_show_rx <= 1;     // Habilito el valid para que cargue el resultado
                leds <= 3'b000;
                
                // Aca tengo que ver si le doy un delay o algo
                
                r_next_state <= S_WAIT_A;   // Reinicio

            end
            
            
        endcase
    end
    
    
    
// Always para el TX

    always @(negedge clk) begin         // Distinto del posedge para darle un tiempo a la ALU a procesar
        t_state <= t_next_state;
        
        case(t_state)
            
        // Esperando un nuevo resultado
        
            S_NEW_DATA: begin
            
                // Reviso que f_show_rx esté en 1 para pasar al siguiente estado (o sea, se transmitieron los datos a la ALU)
                // Si está en 0, sigo esperando
                
                if (f_show_rx) begin
                    t_next_state <= S_WAIT_RES;
                end
                
                f_new_data <= 1'b0;         // Flag de new data en 0
                //FIN
                
            end
            
        // Transmitiendo el resultado
            
            S_WAIT_RES: begin
                
                // Reviso que TX esté listo para transmitir
                // Si está listo, copio lo que venga en i_result a result, y levanto la flag de nuevo dato para el TX
                // Me quedo esperando a que TX tenga un nuevo flanco de listo para transmitir
                
                // En esta parte podría ver de implementar un buffer por si tx no está listo
                
                // FIN
                
                if (i_tx_done) begin
                    result <= i_result;
                    f_new_data <= 1'b1;     // Flag de new data en 1, tx lee y comienza a copiar
                    f_prev_tx_done <= 1'b1; // Estado anterior fue 1, entonces aseguro que en el siguiente if copie el dato
                end
                
                else if (f_prev_tx_done) begin
                    f_new_data <= 0;        
                    f_prev_tx_done <= 0;
                    t_next_state <= S_NEW_DATA;
                end
                
            end
            
        endcase
    end

assign o_update_alu     = f_show_rx ? 1 : 0;    // Si está habilitado, manda a la ALU a operar
assign o_data_a         = data_a;       // Los datos serán constantes, el flag de valid manda a operar
assign o_data_b         = data_b;
assign o_op             = op;
assign o_leds           = leds;
assign o_tx_uart_data   = result;       // Resultado de la ALU se copia a la salida
assign o_new_data       = f_new_data;   // Flag a tx, informa nueva data

endmodule

