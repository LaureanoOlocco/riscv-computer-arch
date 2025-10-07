module uart_tx
#(
    parameter NB_DATA        = 8    ,   // Cantidad de bits por paquete
        // (FLAGS DE RX A IMPLEMENTAR FUNCIONAMIENTO)
    parameter F_RX_PARITY    = 2'b00,   // 00 = sin paridad, 01 = paridad par, 10 = paridad impar
    parameter F_RX_STOP_BITS = 1'b1 ,   // 0 = sin bit de stop, 1 = con bit de stop
    parameter F_RX_SYNC      = 1'b1 ,   // 1 = asíncrono, 0 = síncrono
    
    parameter CLK_FREQ  = 100000000,    // Frecuencia del reloj del sistema 100 MHz
    parameter BAUD_RATE = 115200        // Baud Rate de operación
)
(
    input  wire               clk         , // Clock del sistema (EL GENERADOR DEBE DETERMINAR SINCRONO O ASINCRONO)
    input  wire               i_rst       , // Boton reinicio
    input  wire [NB_DATA-1:0] i_data      , // Datos a transmitir
    input  wire               i_new_data  , // Flag para que cargue el nuevo dato y comience
    output wire               o_tx        , // Salida para transmitir
    output wire               o_tx_done   , // Bit de transmisión finalizada
    output wire               o_valid       // Señal para que el generador de baudios comience y para que la interface espere

);

    localparam                    // Definición de estados
        S_TX_IDLE     = 1'b0,     // Espera bit de inicio
        S_TX_TRANSMIT = 1'b1;     // Detecta el inicio, inicia el baud rate
    
    //localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;

    reg  [1:0] r_state, r_next_state ;   // Estado actual y próximo
    reg  [7:0] r_shift_data          ;   // Registro para almacenar los datos
    reg  [3:0] r_bit_count           ;   // Bit actual de la transmisión
    reg [31:0] r_clock_count         ;   // Contador de clk para dar inicio al generador de baudios
    reg        r_baud_tick_last      ;   // Para almacenar el estado anterior de baud tick
    reg        r_tx                  ;   // Registro para copiar el valor de la salida
    
    //wire       w_baud_tick           ;   // Cable para conectar con el generador    (FIJATE CON EL CLK DE ARRIBA, ESTE SERÍA EL CLK DE TICKS)
    wire       i_baud_tick;
    
    reg               f_tx_done ;       // Flag para avisar a la interface que terminó de transmitir
    reg               f_valid   ;       // Flag para la salida de valid del baud rate generator
    
    // Instancia de baud_rate_gen
    baud_rate_gen #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    )
    tx_baud_rate_gen (
        .i_clk      (clk)       ,
        .i_valid    (f_valid)   ,
        .o_baud_tick(i_baud_tick)   // Tick generado
    );
    
    always @(posedge clk or posedge i_rst) begin
        
        if (i_rst) begin
        
            r_state     <= S_TX_IDLE;    // Estado inicial es IDLE
            r_next_state     <= S_TX_IDLE;
            r_bit_count <= 0;            // La cuenta de la posición va en 0
            f_tx_done   <= 1'b1;         // Está listo para recibir (el reset se aplica a todo el sistema, es indistinto el valor)
            r_tx        <= 1'b1;         // Línea TX en 1 por defecto
            f_valid     <= 1'b0;         // Baud rate generator desactivado
            r_shift_data  <= 0;
            
        end 
        
        else begin
            r_baud_tick_last <= i_baud_tick;    // Almacena el estado anterior de baud tick
        
            if (i_baud_tick && !r_baud_tick_last) begin     // Detecta flanco de subida de baud tick
                r_state <= r_next_state;
            end                             // Revisar esto ya que usamos clk y ticks, creo que el if no haría falta
        end
        
    end
    
    
    
    always @(posedge clk) begin
        r_state <= r_next_state;
        
        case (r_state)

    // IDLE: Espero un nuevo dato para comenzar la transmisión

            S_TX_IDLE: begin
            
                if(i_new_data) begin    // Nuevo dato para mostrar
                
                    //f_tx_done <= 1'b0;    // Aviso a la interface que estoy transmitiendo
                    //r_tx      <= 1'b0;    // El valor de tx pasa a 0
                    f_valid   <= 1'b1;    // Comienza el baud rate
                    r_shift_data <= i_data; // Copio la info al registro
                    
                    if(i_baud_tick && !r_baud_tick_last) begin  // Si vino el flanco de tick
                        
                        //f_tx_done <= 1'b0;    // Aviso a la interface que estoy transmitiendo
                        
                        r_tx      <= 1'b0;    // El valor de tx pasa a 0
                        
                        // TOCAR ESTO PARA CAMBIAR EL ORDEN
                        
                        //r_bit_count  <= 0;              // El contador de posición se reinicia 
                        r_bit_count <= NB_DATA;
                        
                        
                        r_next_state <= S_TX_TRANSMIT;  // Comienzo a transmitir
                        
                    end
                    
                end
                
                else begin          // Si no hay nuevo dato, mantengo la salida en 1
                
                    r_tx         <= 1'b1;   // Salida en 1
                    f_tx_done    <= 1'b1;   // Flag de preparado en 1
                    f_valid      <= 1'b0;   // Desactivo el generador de baud rate
                    
                end
            end
            
    // TRANSMIT: Estado para la transmisión de datos
    
            S_TX_TRANSMIT: begin
                
                f_valid      <= 1'b1;   // Valid se mantiene en 1 para generar ticks
                f_tx_done    <= 1'b0;   // Flag de preparado en 0, está transmitiendo
                
                if(i_baud_tick && !r_baud_tick_last) begin  // Si vino el flanco de tick
                
                // REVISAR SI TRANSMITE BIEN EL ÚLTIMO BIT (tiene que ver con el bit de stop)
                // REVISAR EL ORDEN MSB A LSB
                
                    //if (r_bit_count < NB_DATA - 1) begin        // Comienzo a leer el registro     
                    if (r_bit_count > 0) begin         
                        r_tx <= r_shift_data[((NB_DATA - 1) - (r_bit_count - 1))];  // Copio bit a bit los datos a la salida
                        r_bit_count <= r_bit_count - 1;     // Preparo el siguiente
                    end
                    
                    else begin
                    
                        r_next_state <= S_TX_IDLE;        // Termino de transmitir, vuelvo al inicio
                    
                    end
                end
                
            end
            
        endcase
    end
    
    assign o_tx_done = f_tx_done;
    assign o_valid   = f_valid  ;
    assign o_tx      = r_tx;
    
endmodule

