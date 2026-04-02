//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_dmem_rx.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Data memory receiver/writer over UART.
//                - Receives 4 bytes following a write command.
//                - Address is provided by du_master on start.
//                - Writes the assembled 32-bit word to DMEM and pulses done.
//--------------------------------------------------------------------------------------------------

module du_dmem_rx
#(
    parameter NB_DATA      = 32,  // NB of data width
    parameter NB_ADDR      = 8,   // NB of memory address width
    parameter NB_UART_DATA = 8    // NB of UART data
) (
    // Outputs
    output wire                       o_done            ,  // Write done signal
    output wire                       o_dmem_wr         ,  // Data memory write enable
    output wire [NB_ADDR     - 1 : 0] o_dmem_waddr      ,  // Data memory write address
    output wire [NB_DATA     - 1 : 0] o_dmem_wdata      ,  // Data memory write data

    // Inputs
    input wire                        i_start           ,  // Start signal from master
    input wire [NB_DATA      - 1 : 0] i_waddr           ,  // Write address from master (full 32-bit, truncated to NB_ADDR)
    input wire                        i_rx_done         ,  // UART RX byte received
    input wire [NB_UART_DATA - 1 : 0] i_rx_data         ,  // UART RX data byte
    input wire                        i_rst             ,
    input wire                        clk
);

    // Local Parameters
    localparam NB_STATE    = 3;
    localparam NB_BYTE_CNT = 2;

    // Internal States (one-hot)
    localparam [NB_STATE - 1 : 0] IDLE      = 3'b001;
    localparam [NB_STATE - 1 : 0] RECV_DATA = 3'b010;
    localparam [NB_STATE - 1 : 0] WRITE_MEM = 3'b100;

    // Internal Signals
    reg [NB_STATE - 1 : 0] state_reg, next_state;

    // Assembled word
    reg [NB_DATA - 1 : 0] word_reg, word_next;

    // Byte counter
    reg [NB_BYTE_CNT - 1 : 0] byte_cnt_reg, byte_cnt_next;

    // Latched write address
    reg [NB_ADDR - 1 : 0] addr_reg, addr_next;

    reg                   done_out;
    reg                   dmem_wr_out;

    // Output Assignments
    assign o_dmem_waddr = addr_reg;
    assign o_dmem_wdata = word_reg;
    assign o_done       = done_out;
    assign o_dmem_wr    = dmem_wr_out;

    // Sequential Logic
    always @(posedge clk) begin
        if (i_rst) begin
            state_reg    <= IDLE;
            word_reg     <= {NB_DATA{1'b0}};
            byte_cnt_reg <= {NB_BYTE_CNT{1'b0}};
            addr_reg     <= {NB_ADDR{1'b0}};
        end
        else begin
            state_reg    <= next_state;
            word_reg     <= word_next;
            byte_cnt_reg <= byte_cnt_next;
            addr_reg     <= addr_next;
        end
    end

    // Next-State Logic
    always @(*) begin
        next_state = state_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    next_state = RECV_DATA;
                end
            end

            RECV_DATA: begin
                if (i_rx_done && byte_cnt_reg == 2'd3) begin
                    next_state = WRITE_MEM;
                end
            end

            WRITE_MEM: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State Logic
    always @(*) begin
        // Defaults
        done_out      = 1'b0;
        dmem_wr_out   = 1'b0;
        word_next     = word_reg;
        byte_cnt_next = byte_cnt_reg;
        addr_next     = addr_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    word_next     = {NB_DATA{1'b0}};
                    byte_cnt_next = {NB_BYTE_CNT{1'b0}};
                    addr_next     = i_waddr[NB_ADDR - 1 : 0];
                end
            end

            RECV_DATA: begin
                if (i_rx_done) begin
                    case (byte_cnt_reg)
                        2'd0: word_next[7  : 0]  = i_rx_data;
                        2'd1: word_next[15 : 8]  = i_rx_data;
                        2'd2: word_next[23 : 16] = i_rx_data;
                        2'd3: word_next[31 : 24] = i_rx_data;
                    endcase
                    byte_cnt_next = byte_cnt_reg + 1'b1;
                end
            end

            WRITE_MEM: begin
                dmem_wr_out = 1'b1;
                done_out    = 1'b1;
            end

            default: begin
                // noop
            end
        endcase
    end

endmodule
