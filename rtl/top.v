//! @title TOP
//! @file top.v
//! @author Laureano Olocco - Sofia Avalos
//! @date 2-2025
//! @version 1.0
//! @brief FPGA top-level module.
//!        Instantiates the CPU subsystem (cpu_core + debug_unit) and the
//!        UART physical layer (baud_rate_gen, uart_rx, uart_tx, FIFOs).
//!
//!  Signal flow:
//!    UART RX pin → uart_rx → RX FIFO → cpu_subsystem (DU)
//!    cpu_subsystem (DU) → TX FIFO → uart_tx → UART TX pin
//!
//!  The debug_client.py host tool communicates over UART with the debug unit
//!  to load firmware into IMEM, step/run the CPU, and inspect registers/memory.

module top
#(
    // ------------------------------------------------------------------ //
    // System clock and UART parameters
    // ------------------------------------------------------------------ //
    parameter CLK_FREQ          = 75_000_000 ,  //! FPGA clock frequency (Hz)
    parameter BAUD_RATE         = 115_200    ,  //! UART baud rate (bps)
    parameter NB_BAUD_COUNTER   = 9          ,  //! Baud rate generator counter width
    parameter SM_TICK           = 16         ,  //! Oversampling ticks per bit

    // ------------------------------------------------------------------ //
    // CPU / debug unit parameters
    // ------------------------------------------------------------------ //
    parameter NB_DATA           = 32         ,  //! Data / instruction width
    parameter NB_ADDR           = 8          ,  //! DU memory address width
    parameter NB_PC             = 32         ,  //! Program counter width
    parameter NB_REG            = 32         ,  //! Register file data width
    parameter NB_UART_DATA      = 8          ,  //! UART data width (1 byte)
    parameter N_BKP             = 4          ,  //! Number of hardware breakpoints
    parameter IMEM_ADDR_WIDTH   = 10         ,  //! Instruction memory address width
    parameter DMEM_ADDR_WIDTH   = 10         ,  //! Data memory address width

    // ------------------------------------------------------------------ //
    // FIFO parameters
    // ------------------------------------------------------------------ //
    parameter NB_FIFO_ADDR      = 4              //! FIFO depth = 2^NB_FIFO_ADDR entries
)
(
    // ------------------------------------------------------------------ //
    // Physical UART pins
    // ------------------------------------------------------------------ //
    output wire  o_uart_tx     ,  //! UART TX (to host)
    input  wire  i_uart_rx     ,  //! UART RX (from host)
    input  wire  i_en          ,  //! External enable (e.g., tied to PLL locked signal)

    // ------------------------------------------------------------------ //
    // System
    // ------------------------------------------------------------------ //
    input  wire  i_rst         ,  //! Synchronous reset (active high)
    input  wire  clock               //! System clock
);

    // =====================================================================
    // Baud Rate Generator
    // =====================================================================
    wire s_tick ;

    baud_rate_gen #(
        .NB_COUNTER (NB_BAUD_COUNTER),
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .SM_TICK    (SM_TICK)
    ) u_baud_gen (
        .o_counter  (),           // unused
        .o_tick     (s_tick),
        .i_rst      (i_rst),
        .clock      (clock)
    );

    // =====================================================================
    // UART RX
    // =====================================================================
    wire                        rx_done    ;  // byte received
    wire [NB_UART_DATA - 1 : 0] rx_data    ;  // received byte

    uart_rx #(
        .NB_DATA (NB_UART_DATA)
    ) u_uart_rx (
        .o_data         (rx_data),
        .o_rx_done_tick (rx_done),
        .i_rx           (i_uart_rx),
        .i_s_tick       (s_tick),
        .i_rst          (i_rst),
        .clock          (clock)
    );

    // =====================================================================
    // RX FIFO  (uart_rx → cpu_subsystem)
    // =====================================================================
    wire                        rx_fifo_empty   ;
    wire [NB_UART_DATA - 1 : 0] rx_fifo_data    ;  // data out to DU
    wire                        du_rx_rd        ;   // DU reads from RX FIFO

    fifo #(
        .NB_DATA    (NB_UART_DATA),
        .NB_ADDRESS (NB_FIFO_ADDR)
    ) u_rx_fifo (
        .o_data       (rx_fifo_data),
        .o_empty_flag (rx_fifo_empty),
        .o_full_flag  (),             // not used (UART speed  << CPU speed)
        .i_rd         (du_rx_rd),
        .i_wr         (rx_done),      // write on every received byte
        .i_data       (rx_data),
        .i_rst        (i_rst),
        .clock        (clock)
    );

    // rx_done_to_DU: pulse when there is new data in RX FIFO
    wire du_rx_done = ~rx_fifo_empty ;

    // =====================================================================
    // TX FIFO  (cpu_subsystem → uart_tx)
    // =====================================================================
    wire                        tx_fifo_empty   ;
    wire [NB_UART_DATA - 1 : 0] tx_fifo_data    ;  // data to uart_tx
    wire                        du_uart_wr       ;  // DU writes to TX FIFO
    wire [NB_UART_DATA - 1 : 0] du_uart_wdata   ;  // data from DU

    fifo #(
        .NB_DATA    (NB_UART_DATA),
        .NB_ADDRESS (NB_FIFO_ADDR)
    ) u_tx_fifo (
        .o_data       (tx_fifo_data),
        .o_empty_flag (tx_fifo_empty),
        .o_full_flag  (),
        .i_rd         (tx_done_tick),  // uart_tx reads one byte per transmission
        .i_wr         (du_uart_wr),
        .i_data       (du_uart_wdata),
        .i_rst        (i_rst),
        .clock        (clock)
    );

    // =====================================================================
    // UART TX
    // =====================================================================
    wire  tx_done_tick ;    // TX byte done
    wire  du_tx_start  ;    // DU signals "start sending"

    uart_tx #(
        .NB_DATA (NB_UART_DATA)
    ) u_uart_tx (
        .o_tx           (o_uart_tx),
        .o_tx_done_tick (tx_done_tick),
        .i_data         (tx_fifo_data),
        .i_tx_start     (~tx_fifo_empty),                 // start whenever FIFO has data
        .i_s_tick       (s_tick),
        .i_rst          (i_rst),
        .clock          (clock)
    );

    // =====================================================================
    // CPU Subsystem  (cpu_core + debug_unit_top)
    // =====================================================================
    cpu_subsystem #(
        .NB_DATA         (NB_DATA),
        .NB_ADDR         (NB_ADDR),
        .NB_PC           (NB_PC),
        .NB_REG          (NB_REG),
        .NB_UART_DATA    (NB_UART_DATA),
        .N_BKP           (N_BKP),
        .IMEM_ADDR_WIDTH (IMEM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH (DMEM_ADDR_WIDTH)
    ) u_cpu_subsystem (
        // UART TX (DU → TX FIFO → uart_tx)
        .o_tx_start   (du_tx_start),
        .o_uart_rd    (du_rx_rd),         // DU reads RX FIFO
        .o_uart_wr    (du_uart_wr),       // DU writes TX FIFO
        .o_uart_wdata (du_uart_wdata),

        // UART RX (RX FIFO → DU)
        .i_rx_done    (du_rx_done),       // data available in RX FIFO
        .i_rx_data    (rx_fifo_data),     // byte from RX FIFO
        .i_tx_done    (tx_done_tick),     // TX byte done

        // External enable (tie high — no PLL used, or use PLL locked signal)
        .i_en         (i_en),

        // System
        .i_rst        (i_rst),
        .clk          (clock)
    );

endmodule
