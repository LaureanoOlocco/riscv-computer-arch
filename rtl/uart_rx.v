module uart_rx
#(
    parameter NB_DATA        = 8    ,   // Cantidad de bits por paquete
        // (FLAGS DE RX A IMPLEMENTAR FUNCIONAMIENTO)
    parameter F_RX_PARITY    = 2'b00,   // 00 = sin paridad, 01 = paridad par, 10 = paridad impar
    parameter F_RX_STOP_BITS = 1'b1 ,   // 0 = sin bit de stop, 1 = con bit de stop
    parameter F_RX_SYNC      = 1'b1 ,   // 1 = asíncrono, 0 = síncrono
    
    parameter CLK_FREQ  = 100000000,    // Frecuencia del reloj del sistema 100 MHz
    parameter BAUD_RATE = 115200        // Baud Rate de operación
)
(                   // MMM REVISAR ESTE CLK
    input wire                clk         , // Clock del sistema (EL GENERADOR DEBE DETERMINAR SINCRONO O ASINCRONO)
    input wire                i_rst       , // Boton reinicio
    input wire                i_rx        , // Entrada para escuchar la transmisión
    //input wire                i_baud_tick , // Tick de baud para la sincronización
    output wire [NB_DATA-1:0] o_rx_data   , // Datos recibidos
    
        // REVISAR IMPLEMENTACION RX DONE, DEBERÍA SER 1 TODO EL TIEMPO Y CUANDO ESTÁ ESCUCHANDO BAJA A 0
    output wire               o_rx_done   , // Flag para indicar fin de la recepción
    output wire               o_valid       // Señal para que el generador de baudios comience
);

    localparam [1:0]            // Definición de estados
        S_RX_IDLE  = 2'b00,     // Espera bit de inicio
        S_RX_START = 2'b01,     // Detecta el inicio, inicia el baud rate
        S_RX_DATA  = 2'b10,     // Escucha los datos
        S_RX_STOP  = 2'b11;     // Valida la trama
        
    localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;
    
    reg  [1:0] r_state, r_next_state ;   // Estado actual y próximo
    reg  [7:0] r_shift_data          ;   // Registro para almacenar los datos
    reg  [3:0] r_bit_count           ;   // Bit actual de la transmisión
    reg [31:0] r_clock_count         ;   // Contador de clk para dar inicio al generador de baudios
    reg        r_baud_tick_last      ;   // Para almacenar el estado anterior de baud tick
    
    //wire       w_baud_tick           ;   // Cable para conectar con el generador    (FIJATE CON EL CLK DE ARRIBA, ESTE SERÍA EL CLK DE TICKS)
    wire       i_baud_tick;
        // Registros temporales para las salidas
    reg [NB_DATA-1:0] t_rx_data ;
    reg               f_rx_done ;
    reg               f_valid   ;
    
    
    
    // Instancia de baud_rate_gen
    baud_rate_gen #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    )
    rx_baud_rate_gen (
        .i_clk      (clk)       ,
        .i_valid    (f_valid)   ,
        .o_baud_tick(i_baud_tick)   // Tick generado
    );
    
    
    
    always @(posedge clk or posedge i_rst) begin
        if (i_rst) begin        // Estado de reinicio
            r_state <= S_RX_IDLE;
            r_next_state <= S_RX_IDLE;
            t_rx_data <= 0;
            r_bit_count <= 0;
            f_rx_done <= 0;
            r_clock_count <= 0;
            r_baud_tick_last <= 0;
            f_valid <= 0;
        end
        else begin
            r_baud_tick_last <= i_baud_tick;    // Almacena el estado anterior de baud tick
        
            if (i_baud_tick && !r_baud_tick_last) begin     // Detecta flanco de subida de baud tick
                r_state <= r_next_state;
            end
        end
    end
        

    
    // Bloque secuencial
    always @(posedge clk) begin
        r_state <= r_next_state;
        
        // Máquina de estados
        
        case (r_state)
        
    // IDLE: espero el bit de inicio
            
            S_RX_IDLE: begin
                if (i_rx == 0) begin      // Si vino un 0 arranco
                    r_next_state <= S_RX_START;
                    r_clock_count <= 0;
                    f_valid <= 0;
                    
                    f_rx_done <= 0;     // Revisar si está bien dentro del if o fuera, o si necesita delay
                    
                end
            end
            
    // START: Configuro para empezar a escuchar
            
            S_RX_START: begin
                if (i_rx == 0) begin    // Si la entrada de escucha sigue en 0, comienzo (Revisar, puede ocasionar problemas)(creo que iba en el if de abajo, como un and)
                
                    if (r_clock_count == (DIVISOR - 1)/2) begin     // Espero hasta la mitad del bit de Start
                        r_next_state <= S_RX_DATA;
                        r_bit_count <= 0;         // Preparo el contador de bits
                        f_valid <= 1;       // Inicio el generador de ticks
                    end
                
                    else begin              // Si no llego a la mitad del bit de Start, acumulo
                        r_clock_count <= r_clock_count + 1;
                    end
                
                end 
                
                else begin          // Si la entrada de escucha es 1, hay algo mal, reinicio
                    r_next_state <= S_RX_IDLE;
                end
            end
            
    // DATA: Escucho la transmisión
            
            S_RX_DATA: begin
                f_valid <= 1;
                if (i_baud_tick && !r_baud_tick_last) begin // Solo actúa cuando llega un flanco de subida de baud tick
                    if (r_bit_count < NB_DATA) begin
                        r_shift_data[r_bit_count] <= i_rx;    // Recibe el bit de datos
                        r_bit_count <= r_bit_count + 1;
                    end
                    
                    else begin
                        r_next_state <= S_RX_STOP;        // Llenaron los NB_DATA (probablemente 8), entonces termino
                    end
                end
            end
            
    // STOP: Detecto el fin de la transmisión y reinicio
            
            S_RX_STOP: begin
                if (i_rx == 1) begin  // Se detecta bit de parada después de NB_DATA bits de datos (Y PARIDAD???)
                    f_rx_done <= 1;               // Aviso que hay un paquete nuevo
                    t_rx_data <= r_shift_data;  // Este es el paquete
                    f_valid <= 0;               // Ahorro energía (Apago el generador de ticks)
                    r_bit_count <= 0;
                    r_next_state <= S_RX_IDLE;    // Vuelve a IDLE
                end
                
                else begin      // En caso de que llegue otra cosa que no sea bit de parada, error (IMPLEMENTAR BIT DE PARIDAD)
                    // Ignoro el paquete y reinicio (ESTÁ BIEN???)
                    f_rx_done <= 0;               // Info ta mal así que nada para leer
                    t_rx_data <= {NB_DATA{1'b0}};    // Vacío el buffer 
                    f_valid <= 0;               // Apago el generador
                    r_bit_count <= 0;
                    r_next_state <= S_RX_IDLE;    // Vuelve a IDLE
                end
            end
            
        endcase
        
    end
    
    // Asignaciones para las salidas
    assign o_rx_data = t_rx_data;
    assign o_rx_done = f_rx_done;
    assign o_valid   = f_valid  ;
    
endmodule

