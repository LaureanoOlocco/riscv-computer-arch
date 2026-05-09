module top_wrapper (
    output                                              wire  o_uart_tx         ,
    input                                               wire  i_uart_rx         ,
    input                                               wire  i_rst             ,
    input                                               wire  clock             
);

    wire                                                      clk_75            ;
    wire                                                      locked            ;

    clk_wiz_0 clk_inst (
        .clk_in1                        (clock                                ),
        .clk_out1                       (clk_75                               ),
        .locked                         (locked                               ),
        .reset                          (1'b0                                 )     
    )                                                                          ;

    // Reset active by high
    // Include the PLL lock status to ensure the system is held in reset until the clock is stable
    wire rst_combined = i_rst | ~locked                                         ;

    wire                                         sync_data                      ;
    wire                                         sync_rst                       ;

    // Synchronize the asynchronous UART RX signal and the reset signal to the system clock domain
    synchronizer
    u_synchronizer_data
    (
        .o_data                 (sync_data                                     ),  // synchronized output data
        .i_data                 (i_uart_rx                                     ),  // data to be synchronized    .
        .clock                  (clk_75                                        )   // system clock
    )                                                                           ;

    // Synchronize the reset signal, which is active high, to ensure it is properly aligned with the system clock
    synchronizer
    u_synchronizer_rst
    (
        .o_data                 (sync_rst                                      ),  // synchronized output data
        .i_data                 (rst_combined                                  ),  // data to be synchronized    .
        .clock                  (clk_75                                        )   // system clock
    )                                                                           ;

    top u_top (
        .o_uart_tx              (o_uart_tx                                     ),
        .i_uart_rx              (sync_data                                     ),
        .i_en                   (locked                                        ),
        .i_rst                  (sync_rst                                      ),
        .clock                  (clk_75                                        )
    )                                                                           ;  

endmodule