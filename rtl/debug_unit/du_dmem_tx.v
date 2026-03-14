//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_dmem_tx.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Data memory transmitter over UART.
//                - Reads sequential DMEM addresses via the debug port.
//                - Serializes each 32-bit word as 4 bytes (little-endian).
//                - Intended for full DMEM dumps; stops on address wrap.
//--------------------------------------------------------------------------------------------------

module du_dmem_tx
#(
    parameter NB_DATA      = 32,  // NB of memory data width
    parameter NB_ADDR      = 8,   // NB of memory address width
    parameter NB_UART_DATA = 8    // NB of UART data
) (
    // Outputs
    output reg                        o_done      ,  // Transfer done signal
    output reg                        o_tx_start  ,  // UART Tx start output
    output reg                        o_wr        ,  // UART FIFO Tx write enable output
    output reg [NB_UART_DATA - 1 : 0] o_wdata     ,  // UART FIFO Tx write data
    output reg                        o_mem_rd    ,  // Memory read enable output
    output     [NB_ADDR - 1 : 0]      o_mem_raddr ,  // Memory read address output

    // Inputs
    input wire                        i_start     ,  // Start signal from master
    input wire [NB_DATA - 1 : 0]      i_mem_data  ,  // Memory read data input
    input wire                        i_tx_done   ,  // UART Tx done signal
    input wire                        i_rst       ,
    input wire                        clk
);

    // Local Parameters
    localparam NB_STATE   = 3;
    localparam NB_COUNTER = 3;

    // Internal States
    localparam [NB_STATE - 1 : 0] IDLE      = 3'b001;
    localparam [NB_STATE - 1 : 0] READ_MEM  = 3'b010;
    localparam [NB_STATE - 1 : 0] SEND_WORD = 3'b100;

    // Internal Signals
    // State Register
    reg [NB_STATE - 1 : 0] state_reg ;
    reg [NB_STATE - 1 : 0] next_state;

    // Data Received Registers
    reg [NB_DATA - 1 : 0] rx_data_reg ;
    reg [NB_DATA - 1 : 0] rx_data_next;

    // Memory Read Address Registers
    reg [NB_ADDR - 1 : 0] mem_addr_reg ;
    reg [NB_ADDR - 1 : 0] mem_addr_next;

    // Word's bytes counter registers
    reg [NB_COUNTER - 1 : 0] counter_reg ;
    reg [NB_COUNTER - 1 : 0] counter_next;

    // Read Address Output Logic
    assign o_mem_raddr = mem_addr_reg;


    // FSMD states and data registers
    always @(posedge clk) begin
        if (i_rst) begin
            state_reg    <= IDLE;
            rx_data_reg  <= {NB_DATA{1'b0}};
            mem_addr_reg <= {NB_ADDR{1'b0}};
            counter_reg  <= {NB_COUNTER{1'b0}};
        end
        else begin
            state_reg    <= next_state;
            rx_data_reg  <= rx_data_next;
            mem_addr_reg <= mem_addr_next;
            counter_reg  <= counter_next;
        end
    end

    // Next-State Logic
    always @(*) begin
        // Default values
        next_state = state_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    next_state = READ_MEM;
                end
            end

            READ_MEM: begin
                if (counter_reg == 3'b100) begin
                    next_state = SEND_WORD;
                end
            end

            SEND_WORD: begin
                if (counter_reg == 3'b100 && i_tx_done) begin
                    if (mem_addr_reg == {NB_ADDR{1'b0}}) begin
                        next_state = IDLE;
                    end
                    else begin
                        next_state = READ_MEM;
                    end
                end
            end

            default: next_state = state_reg;
        endcase
    end

    // State Logic
    always @(*) begin
        // Default values
        o_done        = 1'b0;
        o_mem_rd      = 1'b0;
        o_tx_start    = 1'b0;
        o_wr          = 1'b0;
        o_wdata       = 8'h00;
        rx_data_next  = rx_data_reg;
        mem_addr_next = mem_addr_reg;
        counter_next  = counter_reg;

        case (state_reg)
            READ_MEM: begin
                if (counter_reg == 3'b000) begin
                    o_mem_rd      = 1'b1;
                    mem_addr_next = mem_addr_reg + 1'b1;
                end

                counter_next = counter_reg + 1'b1;

                if (counter_reg == 3'b100) begin
                    rx_data_next = i_mem_data;
                    counter_next = {NB_COUNTER{1'b0}};
                end
            end

            SEND_WORD: begin
                if (counter_reg == 3'b100) begin
                    if (i_tx_done) begin
                        counter_next = {NB_COUNTER{1'b0}};
                    end

                    if (mem_addr_reg == {NB_ADDR{1'b0}}) begin
                        o_done = 1'b1;
                    end
                end
                else if (counter_reg == 3'b000) begin
                    o_wdata      = rx_data_reg[7 : 0];
                    o_wr         = 1'b1;
                    o_tx_start   = 1'b1;
                    counter_next = counter_reg + 1'b1;
                end
                else if (counter_reg == 3'b001) begin
                    if (i_tx_done) begin
                        o_wdata      = rx_data_reg[15 : 8];
                        o_wr         = 1'b1;
                        o_tx_start   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b010) begin
                    if (i_tx_done) begin
                        o_wdata      = rx_data_reg[23 : 16];
                        o_wr         = 1'b1;
                        o_tx_start   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b011) begin
                    if (i_tx_done) begin
                        o_wdata      = rx_data_reg[31 : 24];
                        o_wr         = 1'b1;
                        o_tx_start   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
            end

            default: begin
                o_done        = 1'b0;
                o_mem_rd      = 1'b0;
                o_tx_start    = 1'b0;
                o_wr          = 1'b0;
                o_wdata       = 8'h00;
                rx_data_next  = rx_data_reg;
                mem_addr_next = mem_addr_reg;
                counter_next  = counter_reg;
            end

        endcase
    end

endmodule
