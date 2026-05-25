//! @title TESTBENCH - DEBUG UNIT HARDWARE BREAKPOINT
//! @file tb_du_breakpoint.v

`timescale 1ns / 1ps

module tb_du_breakpoint;

    // Parameters
    localparam NB_DATA    = 32;
    localparam N_BKP      = 4;
    localparam CLK_PERIOD = 10;

    // DUT signals
    reg                     clk;
    reg                     i_rst;
    reg  [NB_DATA - 1 : 0] i_pc;
    reg                     i_set;
    reg                     i_clr;
    reg  [NB_DATA - 1 : 0] i_bkp_addr;
    wire                    o_bkp_hit;

    integer errors;

    // DUT instantiation
    du_breakpoint #(
        .NB_DATA (NB_DATA),
        .N_BKP   (N_BKP)
    ) dut (
        .o_bkp_hit  (o_bkp_hit),
        .i_pc       (i_pc),
        .i_set      (i_set),
        .i_clr      (i_clr),
        .i_bkp_addr (i_bkp_addr),
        .i_rst      (i_rst),
        .clk        (clk)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Task: set breakpoint (drive on negedge to avoid race with DUT posedge)
    task set_bkp;
        input [NB_DATA - 1 : 0] addr;
        begin
            @(negedge clk);
            i_set      = 1'b1;
            i_bkp_addr = addr;
            @(negedge clk);
            i_set      = 1'b0;
        end
    endtask

    // Task: clear breakpoint (drive on negedge to avoid race with DUT posedge)
    task clr_bkp;
        input [NB_DATA - 1 : 0] addr;
        begin
            @(negedge clk);
            i_clr      = 1'b1;
            i_bkp_addr = addr;
            @(negedge clk);
            i_clr      = 1'b0;
        end
    endtask

    // Main test
    initial begin
        $dumpfile("tb_du_breakpoint.vcd");
        $dumpvars(0, tb_du_breakpoint);

        errors     = 0;
        i_rst      = 1'b1;
        i_pc       = 32'h0;
        i_set      = 1'b0;
        i_clr      = 1'b0;
        i_bkp_addr = 32'h0;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;
        #(CLK_PERIOD * 2);

        // Test 1: No breakpoints set — no hit
        $display("\n--- Test 1: No breakpoints, PC=0x100 ---");
        i_pc = 32'h00000100;
        @(posedge clk);
        if (o_bkp_hit !== 1'b0) begin
            $display("ERROR: Expected no hit, got hit");
            errors = errors + 1;
        end
        else $display("OK: No hit as expected");

        // Test 2: Set breakpoint at 0x200, check hit
        $display("\n--- Test 2: Set bkp at 0x200 ---");
        set_bkp(32'h00000200);

        i_pc = 32'h00000200;
        #1;  // combinational settle
        if (o_bkp_hit !== 1'b1) begin
            $display("ERROR: Expected hit at 0x200");
            errors = errors + 1;
        end
        else $display("OK: Hit at 0x200");

        // Test 3: Different PC — no hit
        $display("\n--- Test 3: PC=0x204, should not hit ---");
        i_pc = 32'h00000204;
        #1;
        if (o_bkp_hit !== 1'b0) begin
            $display("ERROR: Unexpected hit at 0x204");
            errors = errors + 1;
        end
        else $display("OK: No hit at 0x204");

        // Test 4: Set multiple breakpoints
        $display("\n--- Test 4: Set 3 more breakpoints ---");
        set_bkp(32'h00000300);
        set_bkp(32'h00000400);
        set_bkp(32'h00000500);

        i_pc = 32'h00000400;
        #1;
        if (o_bkp_hit !== 1'b1) begin
            $display("ERROR: Expected hit at 0x400");
            errors = errors + 1;
        end
        else $display("OK: Hit at 0x400");

        // Test 5: Clear breakpoint at 0x200, verify no hit
        $display("\n--- Test 5: Clear bkp at 0x200 ---");
        clr_bkp(32'h00000200);

        i_pc = 32'h00000200;
        #1;
        if (o_bkp_hit !== 1'b0) begin
            $display("ERROR: Hit after clear at 0x200");
            errors = errors + 1;
        end
        else $display("OK: No hit after clear");

        // Test 6: Other breakpoints still active
        $display("\n--- Test 6: 0x300 still active ---");
        i_pc = 32'h00000300;
        #1;
        if (o_bkp_hit !== 1'b1) begin
            $display("ERROR: Expected hit at 0x300");
            errors = errors + 1;
        end
        else $display("OK: Hit at 0x300");

        // Test 7: Overflow — try to set 5th breakpoint (only 4 slots)
        $display("\n--- Test 7: Set bkp with freed slot ---");
        set_bkp(32'h00000600);  // Should take slot freed by 0x200

        i_pc = 32'h00000600;
        #1;
        if (o_bkp_hit !== 1'b1) begin
            $display("ERROR: Expected hit at 0x600");
            errors = errors + 1;
        end
        else $display("OK: Hit at 0x600 (reused slot)");

        #(CLK_PERIOD * 5);
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
