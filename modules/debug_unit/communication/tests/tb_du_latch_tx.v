//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : tb_du_latch_tx.v
// Date        : 2026-05
// Author      : Sofia Avalos - Laureano Olocco
// Description : Testbench for du_latch_tx.
//                - Loads known values into all latch inputs.
//                - Asserts i_start, then captures every byte that the module emits.
//                - Verifies the 45-byte stream matches the expected layout.
//--------------------------------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_du_latch_tx;

    localparam NB_DATA      = 32;
    localparam NB_PC        = 32;
    localparam NB_UART_DATA = 8;
    localparam NB_BYTES     = 45;
    localparam CLK_PERIOD   = 10;

    // Clock / reset / control
    reg clk;
    reg i_rst;
    reg i_start;
    reg i_tx_done;

    // Latch signal stimuli (deterministic patterns)
    reg [NB_PC   - 1 : 0] i_ifid_pc;
    reg [NB_DATA - 1 : 0] i_ifid_instr;
    reg [8 : 0]            i_idex_ctrl;
    reg [NB_DATA - 1 : 0] i_idex_rs1_data;
    reg [NB_DATA - 1 : 0] i_idex_rs2_data;
    reg [NB_DATA - 1 : 0] i_idex_imm;
    reg [4 : 0]            i_idex_rd_addr;
    reg [4 : 0]            i_idex_rs1_addr;
    reg [4 : 0]            i_idex_rs2_addr;
    reg [3 : 0]            i_exmem_ctrl;
    reg [NB_DATA - 1 : 0] i_exmem_alu;
    reg [NB_DATA - 1 : 0] i_exmem_data2;
    reg [4 : 0]            i_exmem_rd_addr;
    reg [1 : 0]            i_memwb_ctrl;
    reg [NB_DATA - 1 : 0] i_memwb_data;
    reg [NB_DATA - 1 : 0] i_memwb_alu;
    reg [4 : 0]            i_memwb_rd_addr;

    // Outputs
    wire                        o_done;
    wire                        o_tx_start;
    wire                        o_wr;
    wire [NB_UART_DATA - 1 : 0] o_wdata;

    // DUT
    du_latch_tx #(
        .NB_DATA      (NB_DATA),
        .NB_PC        (NB_PC),
        .NB_UART_DATA (NB_UART_DATA)
    ) dut (
        .o_done          (o_done),
        .o_tx_start      (o_tx_start),
        .o_wr            (o_wr),
        .o_wdata         (o_wdata),
        .i_start         (i_start),
        .i_ifid_pc       (i_ifid_pc),
        .i_ifid_instr    (i_ifid_instr),
        .i_idex_ctrl     (i_idex_ctrl),
        .i_idex_rs1_data (i_idex_rs1_data),
        .i_idex_rs2_data (i_idex_rs2_data),
        .i_idex_imm      (i_idex_imm),
        .i_idex_rd_addr  (i_idex_rd_addr),
        .i_idex_rs1_addr (i_idex_rs1_addr),
        .i_idex_rs2_addr (i_idex_rs2_addr),
        .i_exmem_ctrl    (i_exmem_ctrl),
        .i_exmem_alu     (i_exmem_alu),
        .i_exmem_data2   (i_exmem_data2),
        .i_exmem_rd_addr (i_exmem_rd_addr),
        .i_memwb_ctrl    (i_memwb_ctrl),
        .i_memwb_data    (i_memwb_data),
        .i_memwb_alu     (i_memwb_alu),
        .i_memwb_rd_addr (i_memwb_rd_addr),
        .i_tx_done       (i_tx_done),
        .i_rst           (i_rst),
        .clk             (clk)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Captured stream
    reg [NB_UART_DATA - 1 : 0] captured [0 : NB_BYTES - 1];
    reg [NB_UART_DATA - 1 : 0] expected [0 : NB_BYTES - 1];
    integer cap_idx;
    integer errors;

    // Capture each byte when o_wr pulses (in SEND_BYTE state)
    always @(posedge clk) begin
        if (!i_rst && o_wr && cap_idx < NB_BYTES) begin
            captured[cap_idx] <= o_wdata;
            cap_idx <= cap_idx + 1;
        end
    end

    // Acknowledge UART TX one cycle after the byte is presented
    // (mimics du_uart returning i_tx_done shortly after TX start)
    reg pending_ack;
    always @(posedge clk) begin
        if (i_rst) begin
            pending_ack <= 1'b0;
            i_tx_done   <= 1'b0;
        end
        else begin
            i_tx_done <= 1'b0;
            if (o_wr) begin
                pending_ack <= 1'b1;
            end
            else if (pending_ack) begin
                i_tx_done   <= 1'b1;
                pending_ack <= 1'b0;
            end
        end
    end

    // Build expected byte vector
    task build_expected;
        begin
            // IF/ID
            expected[ 0] = i_ifid_pc[ 7: 0];
            expected[ 1] = i_ifid_pc[15: 8];
            expected[ 2] = i_ifid_pc[23:16];
            expected[ 3] = i_ifid_pc[31:24];
            expected[ 4] = i_ifid_instr[ 7: 0];
            expected[ 5] = i_ifid_instr[15: 8];
            expected[ 6] = i_ifid_instr[23:16];
            expected[ 7] = i_ifid_instr[31:24];
            // ID/EX
            expected[ 8] = i_idex_ctrl[7:0];
            expected[ 9] = {7'b0, i_idex_ctrl[8]};
            expected[10] = i_idex_rs1_data[ 7: 0];
            expected[11] = i_idex_rs1_data[15: 8];
            expected[12] = i_idex_rs1_data[23:16];
            expected[13] = i_idex_rs1_data[31:24];
            expected[14] = i_idex_rs2_data[ 7: 0];
            expected[15] = i_idex_rs2_data[15: 8];
            expected[16] = i_idex_rs2_data[23:16];
            expected[17] = i_idex_rs2_data[31:24];
            expected[18] = i_idex_imm[ 7: 0];
            expected[19] = i_idex_imm[15: 8];
            expected[20] = i_idex_imm[23:16];
            expected[21] = i_idex_imm[31:24];
            expected[22] = {3'b0, i_idex_rd_addr};
            expected[23] = {3'b0, i_idex_rs1_addr};
            expected[24] = {3'b0, i_idex_rs2_addr};
            // EX/MEM
            expected[25] = {4'b0, i_exmem_ctrl};
            expected[26] = i_exmem_alu[ 7: 0];
            expected[27] = i_exmem_alu[15: 8];
            expected[28] = i_exmem_alu[23:16];
            expected[29] = i_exmem_alu[31:24];
            expected[30] = i_exmem_data2[ 7: 0];
            expected[31] = i_exmem_data2[15: 8];
            expected[32] = i_exmem_data2[23:16];
            expected[33] = i_exmem_data2[31:24];
            expected[34] = {3'b0, i_exmem_rd_addr};
            // MEM/WB
            expected[35] = {6'b0, i_memwb_ctrl};
            expected[36] = i_memwb_data[ 7: 0];
            expected[37] = i_memwb_data[15: 8];
            expected[38] = i_memwb_data[23:16];
            expected[39] = i_memwb_data[31:24];
            expected[40] = i_memwb_alu[ 7: 0];
            expected[41] = i_memwb_alu[15: 8];
            expected[42] = i_memwb_alu[23:16];
            expected[43] = i_memwb_alu[31:24];
            expected[44] = {3'b0, i_memwb_rd_addr};
        end
    endtask

    integer k;

    initial begin
        // ---- Initialize ----
        clk             = 0;
        i_rst           = 1;
        i_start         = 0;
        cap_idx         = 0;
        errors          = 0;
        pending_ack     = 0;
        i_tx_done       = 0;

        // Distinct, easy-to-read patterns per field
        i_ifid_pc       = 32'hDEAD_BEEF;
        i_ifid_instr    = 32'h00532663;     // bge t1, t0, +12
        i_idex_ctrl     = 9'b1_01_1_0_0_1_1; // ds=1, alu_op=01, m2r=1, asrc=0, mw=0, mr=1, rw=1
        i_idex_rs1_data = 32'h0000_000A;
        i_idex_rs2_data = 32'h0000_0005;
        i_idex_imm      = 32'h0000_000C;
        i_idex_rd_addr  = 5'd0;
        i_idex_rs1_addr = 5'd6;
        i_idex_rs2_addr = 5'd5;
        i_exmem_ctrl    = 4'b1001;          // m2r=1, mw=0, mr=0, rw=1
        i_exmem_alu     = 32'h0000_000F;
        i_exmem_data2   = 32'hCAFE_BABE;
        i_exmem_rd_addr = 5'd7;
        i_memwb_ctrl    = 2'b01;            // m2r=0, rw=1
        i_memwb_data    = 32'h0000_0000;
        i_memwb_alu     = 32'h0000_000F;
        i_memwb_rd_addr = 5'd7;

        for (k = 0; k < NB_BYTES; k = k + 1) begin
            captured[k] = 8'h00;
            expected[k] = 8'h00;
        end

        // ---- Reset ----
        repeat (4) @(posedge clk);
        i_rst <= 1'b0;
        @(posedge clk);

        // Build expected stream from current input values
        build_expected;

        // ---- Trigger ----
        i_start <= 1'b1;
        @(posedge clk);
        i_start <= 1'b0;

        // ---- Wait for done ----
        wait (o_done);
        @(posedge clk);

        // ---- Verify ----
        if (cap_idx != NB_BYTES) begin
            $display("FAIL: captured %0d/%0d bytes", cap_idx, NB_BYTES);
            errors = errors + 1;
        end

        for (k = 0; k < NB_BYTES; k = k + 1) begin
            if (captured[k] !== expected[k]) begin
                $display("FAIL byte[%0d]: got 0x%02h, expected 0x%02h",
                         k, captured[k], expected[k]);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: 45-byte latch stream matches expected layout.");
        else
            $display("FAIL: %0d errors detected.", errors);

        // Safety guard
        repeat (10) @(posedge clk);
        $finish;
    end

    // Watchdog — total bytes shouldn't take more than ~500 cycles
    initial begin
        #50000;
        $display("FAIL: watchdog — testbench timed out");
        $finish;
    end

endmodule
