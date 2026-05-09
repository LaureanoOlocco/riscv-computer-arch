//! @title TESTBENCH - DEBUG UNIT MASTER CONTROLLER
//! @file tb_du_master.v
//! @brief Tests the new interactive command protocol with 6-byte frames.
//!        Simulates UART byte-by-byte communication.

`timescale 1ns / 1ps

module tb_du_master;

    // Parameters
    localparam NB_UART_DATA = 8;
    localparam NB_DATA      = 32;
    localparam NB_ADDR      = 8;
    localparam CLK_PERIOD   = 10;

    // DUT signals
    reg                         clk;
    reg                         i_rst;
    reg                         i_rx_done;
    reg  [NB_UART_DATA - 1 : 0] i_rx_data;
    reg                         i_imem_loader_done;
    reg                         i_regfile_tx_done;
    reg                         i_dmem_tx_done;
    reg                         i_regfile_rx_done;
    reg                         i_dmem_rx_done;
    reg  [NB_DATA - 1 : 0]     i_pc;
    reg  [NB_DATA - 1 : 0]     i_instruction;
    reg  [NB_DATA - 1 : 0]     i_regfile_data;
    reg  [NB_DATA - 1 : 0]     i_mem_data;
    reg                         i_bkp_hit;

    wire                        o_cpu_enable;
    wire                        o_cpu_reset;
    wire                        o_imem_loader_start;
    wire                        o_regfile_tx_start;
    wire                        o_dmem_tx_start;
    wire                        o_regfile_rd;
    wire [4 : 0]               o_regfile_raddr;
    wire                        o_regfile_rx_start;
    wire [4 : 0]               o_regfile_rx_addr;
    wire                        o_dmem_rx_start;
    wire [NB_DATA - 1 : 0]    o_dmem_rx_addr;
    wire                        o_mem_rd;
    wire [NB_ADDR - 1 : 0]    o_mem_raddr;
    wire                        o_bkp_set;
    wire                        o_bkp_clr;
    wire [NB_DATA - 1 : 0]    o_bkp_addr;
    wire                        o_resp_valid;
    wire [NB_UART_DATA - 1 : 0] o_resp_status;
    wire [NB_DATA - 1 : 0]    o_resp_data;

    integer errors;

    // DUT instantiation
    du_master #(
        .NB_UART_DATA (NB_UART_DATA),
        .NB_DATA      (NB_DATA),
        .NB_ADDR      (NB_ADDR),
        .NB_STATE     (17),
        .NB_STEP_CNT  (32)
    ) dut (
        .o_cpu_enable        (o_cpu_enable),
        .o_cpu_reset         (o_cpu_reset),
        .o_imem_loader_start (o_imem_loader_start),
        .o_regfile_tx_start  (o_regfile_tx_start),
        .o_dmem_tx_start     (o_dmem_tx_start),
        .o_regfile_rd        (o_regfile_rd),
        .o_regfile_raddr     (o_regfile_raddr),
        .o_regfile_rx_start  (o_regfile_rx_start),
        .o_regfile_rx_addr   (o_regfile_rx_addr),
        .o_dmem_rx_start     (o_dmem_rx_start),
        .o_dmem_rx_addr      (o_dmem_rx_addr),
        .o_mem_rd            (o_mem_rd),
        .o_mem_raddr         (o_mem_raddr),
        .o_bkp_set           (o_bkp_set),
        .o_bkp_clr           (o_bkp_clr),
        .o_bkp_addr          (o_bkp_addr),
        .o_resp_valid        (o_resp_valid),
        .o_resp_status       (o_resp_status),
        .o_resp_data         (o_resp_data),
        .i_imem_loader_done  (i_imem_loader_done),
        .i_regfile_tx_done   (i_regfile_tx_done),
        .i_dmem_tx_done      (i_dmem_tx_done),
        .i_regfile_rx_done   (i_regfile_rx_done),
        .i_dmem_rx_done      (i_dmem_rx_done),
        .i_pc                (i_pc),
        .i_instruction       (i_instruction),
        .i_regfile_data      (i_regfile_data),
        .i_mem_data          (i_mem_data),
        .i_bkp_hit           (i_bkp_hit),
        .i_rx_done           (i_rx_done),
        .i_rx_data           (i_rx_data),
        .i_rst               (i_rst),
        .clk                 (clk)
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
    //   opcode, payload[31:0] (little-endian), checksum
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

    // Task: send command with BAD checksum
    task send_cmd_bad;
        input [7 : 0]  opcode;
        input [31 : 0] payload;
        begin
            send_byte(opcode);
            send_byte(payload[7 : 0]);
            send_byte(payload[15 : 8]);
            send_byte(payload[23 : 16]);
            send_byte(payload[31 : 24]);
            send_byte(8'hFF);  // bad checksum
        end
    endtask

    // Task: wait for resp_valid
    task wait_resp;
        begin
            @(posedge o_resp_valid);
            @(posedge clk);
        end
    endtask

    // Main test
    initial begin
        $dumpfile("tb_du_master.vcd");
        $dumpvars(0, tb_du_master);

        errors             = 0;
        i_rst              = 1'b1;
        i_rx_done          = 1'b0;
        i_rx_data          = 8'h00;
        i_imem_loader_done = 1'b0;
        i_regfile_tx_done  = 1'b0;
        i_dmem_tx_done     = 1'b0;
        i_regfile_rx_done  = 1'b0;
        i_dmem_rx_done     = 1'b0;
        i_pc               = 32'h00000000;
        i_instruction      = 32'h00000013;  // NOP
        i_regfile_data     = 32'h0;
        i_mem_data         = 32'h0;
        i_bkp_hit          = 1'b0;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 5);

        // =====================================================
        // Test 1: CMD_STATUS (0x0F) — check idle state
        // =====================================================
        $display("\n--- Test 1: CMD_STATUS ---");
        send_cmd(8'h0F, 32'h00000000);

        // Wait for VALIDATE + DISPATCH + RESPOND
        #(CLK_PERIOD * 5);
        wait_resp;

        if (o_resp_status == 8'h00 && o_resp_data == 32'h00000000) begin
            $display("OK: STATUS = 0x%08h (idle, not running)", o_resp_data);
        end
        else begin
            $display("ERROR: STATUS response: status=0x%02h, data=0x%08h",
                     o_resp_status, o_resp_data);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 2: CMD_HALT (0x04) — halt while idle
        // =====================================================
        $display("\n--- Test 2: CMD_HALT ---");
        i_pc = 32'h00000040;
        send_cmd(8'h04, 32'h00000000);

        #(CLK_PERIOD * 5);
        wait_resp;

        if (o_resp_status == 8'h00 && o_resp_data == 32'h00000040) begin
            $display("OK: HALT, PC=0x%08h", o_resp_data);
        end
        else begin
            $display("ERROR: HALT response: status=0x%02h, data=0x%08h",
                     o_resp_status, o_resp_data);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 3: CMD_STEP (0x03) — single step (N=1)
        // =====================================================
        $display("\n--- Test 3: CMD_STEP N=1 ---");
        i_pc = 32'h00000044;
        send_cmd(8'h03, 32'h00000001);

        // Wait for stepping to complete (4 cycles per step)
        #(CLK_PERIOD * 20);
        wait_resp;

        if (o_resp_status == 8'h00) begin
            $display("OK: STEP done, PC=0x%08h", o_resp_data);
        end
        else begin
            $display("ERROR: STEP response: status=0x%02h, data=0x%08h",
                     o_resp_status, o_resp_data);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 4: CMD_SET_BKP (0x09) — set breakpoint
        // =====================================================
        $display("\n--- Test 4: CMD_SET_BKP at 0x100 ---");
        send_cmd(8'h09, 32'h00000100);

        #(CLK_PERIOD * 5);
        wait_resp;

        if (o_resp_status == 8'h00) begin
            $display("OK: Breakpoint set");
        end
        else begin
            $display("ERROR: SET_BKP response: status=0x%02h", o_resp_status);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 5: CMD_RESET (0x0B) — CPU reset
        // =====================================================
        $display("\n--- Test 5: CMD_RESET ---");
        send_cmd(8'h0B, 32'h00000000);

        #(CLK_PERIOD * 5);
        wait_resp;

        if (o_resp_status == 8'h00) begin
            $display("OK: Reset done");
        end
        else begin
            $display("ERROR: RESET response: status=0x%02h", o_resp_status);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 6: Bad checksum — should get ERROR response
        // =====================================================
        $display("\n--- Test 6: Bad checksum ---");
        send_cmd_bad(8'h0F, 32'h00000000);

        #(CLK_PERIOD * 5);
        wait_resp;

        if (o_resp_status == 8'h01) begin
            $display("OK: Checksum error detected");
        end
        else begin
            $display("ERROR: Expected ERROR status, got 0x%02h", o_resp_status);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 7: CMD_READ_REG (0x05) — read register 10
        // =====================================================
        $display("\n--- Test 7: CMD_READ_REG x10 ---");
        i_regfile_data = 32'hABCD1234;
        send_cmd(8'h05, 32'h0000000A);

        // Wait for read delay
        #(CLK_PERIOD * 10);
        wait_resp;

        if (o_resp_status == 8'h00 && o_resp_data == 32'hABCD1234) begin
            $display("OK: Read x10 = 0x%08h", o_resp_data);
        end
        else begin
            $display("ERROR: READ_REG response: status=0x%02h, data=0x%08h",
                     o_resp_status, o_resp_data);
            errors = errors + 1;
        end

        #(CLK_PERIOD * 10);

        // =====================================================
        // Test 8: CMD_READ_MEM (0x06) — read memory at 0x20
        // =====================================================
        $display("\n--- Test 8: CMD_READ_MEM [0x20] ---");
        i_mem_data = 32'hFEDCBA98;
        send_cmd(8'h06, 32'h00000020);

        #(CLK_PERIOD * 10);
        wait_resp;

        if (o_resp_status == 8'h00 && o_resp_data == 32'hFEDCBA98) begin
            $display("OK: Read [0x20] = 0x%08h", o_resp_data);
        end
        else begin
            $display("ERROR: READ_MEM response: status=0x%02h, data=0x%08h",
                     o_resp_status, o_resp_data);
            errors = errors + 1;
        end

        // Summary
        #(CLK_PERIOD * 10);
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
