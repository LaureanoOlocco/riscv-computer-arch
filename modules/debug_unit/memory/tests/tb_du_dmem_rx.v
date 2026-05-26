//! @title TESTBENCH - DEBUG UNIT DATA MEMORY RECEIVER
//! @file tb_du_dmem_rx.v

`timescale 1ns / 1ps

module tb_du_dmem_rx;

    // Parameters
    localparam NB_DATA      = 32;
    localparam NB_ADDR      = 8;
    localparam NB_UART_DATA = 8;
    localparam CLK_PERIOD   = 10;

    // DUT signals
    reg                         clk;
    reg                         i_rst;
    reg                         i_start;
    reg  [NB_DATA - 1 : 0]    i_waddr;
    reg                         i_rx_done;
    reg  [NB_UART_DATA - 1 : 0] i_rx_data;
    wire                        o_done;
    wire                        o_dmem_wr;
    wire [NB_ADDR - 1 : 0]    o_dmem_waddr;
    wire [NB_DATA - 1 : 0]    o_dmem_wdata;

    integer errors;

    // DUT instantiation
    du_dmem_rx #(
        .NB_DATA      (NB_DATA),
        .NB_ADDR      (NB_ADDR),
        .NB_UART_DATA (NB_UART_DATA)
    ) dut (
        .o_done       (o_done),
        .o_dmem_wr    (o_dmem_wr),
        .o_dmem_waddr (o_dmem_waddr),
        .o_dmem_wdata (o_dmem_wdata),
        .i_start      (i_start),
        .i_waddr      (i_waddr),
        .i_rx_done    (i_rx_done),
        .i_rx_data    (i_rx_data),
        .i_rst        (i_rst),
        .clk          (clk)
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
        $dumpfile("tb_du_dmem_rx.vcd");
        $dumpvars(0, tb_du_dmem_rx);

        errors    = 0;
        i_rst     = 1'b1;
        i_start   = 1'b0;
        i_waddr   = 32'h0;
        i_rx_done = 1'b0;
        i_rx_data = 8'h00;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 2);

        // Test 1: Write 0xCAFEBABE to address 0x10
        $display("\n--- Test 1: Write 0xCAFEBABE to addr 0x10 ---");
        @(negedge clk);
        i_waddr = 32'h00000010;
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        send_byte(8'hBE);  // byte 0 (LSB)
        send_byte(8'hBA);  // byte 1
        send_byte(8'hFE);  // byte 2
        send_byte(8'hCA);  // byte 3 (MSB)

        @(posedge o_done);
        #1;

        if (o_dmem_wr && o_dmem_waddr == 8'h10 && o_dmem_wdata == 32'hCAFEBABE) begin
            $display("OK: Write [0x10] = 0x%08h", o_dmem_wdata);
        end
        else begin
            $display("ERROR: wr=%b, addr=0x%02h, data=0x%08h",
                     o_dmem_wr, o_dmem_waddr, o_dmem_wdata);
            errors = errors + 1;
        end

        if (!o_done) begin
            $display("ERROR: o_done not asserted");
            errors = errors + 1;
        end

        @(posedge clk);
        @(posedge clk);

        // Test 2: Write 0x00000001 to address 0xFF
        $display("\n--- Test 2: Write 0x00000001 to addr 0xFF ---");
        @(negedge clk);
        i_waddr = 32'h000000FF;
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);

        @(posedge o_done);
        #1;

        if (o_dmem_wr && o_dmem_waddr == 8'hFF && o_dmem_wdata == 32'h00000001) begin
            $display("OK: Write [0xFF] = 0x%08h", o_dmem_wdata);
        end
        else begin
            $display("ERROR: wr=%b, addr=0x%02h, data=0x%08h",
                     o_dmem_wr, o_dmem_waddr, o_dmem_wdata);
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
