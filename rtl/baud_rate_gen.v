module baud_rate_gen
#(
    parameter CLK_FREQ  = 100000000,    // Frecuencia del reloj del sistema 100 MHz
    parameter BAUD_RATE = 115200        // Baud Rate de operación
)
(
    input  wire i_clk     , // Clock del sistema
    input  wire i_valid   , // Le da comienzo a generar ticks
    output wire o_baud_tick // Tick para los módulos
);

    // Cada cierta cantidad de clk, un tick
    localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;
    
    reg [31:0] r_count          ;   // Contador de clk para un tick
    reg        r_delay_for_tick ;   // Delay para un tick, para que llegue a operar bien la lógica
    reg        r_tick           ;   // Registro para modificar los ticks
    
    always @(posedge i_clk) begin // or posedge i_valid) begin
    
            // Habilitado a generar ticks
        if (i_valid) begin
            
                // Si la cantidad de clk alcanzó al divisor, genero el tick
            if (r_count == DIVISOR -1) begin
                r_count <= 0;
                r_tick <= 1;     // Probar si alcanzará con un solo ciclo de reloj para que los otros módulos actúen
                r_delay_for_tick <= 4'b1111;
            end
            
                // Si clk no alcanza al divisor, sumo
            else begin
                r_count <= r_count + 1;
                
                if (r_delay_for_tick == 0) begin          // Si el delay llegó a 0, bajo el tick
                    r_tick <= 0;
                end
                
                else begin
                    r_delay_for_tick <= r_delay_for_tick - 1;   // Decremento el delay
                end
            end
            
        end
        
            // Estado de reset, todo en 0
        else begin
            r_count <= 0;
            r_tick <= 0;
        end
    end
    
    assign o_baud_tick = r_tick;
    
endmodule

