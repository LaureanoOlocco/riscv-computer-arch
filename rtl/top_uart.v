module top_uart
#(
    parameter                                                                   NB_OP_CODE      = 6                     ,                                  
    parameter                                                                   NB_DATA         = 8                     ,       
    parameter                                                                   SM_TICK         = 16                    ,                                             
    parameter                                                                   NB_ADDRESS      = 4                     ,           
    parameter                                                                   NB_COUNT        = 3                     ,        
    parameter                                                                   NB_REG          = 32                    ,    
    parameter                                                                   BAUD_RATE       = 115_200               ,
    parameter                                                                   CLK_FREQ        = 100_000_000           ,
    parameter                                                                   NB_UART_OUT     = 2                     ,
    parameter                                                                   NB_COUNTER      = 9

) 
(
    output wire [NB_UART_OUT                                           - 1 : 0] o_uart                                  ,
    output wire                                                                 i_tx                                    ,
    input  wire                                                                 i_rx                                    ,
    input  wire                                                                 i_rst                                   ,
    input  wire                                                                 clock
)                                                                                                                       ;

    wire                                                                        counter_tick_to_uart                    ;
    wire                                                                        uart_rx_done_to_fifo_wr                 ;
    wire                                                                        fifo_rx_empty_to_interface              ;
    wire                                                                        fifo_tx_empty_to_interface              ; // ← NUEVO
    wire                                                                        interface_to_fifo_rx_rd                 ;
    wire                                                                        interface_to_fifo_tx_wr                 ;
    wire                                                                        interface_to_fifo_tx_rd                 ;
    wire                                                                        interface_to_tx_start                   ;
    wire                                                                        uart_tx_done_to_interface               ;
    wire        [NB_REG                                                - 1 : 0] interface_to_alu_data_a                 ;
    wire        [NB_REG                                                - 1 : 0] interface_to_alu_data_b                 ;
    wire        [NB_REG                                                - 1 : 0] alu_out_to_interface                    ;    
    wire        [NB_DATA                                               - 1 : 0] interface_to_fifo_tx_data               ;
    wire        [NB_DATA                                               - 1 : 0] fifo_rx_data_to_interface               ;
    wire        [NB_DATA                                               - 1 : 0] fifo_tx_data_to_uart_tx                 ;
    wire        [NB_DATA                                               - 1 : 0] uart_rx_data_to_fifo_data               ;
    wire        [NB_OP_CODE                                            - 1 : 0] interface_to_alu_op_code                ;

    baud_rate_gen #(
        .NB_COUNTER (NB_COUNTER                                                                                         ),
        .CLK_FREQ   (CLK_FREQ                                                                                           ),
        .BAUD_RATE  (BAUD_RATE                                                                                          ),
        .SM_TICK    (SM_TICK                                                                                            )
    ) 
    u_baud_rate_gen 
    (
        .o_counter  (                                                                                                   ),
        .o_tick     (counter_tick_to_uart                                                                               ),
        .i_rst      (i_rst                                                                                              ),
        .clock      (clock                                                                                              )
    );

    alu#(
        .NB_DATA        (NB_REG                                                                                         ),
        .NB_OP_CODE     (NB_OP_CODE                                                                                     )
    )
    u_alu
    (
        .o_result       (alu_out_to_interface                                                                           ),  
        .i_data_a       (interface_to_alu_data_a                                                                        ),  
        .i_data_b       (interface_to_alu_data_b                                                                        ),  
        .i_op_code      (interface_to_alu_op_code                                                                       )   
    )                                                                                                                   ;
    
    interface_uart#(
        .NB_DATA        (NB_DATA                                                                                        ),
        .NB_REG         (NB_REG                                                                                         ),
        .NB_OP_CODE     (NB_OP_CODE                                                                                     ),
        .NB_COUNT       (NB_COUNT                                                                                       )
    )
    u_interface_uart
    (
        .o_tx_start     (interface_to_tx_start                                                                          ),  
        .o_read         (interface_to_fifo_rx_rd                                                                        ),  
        .o_write        (interface_to_fifo_tx_wr                                                                        ),
        .o_fifo_tx_rd   (interface_to_fifo_tx_rd                                                                        ),
        .o_alu_out      (interface_to_fifo_tx_data                                                                      ),  
        .o_alu_data_a   (interface_to_alu_data_a                                                                        ),  
        .o_alu_data_b   (interface_to_alu_data_b                                                                        ),  
        .o_alu_op_code  (interface_to_alu_op_code                                                                       ),  
        .i_alu_out      (alu_out_to_interface                                                                           ),  
        .i_rx_data      (fifo_rx_data_to_interface                                                                      ),  
        .i_rx_done      (uart_rx_done_to_fifo_wr                                                                        ),  
        .i_rx_empty     (fifo_rx_empty_to_interface                                                                     ),
        .i_fifo_tx_empty(fifo_tx_empty_to_interface                                                                     ), // ← NUEVO
        .i_tx_done      (uart_tx_done_to_interface                                                                      ),  
        .i_rst          (i_rst                                                                                          ),  
        .clock          (clock                                                                                          )   
    )                                                                                                                    ;

//----------------------------------------- FIFO INSTANCES --------------------------------------------//

    fifo#(
        .NB_DATA        (NB_DATA                                                                                        ),
        .NB_ADDRESS     (NB_ADDRESS                                                                                     )
    )
    u_fifo_rx
    (
        .o_data         (fifo_rx_data_to_interface                                                                      ),  
        .o_empty_flag   (fifo_rx_empty_to_interface                                                                     ),  
        .o_full_flag    (                                                                                               ),  
        .i_rd           (interface_to_fifo_rx_rd                                                                        ),  
        .i_wr           (uart_rx_done_to_fifo_wr                                                                        ),  
        .i_data         (uart_rx_data_to_fifo_data                                                                      ),  
        .i_rst          (i_rst                                                                                          ),  
        .clock          (clock                                                                                          )   
    )                                                                                                                    ;
        
    fifo#(
        .NB_DATA        (NB_DATA                                                                                        ),
        .NB_ADDRESS     (NB_ADDRESS                                                                                     )
    )   
    u_fifo_tx    
    (   
        .o_data         (fifo_tx_data_to_uart_tx                                                                        ),  
        .o_empty_flag   (fifo_tx_empty_to_interface                                                                     ), 
        .o_full_flag    (                                                                                               ), 
        .i_rd           (interface_to_fifo_tx_rd                                                                        ),
        .i_wr           (interface_to_fifo_tx_wr                                                                        ), 
        .i_data         (interface_to_fifo_tx_data                                                                      ),
        .i_rst          (i_rst                                                                                          ),  
        .clock          (clock                                                                                          )   
    )                                                                                                                   ;    

    uart_rx#( 
        .NB_DATA        (NB_DATA                                                                                        ),
        .SM_TICK        (SM_TICK                                                                                        )
    )
    u_uart_rx
    (
        .o_data         (uart_rx_data_to_fifo_data                                                                      ),  
        .o_rx_done_tick (uart_rx_done_to_fifo_wr                                                                        ),  
        .i_rx           (i_rx                                                                                           ),  
        .i_s_tick       (counter_tick_to_uart                                                                           ),  
        .i_rst          (i_rst                                                                                          ),  
        .clock          (clock                                                                                          )     
    )                                                                                                                   ;

    uart_tx#(
        .NB_DATA        (NB_DATA                                                                                        ),
        .SM_TICK        (SM_TICK                                                                                        )
    )                                                       
    u_uart_tx                                                        
    (                                                       
        .o_tx           (i_tx                                                                                           ),  
        .o_tx_done_tick (uart_tx_done_to_interface                                                                      ),  
        .i_data         (fifo_tx_data_to_uart_tx                                                                        ),  
        .i_tx_start     (interface_to_tx_start                                                                          ),        
        .i_s_tick       (counter_tick_to_uart                                                                           ),  
        .i_rst          (i_rst                                                                                          ),  
        .clock          (clock                                                                                          )   
    )                                                                                                                   ;				
    
    assign o_uart[0] = i_rx                                                                                             ;
    assign o_uart[1] = i_tx                                                                                             ;
    

endmodule