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
    output wire                        o_done      ,  // Transfer done signal
    output wire                        o_tx_start  ,  // UART Tx start output
    output wire                        o_wr        ,  // UART FIFO Tx write enable output
    output wire [NB_UART_DATA - 1 : 0] o_wdata     ,  // UART FIFO Tx write data
    output wire                        o_mem_rd    ,  // Memory read enable output
    output wire [NB_ADDR      - 1 : 0] o_mem_raddr ,  // Memory read address output

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

    reg                        done_out      ; // Transfer done signal
    reg                        tx_start_out  ; // UART Tx start output
    reg                        wr_out        ; // UART FIFO Tx write enable output
    reg [NB_UART_DATA - 1 : 0] wdata_out     ; // UART FIFO Tx write data
    reg                        mem_rd_out    ; // Memory read enable output

    // Read Address Output Logic
    assign o_mem_raddr = mem_addr_reg;
    assign o_done      = done_out;
    assign o_tx_start  = tx_start_out;
    assign o_wr        = wr_out;
    assign o_wdata     = wdata_out;
    assign o_mem_rd    = mem_rd_out;

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
        done_out      = 1'b0;
        tx_start_out  = 1'b0;
        wr_out        = 1'b0;
        wdata_out     = 8'h00;
        mem_rd_out    = 1'b0;
        rx_data_next  = rx_data_reg;
        mem_addr_next = mem_addr_reg;
        counter_next  = counter_reg;

        case (state_reg)
            READ_MEM: begin
                if (counter_reg == 3'b000) begin
                    mem_rd_out      = 1'b1;
                end

                counter_next = counter_reg + 1'b1;

                if (counter_reg == 3'b100) begin
                    rx_data_next = i_mem_data;
                    mem_addr_next = mem_addr_reg + 1'b1;
                    counter_next = {NB_COUNTER{1'b0}};
                end
            end

            SEND_WORD: begin
                if (counter_reg == 3'b100) begin
                    if (i_tx_done) begin
                        counter_next = {NB_COUNTER{1'b0}};
                    end

                    if (mem_addr_reg == {NB_ADDR{1'b0}}) begin
                        done_out = 1'b1;
                    end
                end
                else if (counter_reg == 3'b000) begin
                    wdata_out      = rx_data_reg[7 : 0];
                    wr_out         = 1'b1;
                    tx_start_out   = 1'b1;
                    counter_next = counter_reg + 1'b1;
                end
                else if (counter_reg == 3'b001) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[15 : 8];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b010) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[23 : 16];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b011) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[31 : 24];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
            end

            default: begin
                done_out        = 1'b0;
                mem_rd_out      = 1'b0;
                tx_start_out    = 1'b0;
                wr_out          = 1'b0;
                wdata_out       = 8'h00;
                rx_data_next  = rx_data_reg;
                mem_addr_next = mem_addr_reg;
                counter_next  = counter_reg;
            end

        endcase
    end

endmodule
