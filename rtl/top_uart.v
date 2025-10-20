module top
#(
    parameter NB_COUNTER      = 9                          ,       
    parameter NB_OP_CODE      = 6                          ,                                  
    parameter NB_DATA         = 8                          ,       
    parameter NB_TICK_CNT     = 4                          ,                                             
    parameter NB_ADDRESS      = 4                          ,           
    parameter NB_COUNT        = 3                          ,        
    parameter NB_REG          = 32                         ,    
    parameter BAUD_RATE       = 115_200                    ,
    parameter CLK_FREQ        = 100_000_000 

) 
(
    output [1 : 0] o_uart                                  ,
    output         i_tx                                    ,
    input          i_rx                                    ,
    input          i_rst                                   ,
    input          clk
)                                                          ;

    wire                        counter_tick_to_uart       ;
    wire                        uart_rx_done_to_fifo_wr    ;
    wire                        fifo_rx_empty_to_interface ;
    wire                        interface_to_fifo_rx_rd    ;
    wire                        interface_to_fifo_tx_wr    ;
    wire                        interface_to_tx_start      ;
    wire                        uart_tx_done_to_interface  ;
    wire [NB_REG       - 1 : 0] interface_to_alu_a         ;
    wire [NB_REG       - 1 : 0] interface_to_alu_b         ;
    wire [NB_REG       - 1 : 0] alu_out_to_interface       ;    
    wire [NB_DATA      - 1 : 0] interface_to_fifo_tx_wdata ;
    wire [NB_DATA      - 1 : 0] fifo_rx_rdata_to_interface ;
    wire [NB_DATA      - 1 : 0] fifo_tx_rdata_to_uart_tx   ;
    wire [NB_DATA      - 1 : 0] uart_rx_data_to_fifo_wdata ;
    wire [NB_OP_CODE   - 1 : 0] interface_to_alu_op        ;

    assign o_uart[0] = i_rx                                ;
    assign o_uart[1] = i_tx                                ;

    baud_rate_gen
    #(
        .NB_COUNTER (NB_COUNTER                            )
        
    )
    baud_rate_gen_unit
    (
        .o_counter (                                       ),  
        .o_tick    (counter_tick_to_uart                   ),  
        .i_rst     (i_rst                                  ),  
        .clk       (clk                                    )   
    )                                                      ;

    alu
    #(
        .NB_REG      (NB_REG                               ),
        .NB_OP_CODE  (NB_OP_CODE                           )
    )
    alu_unit
    (
        .o_out (alu_out_to_interface                       ),  
        .i_a   (interface_to_alu_a                         ),  
        .i_b   (interface_to_alu_b                         ),  
        .i_op  (interface_to_alu_op                        )   
    )                                                      ;
    
    interface
    #(
        .NB_DATA    (NB_DATA                               ),
        .NB_REG     (NB_REG                                ),
        .NB_OP_CODE (NB_OP_CODE                            ),
        .NB_COUNT   (NB_COUNT                              )
    )

    interface_unit
    (
        .o_tx_start (interface_to_tx_start                 ),  
        .o_rd       (interface_to_fifo_rx_rd               ),  
        .o_wr       (interface_to_fifo_tx_wr               ),  
        .o_alu_out  (interface_to_fifo_tx_wdata            ),  
        .o_alu_a    (interface_to_alu_a                    ),  
        .o_alu_b    (interface_to_alu_b                    ),  
        .o_alu_op   (interface_to_alu_op                   ),  
        .i_alu_out  (alu_out_to_interface                  ),  
        .i_rx_data  (fifo_rx_rdata_to_interface            ),  
        .i_rx_done  (uart_rx_done_to_fifo_wr               ),  
        .i_rx_empty (fifo_rx_empty_to_interface            ),  
        .i_tx_done  (uart_tx_done_to_interface             ),  
        .i_rst      (i_rst                                 ),  
        .clk        (clk                                   )   
    )                                                      ;

//----------------------------------------- FIFO INSTANCES --------------------------------------------//

    fifo
    #(
        .NB_DATA    (NB_DATA                               ),
        .NB_ADDRESS (NB_ADDRESS                            )
    )
    fifo_rx_unit
    (
        .o_rdata (fifo_rx_rdata_to_interface               ),  
        .o_empty (fifo_rx_empty_to_interface               ),  
        .o_full  (                                         ),  
        .i_rd    (interface_to_fifo_rx_rd                  ),  
        .i_wr    (uart_rx_done_to_fifo_wr                  ),  
        .i_wdata (uart_rx_data_to_fifo_wdata               ),  
        .i_rst   (i_rst                                    ),  
        .clk     (clk                                      )   
    )                                                      ;
        
    fifo
    #(
        .NB_DATA    (NB_DATA                               ),
        .NB_ADDRESS (NB_ADDRESS                            )
    )
    fifo_tx_unit
    (
        .o_rdata (fifo_tx_rdata_to_uart_tx                 ),  
        .o_empty (fifo_tx_empty_to_led                     ), 
        .o_full  (                                         ), 
        .i_rd    (interface_to_tx_start                    ), 
        .i_wr    (interface_to_fifo_tx_wr                  ), 
        .i_wdata (interface_to_fifo_tx_wdata               ),
        .i_rst   (i_rst                                    ),  
        .clk     (clk                                      )   
    )                                                      ;    

//----------------------------------------- UART INSTANCES --------------------------------------------//

    uart_rx
    #( 
        .NB_DATA     (NB_DATA                              ),
        .NB_TICK_CNT (NB_TICK_CNT                          )
    )
    uart_rx_unit
    (
        .o_data    (uart_rx_data_to_fifo_wdata             ),  
        .o_rx_done (uart_rx_done_to_fifo_wr                ),  
        .i_rx      (i_rx                                   ),  
        .i_stick   (counter_tick_to_uart                   ),  
        .i_rst     (i_rst                                  ),  
        .clk       (clk                                    )     
    )                                                      ;

    uart_tx
    # (
        .NB_DATA     (NB_DATA                              ),
        .NB_TICK_CNT (NB_TICK_CNT                          )
    )
    uart_tx_unit
    (  
        .o_tx      (i_tx                                   ),  
        .o_tx_done (uart_tx_done_to_interface              ),  
        .i_data    (fifo_tx_rdata_to_uart_tx               ),  
        .i_tx_start(interface_to_tx_start                  ),        
        .i_stick   (counter_tick_to_uart                   ),  
        .i_rst     (i_rst                                  ),  
        .clk       (clk                                    )   
    )                                                      ;

endmodule