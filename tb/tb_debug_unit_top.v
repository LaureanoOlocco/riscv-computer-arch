//! @title TESTBENCH - DEBUG UNIT TOP (Integration)
//! @file tb_debug_unit_top.v
//! @brief Integration test: sends command frames byte-by-byte through
//!        debug_unit_top and verifies UART TX responses.

`timescale 1ns / 1ps

module tb_debug_unit_top;

    // Parameters
    localparam NB_DATA      = 32;
    localparam NB_ADDR      = 8;
    localparam NB_PC        = 32;
    localparam NB_REG       = 32;
    localparam NB_UART_DATA = 8;
    localparam N_BKP        = 4;
    localparam CLK_PERIOD   = 10;

    // DUT signals
    reg                         clk;
    reg                         i_rst;
    reg                         i_rx_done;
    reg  [NB_UART_DATA - 1 : 0] i_rx_data;
    reg                         i_tx_done;
    reg  [NB_PC - 1 : 0]       i_pc;
    reg  [NB_DATA - 1 : 0]     i_instruction;
    reg  [NB_REG - 1 : 0]      i_regfile_data;
    reg  [NB_DATA - 1 : 0]     i_dmem_data;

    wire                        o_cpu_enable;
    wire                        o_cpu_reset;
    wire                        o_imem_wr;
    wire [NB_ADDR - 1 : 0]    o_imem_waddr;
    wire [NB_DATA - 1 : 0]    o_imem_wdata;
    wire                        o_regfile_rd;
    wire [4 : 0]               o_regfile_raddr;
    wire                        o_regfile_wr;
    wire [4 : 0]               o_regfile_waddr;
    wire [NB_REG - 1 : 0]     o_regfile_wdata;
    wire                        o_dmem_rd;
    wire [NB_ADDR - 1 : 0]    o_dmem_raddr;
    wire                        o_dmem_wr;
    wire [NB_ADDR - 1 : 0]    o_dmem_waddr;
    wire [NB_DATA - 1 : 0]    o_dmem_wdata;
    wire                        o_bkp_hit;
    wire                        o_tx_start;
    wire                        o_uart_rd;
    wire                        o_uart_wr;
    wire [NB_UART_DATA - 1 : 0] o_uart_wdata;

    integer errors;

    // Response capture
    reg [NB_UART_DATA - 1 : 0] resp_bytes [0 : 4];
    integer resp_idx;

    // DUT instantiation
    debug_unit_top #(
        .NB_DATA      (NB_DATA),
        .NB_ADDR      (NB_ADDR),
        .NB_PC        (NB_PC),
        .NB_REG       (NB_REG),
        .NB_UART_DATA (NB_UART_DATA),
        .N_BKP        (N_BKP)
    ) dut (
        .o_cpu_enable    (o_cpu_enable),
        .o_cpu_reset     (o_cpu_reset),
        .o_imem_wr       (o_imem_wr),
        .o_imem_waddr    (o_imem_waddr),
        .o_imem_wdata    (o_imem_wdata),
        .o_regfile_rd    (o_regfile_rd),
        .o_regfile_raddr (o_regfile_raddr),
        .o_regfile_wr    (o_regfile_wr),
        .o_regfile_waddr (o_regfile_waddr),
        .o_regfile_wdata (o_regfile_wdata),
        .o_dmem_rd       (o_dmem_rd),
        .o_dmem_raddr    (o_dmem_raddr),
        .o_dmem_wr       (o_dmem_wr),
        .o_dmem_waddr    (o_dmem_waddr),
        .o_dmem_wdata    (o_dmem_wdata),
        .o_bkp_hit       (o_bkp_hit),
        .o_tx_start      (o_tx_start),
        .o_uart_rd       (o_uart_rd),
        .o_uart_wr       (o_uart_wr),
        .o_uart_wdata    (o_uart_wdata),
        .i_pc            (i_pc),
        .i_instruction   (i_instruction),
        .i_regfile_data  (i_regfile_data),
        .i_dmem_data     (i_dmem_data),
        .i_rx_done       (i_rx_done),
        .i_rx_data       (i_rx_data),
        .i_tx_done       (i_tx_done),
        .i_rst           (i_rst),
        .clk             (clk)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Task: send one UART byte
    task send_byte;
        input [NB_UART_DATA - 1 : 0] data;
        begin
            @(posedge clk);
            i_rx_data = data;
            i_rx_done = 1'b1;
            @(posedge clk);
            i_rx_done = 1'b0;
            @(posedge clk);
        end
    endtask

    // Task: send a 6-byte command frame
    task send_cmd;
        input [7 : 0]  opcode;
        input [31 : 0] payload;
        reg   [7 : 0]  checksum;
        begin
            checksum = opcode ^ payload[7:0] ^ payload[15:8]
                     ^ payload[23:16] ^ payload[31:24];

            send_byte(opcode);
            send_byte(payload[7 : 0]);
            send_byte(payload[15 : 8]);
            send_byte(payload[23 : 16]);
            send_byte(payload[31 : 24]);
            send_byte(checksum);
        end
    endtask

    // Task: capture 5-byte response (simulating UART TX done handshake)
    task capture_response;
        begin
            resp_idx = 0;
            while (resp_idx < 5) begin
                @(posedge clk);
                if (o_uart_wr) begin
                    resp_bytes[resp_idx] = o_uart_wdata;
                    resp_idx = resp_idx + 1;
                    // Simulate TX completion
                    @(posedge clk);
                    @(posedge clk);
                    i_tx_done = 1'b1;
                    @(posedge clk);
                    i_tx_done = 1'b0;
                end
            end
        end
    endtask

    // Main test
    initial begin
        $dumpfile("tb_debug_unit_top.vcd");
        $dumpvars(0, tb_debug_unit_top);

        errors        = 0;
        i_rst         = 1'b1;
        i_rx_done     = 1'b0;
        i_rx_data     = 8'h00;
        i_tx_done     = 1'b0;
        i_pc          = 32'h00000000;
        i_instruction = 32'h00000013;
        i_regfile_data= 32'h0;
        i_dmem_data   = 32'h0;
        resp_idx      = 0;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 5);

        // ===========================================================
        // Test 1: CMD_STATUS
        // ===========================================================
        $display("\n--- Integration Test 1: CMD_STATUS ---");
        send_cmd(8'h0F, 32'h00000000);

        // Wait for processing
        #(CLK_PERIOD * 10);

        // Capture response
        capture_response;

        $display("Response: status=0x%02h, data=0x%02h%02h%02h%02h",
                 resp_bytes[0], resp_bytes[4], resp_bytes[3],
                 resp_bytes[2], resp_bytes[1]);

        if (resp_bytes[0] == 8'h00) begin
            $display("OK: Status OK");
        end
        else begin
            $display("ERROR: Expected STATUS_OK");
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // ===========================================================
        // Test 2: CMD_HALT — verify PC in response
        // ===========================================================
        $display("\n--- Integration Test 2: CMD_HALT ---");
        i_pc = 32'h00000080;
        send_cmd(8'h04, 32'h00000000);

        #(CLK_PERIOD * 10);
        capture_response;

        $display("Response: status=0x%02h, PC=0x%02h%02h%02h%02h",
                 resp_bytes[0], resp_bytes[4], resp_bytes[3],
                 resp_bytes[2], resp_bytes[1]);

        if (resp_bytes[0] == 8'h00 &&
            resp_bytes[1] == 8'h80 &&
            resp_bytes[2] == 8'h00 &&
            resp_bytes[3] == 8'h00 &&
            resp_bytes[4] == 8'h00) begin
            $display("OK: HALT, PC = 0x00000080");
        end
        else begin
            $display("ERROR: Wrong HALT response");
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // ===========================================================
        // Test 3: CMD_SET_BKP + verify bkp_hit
        // ===========================================================
        $display("\n--- Integration Test 3: CMD_SET_BKP + hit ---");
        send_cmd(8'h09, 32'h00000200);

        #(CLK_PERIOD * 10);
        capture_response;

        // Now set PC to breakpoint address
        i_pc = 32'h00000200;
        #(CLK_PERIOD * 2);

        if (o_bkp_hit) begin
            $display("OK: Breakpoint hit at 0x200");
        end
        else begin
            $display("ERROR: Expected breakpoint hit");
            errors = errors + 1;
        end

        // Summary
        #(CLK_PERIOD * 10);
        if (errors == 0)
            $display("\n*** ALL INTEGRATION TESTS PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
