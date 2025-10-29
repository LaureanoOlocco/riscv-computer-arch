`timescale 1ns/1ps

module tb_fifo();

    // Parameters
    parameter int                       NB_DATA     = 8                     ;
    parameter int                       NB_ADDRESS  = 4                     ;
    parameter real                      CLK_PERIOD  = 10.0                  ;
    
    localparam int                      FIFO_DEPTH  = 2**NB_ADDRESS         ;
    
    // Signals
    logic                               clock                               ;
    logic                               i_rst                               ;
    logic                               i_wr                                ;
    logic                               i_rd                                ;
    logic   [NB_DATA           - 1 : 0] i_data                              ;
    logic   [NB_DATA           - 1 : 0] o_data                              ;
    logic                               o_empty_flag                        ;
    logic                               o_full_flag                         ;
    
    // Test variables
    int                                 test_count                          ;
    int                                 error_count                         ;
    logic   [NB_DATA           - 1 : 0] expected_data                       ;
    
    // DUT instantiation
    fifo 
    #(
        .NB_DATA        (NB_DATA        ),
        .NB_ADDRESS     (NB_ADDRESS     )
    )
    u_fifo
    (
        .o_data         (o_data         ),
        .o_empty_flag   (o_empty_flag   ),
        .o_full_flag    (o_full_flag    ),
        .i_rd           (i_rd           ),
        .i_wr           (i_wr           ),
        .i_data         (i_data         ),
        .i_rst          (i_rst          ),
        .clock          (clock          )
    );
    
    // Clock generation
    initial begin
        clock = 1'b0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end
    
    // Main test sequence
    initial begin
        test_count  = 0;
        error_count = 0;
        
        initialize();
        print_header();
        
        test_reset();
        reset_fifo();
        
        test_single_write_read();
        reset_fifo();
        
        test_fill_fifo();
        reset_fifo();
        
        test_empty_fifo();
        reset_fifo();
        
        test_simultaneous_rw();
        reset_fifo();
        
        test_write_when_full();
        reset_fifo();
        
        test_read_when_empty();
        reset_fifo();
        
        test_sequential_operations();
        reset_fifo();
        
        test_burst_operations();
        
        print_summary();
        
        repeat(10) @(posedge clock);
        $finish;
    end
    
    // Initialize signals
    task initialize();
        i_rst       = 1'b1;
        i_wr        = 1'b0;
        i_rd        = 1'b0;
        i_data      = '0;
        
        repeat(5) @(posedge clock);
        i_rst = 1'b0;
        repeat(2) @(posedge clock);
    endtask
    
    // Reset FIFO between tests
    task reset_fifo();
        i_wr = 1'b0;
        i_rd = 1'b0;
        i_rst = 1'b1;
        repeat(3) @(posedge clock);
        i_rst = 1'b0;
        repeat(2) @(posedge clock);
    endtask
    
    task test_reset();
        $display("\n[TEST 1] Reset Behavior");
        $display("========================================");
        
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty after reset");
        check_condition(o_full_flag == 1'b0, "FIFO should not be full after reset");
        
        $display("[PASS] Reset test completed\n");
    endtask
    
    task test_single_write_read();
        logic [NB_DATA-1:0] test_value;
        
        $display("\n[TEST 2] Single Write and Read");
        $display("========================================");
        
        test_value = 8'hA5;
        
        // Write
        @(posedge clock);
        i_wr    = 1'b1;
        i_data  = test_value;
        
        @(posedge clock);
        i_wr = 1'b0;
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b0, "FIFO should not be empty after write");
        
        // Read
        i_rd = 1'b1;
        
        @(posedge clock);
        check_data(test_value, o_data, "Single write/read");
        i_rd = 1'b0;
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty after read");
        
        $display("[PASS] Single write/read test completed\n");
    endtask
    
    task test_fill_fifo();
        $display("\n[TEST 3] Fill FIFO Completely");
        $display("========================================");
        
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i;
            
            @(posedge clock);
            i_wr = 1'b0;
            
            if (i < FIFO_DEPTH - 1) begin
                @(posedge clock);
                check_condition(o_full_flag == 1'b0, 
                    $sformatf("FIFO should not be full at %0d/%0d", i+1, FIFO_DEPTH));
            end
        end
        
        @(posedge clock);
        check_condition(o_full_flag == 1'b1, "FIFO should be full");
        check_condition(o_empty_flag == 1'b0, "FIFO should not be empty when full");
        
        $display("[PASS] Fill FIFO test completed\n");
    endtask
    
    task test_empty_fifo();
        $display("\n[TEST 4] Empty FIFO Completely");
        $display("========================================");
        
        // First fill it
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i;
            @(posedge clock);
            i_wr = 1'b0;
        end
        
        @(posedge clock);
        
        // Now read all
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            
            @(posedge clock);
            check_data(i[NB_DATA-1:0], o_data, $sformatf("Read %0d/%0d", i+1, FIFO_DEPTH));
            i_rd = 1'b0;
        end
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty");
        check_condition(o_full_flag == 1'b0, "FIFO should not be full when empty");
        
        $display("[PASS] Empty FIFO test completed\n");
    endtask
    
    task test_simultaneous_rw();
        logic [NB_DATA-1:0] wr_val;
        
        $display("\n[TEST 5] Simultaneous Read/Write");
        $display("========================================");
        
        // Fill FIFO halfway first
        for (int i = 0; i < FIFO_DEPTH/2; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i + 100;
            @(posedge clock);
            i_wr = 1'b0;
        end
        
        @(posedge clock);
        
        // Simultaneous operations
        for (int i = 0; i < 5; i++) begin
            wr_val = i + 200;
            
            @(posedge clock);
            i_wr    = 1'b1;
            i_rd    = 1'b1;
            i_data  = wr_val;
            
            @(posedge clock);
            expected_data = (i + 100);
            check_data(expected_data, o_data, $sformatf("Simultaneous R/W %0d", i));
            
            i_wr = 1'b0;
            i_rd = 1'b0;
        end
        
        // Empty remaining data
        for (int i = 5; i < FIFO_DEPTH/2; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 100);
            check_data(expected_data, o_data, $sformatf("Cleanup %0d", i));
            i_rd = 1'b0;
        end
        
        // Read the simultaneously written data
        for (int i = 0; i < 5; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 200);
            check_data(expected_data, o_data, $sformatf("Simultaneous written %0d", i));
            i_rd = 1'b0;
        end
        
        $display("[PASS] Simultaneous R/W test completed\n");
    endtask
    
    task test_write_when_full();
        logic [NB_DATA-1:0] overflow_data;
        
        $display("\n[TEST 6] Write When Full");
        $display("========================================");
        
        // Fill FIFO
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i + 50;
            @(posedge clock);
            i_wr = 1'b0;
        end
        
        @(posedge clock);
        check_condition(o_full_flag == 1'b1, "FIFO should be full");
        
        // Try to write when full
        overflow_data = 8'hFF;
        @(posedge clock);
        i_wr    = 1'b1;
        i_data  = overflow_data;
        
        @(posedge clock);
        i_wr = 1'b0;
        
        check_condition(o_full_flag == 1'b1, "FIFO should remain full");
        $display("Write to full FIFO ignored (expected behavior)");
        
        // Verify data integrity by reading all
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 50);
            check_data(expected_data, o_data, $sformatf("Data integrity check %0d", i));
            i_rd = 1'b0;
        end
        
        $display("[PASS] Write when full test completed\n");
    endtask
    
    task test_read_when_empty();
        $display("\n[TEST 7] Read When Empty");
        $display("========================================");
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty");
        
        // Try to read when empty
        @(posedge clock);
        i_rd = 1'b1;
        
        @(posedge clock);
        i_rd = 1'b0;
        
        check_condition(o_empty_flag == 1'b1, "FIFO should remain empty");
        $display("Read from empty FIFO ignored (expected behavior)");
        
        $display("[PASS] Read when empty test completed\n");
    endtask
    
    task test_sequential_operations();
        $display("\n[TEST 8] Sequential Write/Read Operations");
        $display("========================================");
        
        // Write 8 values
        for (int i = 0; i < 8; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i + 10;
            @(posedge clock);
            i_wr = 1'b0;
            $display("  Wrote: 0x%02h", i + 10);
        end
        
        @(posedge clock);
        
        // Read 4 values
        for (int i = 0; i < 4; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 10);
            check_data(expected_data, o_data, $sformatf("Read %0d", i));
            i_rd = 1'b0;
        end
        
        // Write 4 more values
        for (int i = 0; i < 4; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i + 20;
            @(posedge clock);
            i_wr = 1'b0;
            $display("  Wrote: 0x%02h", i + 20);
        end
        
        // Read remaining 8 values
        for (int i = 4; i < 8; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 10);
            check_data(expected_data, o_data, $sformatf("Read %0d", i));
            i_rd = 1'b0;
        end
        
        for (int i = 0; i < 4; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 20);
            check_data(expected_data, o_data, $sformatf("Read %0d", i + 8));
            i_rd = 1'b0;
        end
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty");
        
        $display("[PASS] Sequential operations test completed\n");
    endtask
    
    task test_burst_operations();
        $display("\n[TEST 9] Burst Write and Burst Read");
        $display("========================================");
        
        // Burst write
        $display("Burst writing %0d words...", FIFO_DEPTH);
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_wr    = 1'b1;
            i_data  = i + 200;
            @(posedge clock);
            i_wr = 1'b0;
        end
        
        @(posedge clock);
        check_condition(o_full_flag == 1'b1, "FIFO should be full after burst write");
        
        // Burst read
        $display("Burst reading %0d words...", FIFO_DEPTH);
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge clock);
            i_rd = 1'b1;
            @(posedge clock);
            expected_data = (i + 200);
            check_data(expected_data, o_data, $sformatf("Burst read %0d", i));
            i_rd = 1'b0;
        end
        
        @(posedge clock);
        check_condition(o_empty_flag == 1'b1, "FIFO should be empty after burst read");
        
        $display("[PASS] Burst operations test completed\n");
    endtask
    
    task check_condition(bit condition, string msg);
        test_count++;
        if (condition) begin
            $display("  [✓] %s", msg);
        end else begin
            $display("  [✗] %s", msg);
            error_count++;
        end
    endtask
    
    task check_data(logic [NB_DATA-1:0] expected, logic [NB_DATA-1:0] actual, string msg);
        test_count++;
        if (expected == actual) begin
            $display("  [✓] %s: Expected=0x%02h, Got=0x%02h", msg, expected, actual);
        end else begin
            $display("  [✗] %s: Expected=0x%02h, Got=0x%02h", msg, expected, actual);
            error_count++;
        end
    endtask
    
    function void print_header();
        $display("\n============================================================");
        $display("              FIFO Testbench (SystemVerilog)               ");
        $display("============================================================");
        $display("NB_DATA:             %0d bits", NB_DATA);
        $display("NB_ADDRESS:          %0d bits", NB_ADDRESS);
        $display("FIFO Depth:          %0d words", FIFO_DEPTH);
        $display("Clock Period:        %.2f ns", CLK_PERIOD);
        $display("============================================================");
    endfunction
    
    function void print_summary();
        $display("\n============================================================");
        $display("                      Test Summary                         ");
        $display("============================================================");
        $display("Total checks:        %0d", test_count);
        $display("Passed:              %0d", test_count - error_count);
        $display("Failed:              %0d", error_count);
        $display("Status:              %s", (error_count == 0) ? "PASSED ✓" : "FAILED ✗");
        $display("============================================================\n");
    endfunction
    
    // Assertions
    property mutex_flags;
        @(posedge clock) disable iff (i_rst)
        !(o_empty_flag && o_full_flag);
    endproperty
    assert_mutex_flags: assert property(mutex_flags)
    else $error("[%0t] Empty and full flags are both high!", $time);
    
    // Coverage
    covergroup cg_fifo @(posedge clock);
        option.per_instance = 1;
        cp_write: coverpoint i_wr;
        cp_read: coverpoint i_rd;
        cp_empty: coverpoint o_empty_flag;
        cp_full: coverpoint o_full_flag;
        cross_ops: cross cp_write, cp_read;
    endgroup
    
    cg_fifo cg_inst = new();
    
    initial begin
        #500000;
        $display("\n[TIMEOUT] Simulation exceeded maximum time");
        $finish;
    end
    
endmodule