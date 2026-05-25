//! @title TESTBENCH - DEBUG UNIT REGISTER FILE TX
//! @file tb_du_regfile_tx.v
//! @brief Verifies that the full register dump sends PC + x0..x31.

`timescale 1ns / 1ps

module tb_du_regfile_tx;

    localparam NB_PC        = 32;
    localparam NB_REG       = 32;
    localparam NB_UART_DATA = 8;
    localparam CLK_PERIOD   = 10;

    reg                         clk;
    reg                         i_rst;
    reg                         i_start;
    reg  [NB_PC        - 1 : 0] i_pc;
    reg  [NB_REG       - 1 : 0] i_regfile_data;
    reg                         i_tx_done;

    wire                        o_done;
    wire                        o_tx_start;
    wire                        o_wr;
    wire [NB_UART_DATA - 1 : 0] o_wdata;
    wire                        o_regfile_rd;
    wire [4 : 0]                o_regfile_raddr;

    reg [NB_UART_DATA - 1 : 0] tx_bytes [0 : 131];
    integer tx_count;
    integer errors;
    integer idx;
    integer timeout;

    du_regfile_tx #(
        .NB_PC        (NB_PC),
        .NB_REG       (NB_REG),
        .NB_UART_DATA (NB_UART_DATA)
    ) dut (
        .o_done          (o_done),
        .o_tx_start      (o_tx_start),
        .o_wr            (o_wr),
        .o_wdata         (o_wdata),
        .o_regfile_rd    (o_regfile_rd),
        .o_regfile_raddr (o_regfile_raddr),
        .i_start         (i_start),
        .i_pc            (i_pc),
        .i_regfile_data  (i_regfile_data),
        .i_tx_done       (i_tx_done),
        .i_rst           (i_rst),
        .clk             (clk)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    always @(*) begin
        i_regfile_data = {27'b0, o_regfile_raddr};
    end

    always @(posedge clk) begin
        if (i_rst) begin
            i_tx_done <= 1'b0;
            tx_count  <= 0;
        end
        else begin
            i_tx_done <= o_wr;
            if (o_wr) begin
                tx_bytes[tx_count] <= o_wdata;
                tx_count <= tx_count + 1;
            end
        end
    end

    initial begin
        $dumpfile("tb_du_regfile_tx.vcd");
        $dumpvars(0, tb_du_regfile_tx);

        errors  = 0;
        timeout = 0;
        i_rst   = 1'b1;
        i_start = 1'b0;
        i_pc    = 32'h12345678;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 2);

        @(posedge clk);
        i_start = 1'b1;
        @(posedge clk);
        i_start = 1'b0;

        while (!o_done && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (!o_done) begin
            $display("ERROR: timeout waiting for o_done");
            errors = errors + 1;
        end

        @(posedge clk);

        if (tx_count == 132) begin
            $display("OK: emitted 132 dump bytes");
        end
        else begin
            $display("ERROR: expected 132 bytes, got %0d", tx_count);
            errors = errors + 1;
        end

        if (tx_bytes[0] != 8'h78 || tx_bytes[1] != 8'h56 ||
            tx_bytes[2] != 8'h34 || tx_bytes[3] != 8'h12) begin
            $display("ERROR: PC bytes are wrong");
            errors = errors + 1;
        end

        for (idx = 0; idx < 32; idx = idx + 1) begin
            if (tx_bytes[4 + idx*4]     != idx[7:0] ||
                tx_bytes[4 + idx*4 + 1] != 8'h00 ||
                tx_bytes[4 + idx*4 + 2] != 8'h00 ||
                tx_bytes[4 + idx*4 + 3] != 8'h00) begin
                $display("ERROR: x%0d dump bytes are wrong", idx);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("\n*** REGFILE TX TEST PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
