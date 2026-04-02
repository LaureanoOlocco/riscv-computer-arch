//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_imem_loader.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Instruction memory loader over UART.
//                - Receives a 32-bit size (instruction count), then 32-bit words.
//                - Writes each word to consecutive IMEM addresses (little-endian).
//                - Asserts done after the last word is written.
//--------------------------------------------------------------------------------------------------

module du_imem_loader
#(
    parameter NB_DATA      = 32,  // NB of memory data width
    parameter NB_ADDR      = 8,   // NB of memory address width
    parameter NB_UART_DATA = 8    // NB of UART data
) (
    // Outputs
    output wire                       o_done      ,  // Load done signal
    output wire                       o_mem_wr    ,  // Memory write enable output
    output wire [NB_ADDR - 1 : 0]     o_mem_waddr ,  // Memory write address output
    output wire [NB_DATA - 1 : 0]     o_mem_wdata ,  // Memory write data output

    // Inputs
    input wire                        i_start     ,  // Start signal from master
    input wire                        i_rx_done   ,  // UART RX byte received
    input wire [NB_UART_DATA - 1 : 0] i_rx_data   ,  // UART RX data byte
    input wire                        i_rst       ,
    input wire                        clk
);

    // Local Parameters
    localparam NB_STATE    = 4;
    localparam NB_BYTE_CNT = 2;

    // Internal States
    localparam [NB_STATE - 1 : 0] IDLE      = 4'b0001;
    localparam [NB_STATE - 1 : 0] RECV_SIZE = 4'b0010;
    localparam [NB_STATE - 1 : 0] RECV_INST = 4'b0100;
    localparam [NB_STATE - 1 : 0] WRITE_MEM = 4'b1000;

    // Internal Signals
    // State Register
    reg [NB_STATE - 1 : 0] state_reg ;
    reg [NB_STATE - 1 : 0] next_state;

    // Assembled Word Registers
    reg [NB_DATA - 1 : 0] word_reg ;
    reg [NB_DATA - 1 : 0] word_next;

    // Byte Counter Registers (position within 4-byte word)
    reg [NB_BYTE_CNT - 1 : 0] byte_counter_reg ;
    reg [NB_BYTE_CNT - 1 : 0] byte_counter_next;

    // Memory Write Address Registers
    reg [NB_ADDR - 1 : 0] mem_addr_reg ;
    reg [NB_ADDR - 1 : 0] mem_addr_next;

    // Instruction Count Registers (total instructions to load)
    reg [NB_DATA - 1 : 0] size_reg ;
    reg [NB_DATA - 1 : 0] size_next;

    reg                   done_out      ;
    reg                   mem_wr_out    ;

    // Output Assignments
    assign o_mem_waddr = mem_addr_reg;
    assign o_mem_wdata = word_reg;
    assign o_done      = done_out;
    assign o_mem_wr    = mem_wr_out;

    // FSMD states and data registers
    always @(posedge clk) begin
        if (i_rst) begin
            state_reg        <= IDLE;
            word_reg         <= {NB_DATA{1'b0}};
            byte_counter_reg <= {NB_BYTE_CNT{1'b0}};
            mem_addr_reg     <= {NB_ADDR{1'b0}};
            size_reg         <= {NB_DATA{1'b0}};
        end
        else begin
            state_reg        <= next_state;
            word_reg         <= word_next;
            byte_counter_reg <= byte_counter_next;
            mem_addr_reg     <= mem_addr_next;
            size_reg         <= size_next;
        end
    end

    // Next-State Logic
    always @(*) begin
        // Default values
        next_state = state_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    next_state = RECV_SIZE;
                end
            end

            RECV_SIZE: begin
                if (i_rx_done && byte_counter_reg == 2'd3) begin
                    next_state = RECV_INST;
                end
            end

            RECV_INST: begin
                if (i_rx_done && byte_counter_reg == 2'd3) begin
                    next_state = WRITE_MEM;
                end
            end

            WRITE_MEM: begin
                if ((mem_addr_reg + 1'b1) == size_reg[NB_ADDR - 1 : 0]) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = RECV_INST;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // State Logic
    always @(*) begin
        // Default values
        done_out          = 1'b0;
        mem_wr_out        = 1'b0;
        word_next         = word_reg;
        byte_counter_next = byte_counter_reg;
        mem_addr_next     = mem_addr_reg;
        size_next         = size_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    word_next         = {NB_DATA{1'b0}};
                    byte_counter_next = {NB_BYTE_CNT{1'b0}};
                    mem_addr_next     = {NB_ADDR{1'b0}};
                    size_next         = {NB_DATA{1'b0}};
                end
            end

            RECV_SIZE: begin
                if (i_rx_done) begin
                    case (byte_counter_reg)
                        2'd0: size_next[7  : 0]  = i_rx_data;
                        2'd1: size_next[15 : 8]  = i_rx_data;
                        2'd2: size_next[23 : 16] = i_rx_data;
                        2'd3: size_next[31 : 24] = i_rx_data;
                    endcase
                    byte_counter_next = byte_counter_reg + 1'b1;
                end
            end

            RECV_INST: begin
                if (i_rx_done) begin
                    case (byte_counter_reg)
                        2'd0: word_next[7  : 0]  = i_rx_data;
                        2'd1: word_next[15 : 8]  = i_rx_data;
                        2'd2: word_next[23 : 16] = i_rx_data;
                        2'd3: word_next[31 : 24] = i_rx_data;
                    endcase
                    byte_counter_next = byte_counter_reg + 1'b1;
                end
            end

            WRITE_MEM: begin
                mem_wr_out    = 1'b1;
                mem_addr_next = mem_addr_reg + 1'b1;
                word_next     = {NB_DATA{1'b0}};

                if ((mem_addr_reg + 1'b1) == size_reg[NB_ADDR - 1 : 0]) begin
                    done_out = 1'b1;
                end
            end

            default: begin
                done_out          = 1'b0;
                mem_wr_out        = 1'b0;
                word_next         = word_reg;
                byte_counter_next = byte_counter_reg;
                mem_addr_next     = mem_addr_reg;
                size_next         = size_reg;
            end

        endcase
    end

endmodule
