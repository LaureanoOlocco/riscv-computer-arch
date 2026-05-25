//! @title TESTBENCH - DEBUG UNIT RESPONSE BUILDER
//! @file tb_du_resp_builder.v

`timescale 1ns / 1ps

module tb_du_resp_builder;

    // Parameters
    localparam NB_UART_DATA = 8;
    localparam NB_DATA      = 32;
    localparam CLK_PERIOD   = 10;

    // DUT signals
    reg                         clk;
    reg                         i_rst;
    reg                         i_valid;
    reg  [NB_UART_DATA - 1 : 0] i_status;
    reg  [NB_DATA - 1 : 0]      i_data;
    reg                         i_tx_done;
    wire                        o_done;
    wire                        o_tx_start;
    wire                        o_wr;
    wire [NB_UART_DATA - 1 : 0] o_wdata;

    // Expected output tracking
    reg [NB_UART_DATA - 1 : 0] expected_bytes [0:4];
    integer byte_idx;
    integer errors;

    // DUT instantiation
    du_resp_builder #(
        .NB_UART_DATA (NB_UART_DATA),
        .NB_DATA      (NB_DATA)
    ) dut (
        .o_done     (o_done),
        .o_tx_start (o_tx_start),
        .o_wr       (o_wr),
        .o_wdata    (o_wdata),
        .i_valid    (i_valid),
        .i_status   (i_status),
        .i_data     (i_data),
        .i_tx_done  (i_tx_done),
        .i_rst      (i_rst),
        .clk        (clk)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Task: simulate TX done after a few cycles
    task wait_and_ack_tx;
        begin
            @(posedge clk);
            @(posedge clk);
            i_tx_done = 1'b1;
            @(posedge clk);
            i_tx_done = 1'b0;
        end
    endtask

    // Task: send a response and verify
    task send_and_verify;
        input [NB_UART_DATA - 1 : 0] status;
        input [NB_DATA - 1 : 0]       data;
        begin
            expected_bytes[0] = status;
            expected_bytes[1] = data[7 : 0];
            expected_bytes[2] = data[15 : 8];
            expected_bytes[3] = data[23 : 16];
            expected_bytes[4] = data[31 : 24];

            // Assert valid
            i_status = status;
            i_data   = data;
            i_valid  = 1'b1;
            @(posedge clk);
            i_valid  = 1'b0;

            // Capture and verify each byte
            for (byte_idx = 0; byte_idx < 5; byte_idx = byte_idx + 1) begin
                // Wait for wr assertion
                @(posedge clk);
                if (o_wr) begin
                    if (o_wdata !== expected_bytes[byte_idx]) begin
                        $display("ERROR: Byte %0d: expected 0x%02h, got 0x%02h",
                                 byte_idx, expected_bytes[byte_idx], o_wdata);
                        errors = errors + 1;
                    end
                    else begin
                        $display("OK: Byte %0d = 0x%02h", byte_idx, o_wdata);
                    end
                end
                // Simulate TX done
                wait_and_ack_tx;
            end

            // Wait for done
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    // Main test
    initial begin
        $dumpfile("tb_du_resp_builder.vcd");
        $dumpvars(0, tb_du_resp_builder);

        errors    = 0;
        i_rst     = 1'b1;
        i_valid   = 1'b0;
        i_status  = 8'h00;
        i_data    = 32'h0;
        i_tx_done = 1'b0;

        // Reset
        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 2);

        // Test 1: OK response with data 0xDEADBEEF
        $display("\n--- Test 1: OK response, data=0xDEADBEEF ---");
        send_and_verify(8'h00, 32'hDEADBEEF);

        // Test 2: ERROR response with data 0x00000000
        $display("\n--- Test 2: ERROR response, data=0x00000000 ---");
        send_and_verify(8'h01, 32'h00000000);

        // Test 3: BUSY response with data 0x12345678
        $display("\n--- Test 3: BUSY response, data=0x12345678 ---");
        send_and_verify(8'h02, 32'h12345678);

        // Summary
        #(CLK_PERIOD * 5);
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
