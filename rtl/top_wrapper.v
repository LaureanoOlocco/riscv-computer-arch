module top_wrapper
#(
)
(
    // ------------------------------------------------------------------ //
    // Physical UART pins
    // ------------------------------------------------------------------ //
    output wire  o_uart_tx     ,  //! UART TX (to host)
    input  wire  i_uart_rx     ,  //! UART RX (from host)

    // ------------------------------------------------------------------ //
    // System
    // ------------------------------------------------------------------ //
    input  wire  i_rst         ,  //! Synchronous reset (active high)
    input  wire  clock               //! System clock
);
  
    wire clk_75                                                             ;
    wire locked                                                             ;

    clk_wiz_0 clk_inst (
        .clk_in1    (clock      ),  // input clock   
        .clk_out1   (clk_75     ),  // output clock  
        .locked     (locked     ),
        .reset      (i_rst      )  
    )                           ;

    wire sync_data                                                          ;
    wire sync_rst                                                           ;

    synchronizer
    u_synchronizer_data
    (
        .o_data     (sync_data)                                             ,  // synchronized output data
        .i_data     (i_uart_rx)                                             ,  // data to be synchronized    .
        .clock      (clk_75   )                                                //! System clock
    );

    synchronizer
    u_synchronizer_rst
    (
        .o_data     (sync_rst)                                              ,  // synchronized output data
        .i_data     (i_rst   )                                              ,  // data to be synchronized    .
        .clock      (clk_75  )                                                   //! System clock
    );

    top
    u_top (
        .o_uart_tx     (o_uart_tx)                                             ,  //! UART TX (to host)
        .i_uart_rx     (sync_data)                                             ,  //! UART RX (from host)
        .i_en          (locked   )                                             ,  //! External enable (e.g., tied to PLL locked signal)
        .i_rst         (sync_rst )                                             ,  //! Synchronous reset (active high)
        .clock         (clk_75   )                                                //! System clock
    );
 


endmodule