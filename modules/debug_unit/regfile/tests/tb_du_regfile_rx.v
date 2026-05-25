//! @title TESTBENCH - DEBUG UNIT REGISTER FILE RECEIVER
//! @file tb_du_regfile_rx.v

`timescale 1ns / 1ps

module tb_du_regfile_rx;

    // Parameters
    localparam NB_DATA      = 32;
    localparam NB_UART_DATA = 8;
    localparam CLK_PERIOD   = 10;

    // DUT signals
    reg                         clk;
    reg                         i_rst;
    reg                         i_start;
    reg  [4 : 0]               i_waddr;
    reg                         i_rx_done;
    reg  [NB_UART_DATA - 1 : 0] i_rx_data;
    wire                        o_done;
    wire                        o_regfile_wr;
    wire [4 : 0]               o_regfile_waddr;
    wire [NB_DATA - 1 : 0]    o_regfile_wdata;

    integer errors;

    // DUT instantiation
    du_regfile_rx #(
        .NB_DATA      (NB_DATA),
        .NB_UART_DATA (NB_UART_DATA)
    ) dut (
        .o_done          (o_done),
        .o_regfile_wr    (o_regfile_wr),
        .o_regfile_waddr (o_regfile_waddr),
        .o_regfile_wdata (o_regfile_wdata),
        .i_start         (i_start),
        .i_waddr         (i_waddr),
        .i_rx_done       (i_rx_done),
        .i_rx_data       (i_rx_data),
        .i_rst           (i_rst),
        .clk             (clk)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Task: send a UART byte (drive on negedge to avoid race with DUT posedge)
    task send_byte;
        input [NB_UART_DATA - 1 : 0] data;
        begin
            @(negedge clk);
            i_rx_data = data;
            i_rx_done = 1'b1;
            @(negedge clk);
            i_rx_done = 1'b0;
            @(negedge clk);
        end
    endtask

    // Main test
    initial begin
        $dumpfile("tb_du_regfile_rx.vcd");
        $dumpvars(0, tb_du_regfile_rx);

        errors    = 0;
        i_rst     = 1'b1;
        i_start   = 1'b0;
        i_waddr   = 5'b0;
        i_rx_done = 1'b0;
        i_rx_data = 8'h00;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 2);

        // Test 1: Write 0x78563412 to register 5
        $display("\n--- Test 1: Write 0x78563412 to x5 ---");
        @(negedge clk);
        i_waddr = 5'd5;
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        send_byte(8'h12);  // byte 0 (LSB)
        send_byte(8'h34);  // byte 1
        send_byte(8'h56);  // byte 2
        send_byte(8'h78);  // byte 3 (MSB)

        @(posedge o_done);  // wait for WRITE_REG state
        #1;  // combinational settle

        if (o_regfile_wr && o_regfile_waddr == 5'd5 && o_regfile_wdata == 32'h78563412) begin
            $display("OK: Write x5 = 0x%08h", o_regfile_wdata);
        end
        else begin
            $display("ERROR: wr=%b, addr=%0d, data=0x%08h",
                     o_regfile_wr, o_regfile_waddr, o_regfile_wdata);
            errors = errors + 1;
        end

        if (!o_done) begin
            $display("ERROR: o_done not asserted");
            errors = errors + 1;
        end

        @(posedge clk);
        @(posedge clk);

        // Test 2: Write 0xFFFFFFFF to register 31
        $display("\n--- Test 2: Write 0xFFFFFFFF to x31 ---");
        @(negedge clk);
        i_waddr = 5'd31;
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hFF);

        @(posedge o_done);
        #1;

        if (o_regfile_wr && o_regfile_waddr == 5'd31 && o_regfile_wdata == 32'hFFFFFFFF) begin
            $display("OK: Write x31 = 0x%08h", o_regfile_wdata);
        end
        else begin
            $display("ERROR: wr=%b, addr=%0d, data=0x%08h",
                     o_regfile_wr, o_regfile_waddr, o_regfile_wdata);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 5);
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
