`timescale 1ns/1ps

module tb_uart_rx();

    // Parameters
    parameter int                       NB_DATA     = 8                     ;
    parameter int                       SM_TICK     = 16                    ;
    parameter real                      CLK_PERIOD  = 10.0                  ;
    
    // Signals
    logic                               clock                               ;
    logic                               i_rst                               ;
    logic                               i_s_tick                            ;
    logic                               i_rx                                ;
    logic   [NB_DATA           - 1 : 0] o_data                              ;
    logic                               o_rx_done_tick                      ;
    
    // Test variables
    int                                 test_count                          ;
    int                                 error_count                         ;
    logic   [NB_DATA           - 1 : 0] expected_data                       ;
    
    // DUT instantiation
    uart_rx 
    #(
        .NB_DATA        (NB_DATA        ),
        .SM_TICK        (SM_TICK        )
    )
    u_uart_rx
    (
        .o_data         (o_data         ),
        .o_rx_done_tick (o_rx_done_tick ),
        .i_rx           (i_rx           ),
        .i_s_tick       (i_s_tick       ),
        .i_rst          (i_rst          ),
        .clock          (clock          )
    );
    
    // Clock generation
    initial begin
        clock = 1'b0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end
    
    // Sample tick generation - active every cycle
    always @(posedge clock) begin
        if (i_rst)
            i_s_tick <= 1'b0;
        else
            i_s_tick <= 1'b1;
    end
    
    // Main test sequence
    initial begin
        test_count  = 0;
        error_count = 0;
        
        initialize();
        print_header();
        
        test_reset();
        
        test_single_byte();
        
        test_multiple_bytes();
        
        test_all_zeros();
        
        test_all_ones();
        
        test_alternating_pattern();
        
        test_back_to_back();
        
        test_invalid_stop_bit();
        
        print_summary();
        
        repeat(20) @(posedge clock);
        $finish;
    end
    
    // Initialize signals
    task initialize();
        i_rst       = 1'b1;
        i_rx        = 1'b1;
        
        repeat(10) @(posedge clock);
        i_rst = 1'b0;
        repeat(5) @(posedge clock);
    endtask
    
    task test_reset();
        $display("\n[TEST 1] Reset Behavior");
        $display("========================================");
        
        check_condition(o_rx_done_tick == 1'b0, "RX done tick should be low after reset");
        check_condition(o_data == 8'h00, "Output data should be 0 after reset");
        
        $display("[PASS] Reset test completed\n");
    endtask
    
    task test_single_byte();
        $display("\n[TEST 2] Single Byte Reception");
        $display("========================================");
        
        expected_data = 8'hA5;
        
        send_uart_byte(expected_data);
        
        // Wait for transmission to complete (start + 8 data + stop = 10 bits)
        repeat(SM_TICK * 10 + 5) @(posedge clock);
        
        check_data(expected_data, o_data, "Single byte 0xA5");
        
        $display("[PASS] Single byte test completed\n");
    endtask
    
    task test_multiple_bytes();
        $display("\n[TEST 3] Multiple Byte Reception");
        $display("========================================");
        
        for (int i = 0; i < 5; i++) begin
            expected_data = i + 10;
            
            $display("  Sending byte %0d: 0x%02h", i, expected_data);
            send_uart_byte(expected_data);
            
            // Wait for transmission
            repeat(SM_TICK * 10 + 5) @(posedge clock);
            
            check_data(expected_data, o_data, $sformatf("Byte %0d", i));
            
            // Small gap between bytes
            repeat(5) @(posedge clock);
        end
        
        $display("[PASS] Multiple bytes test completed\n");
    endtask
    
    task test_all_zeros();
        $display("\n[TEST 4] All Zeros (0x00)");
        $display("========================================");
        
        expected_data = 8'h00;
        
        send_uart_byte(expected_data);
        repeat(SM_TICK * 10 + 5) @(posedge clock);
        
        check_data(expected_data, o_data, "All zeros");
        
        $display("[PASS] All zeros test completed\n");
    endtask
    
    task test_all_ones();
        $display("\n[TEST 5] All Ones (0xFF)");
        $display("========================================");
        
        expected_data = 8'hFF;
        
        send_uart_byte(expected_data);
        repeat(SM_TICK * 10 + 5) @(posedge clock);
        
        check_data(expected_data, o_data, "All ones");
        
        $display("[PASS] All ones test completed\n");
    endtask
    
    task test_alternating_pattern();
        $display("\n[TEST 6] Alternating Patterns");
        $display("========================================");
        
        // Test 0xAA
        expected_data = 8'hAA;
        send_uart_byte(expected_data);
        repeat(SM_TICK * 10 + 5) @(posedge clock);
        check_data(expected_data, o_data, "Pattern 0xAA");
        repeat(5) @(posedge clock);
        
        // Test 0x55
        expected_data = 8'h55;
        send_uart_byte(expected_data);
        repeat(SM_TICK * 10 + 5) @(posedge clock);
        check_data(expected_data, o_data, "Pattern 0x55");
        
        $display("[PASS] Alternating patterns test completed\n");
    endtask
    
    task test_back_to_back();
        $display("\n[TEST 7] Back-to-Back Bytes");
        $display("========================================");
        
        for (int i = 0; i < 3; i++) begin
            expected_data = 8'h30 + i;
            
            send_uart_byte(expected_data);
            repeat(SM_TICK * 10 + 5) @(posedge clock);
            
            check_data(expected_data, o_data, $sformatf("Back-to-back byte %0d", i));
            
            // Minimal gap
            repeat(3) @(posedge clock);
        end
        
        $display("[PASS] Back-to-back test completed\n");
    endtask
    
    task test_invalid_stop_bit();
        $display("\n[TEST 8] Invalid Stop Bit");
        $display("========================================");
        
        expected_data = 8'h42;
        
        // Send start bit
        i_rx = 1'b0;
        repeat(SM_TICK) @(posedge clock);
        
        // Send data bits (LSB first)
        for (int i = 0; i < NB_DATA; i++) begin
            i_rx = expected_data[i];
            repeat(SM_TICK) @(posedge clock);
        end
        
        // Send invalid stop bit (0 instead of 1)
        i_rx = 1'b0;
        repeat(SM_TICK) @(posedge clock);
        
        // Return to idle
        i_rx = 1'b1;
        repeat(10) @(posedge clock);
        
        check_condition(o_rx_done_tick == 1'b0, "Should not assert done tick on invalid stop bit");
        
        $display("[PASS] Invalid stop bit test completed\n");
    endtask
    
    // Helper task to send a UART byte
    task send_uart_byte(logic [NB_DATA-1:0] data);
        // Idle state
        i_rx = 1'b1;
        repeat(2) @(posedge clock);
        
        // Start bit (0)
        i_rx = 1'b0;
        repeat(SM_TICK) @(posedge clock);
        
        // Data bits (LSB first)
        for (int i = 0; i < NB_DATA; i++) begin
            i_rx = data[i];
            repeat(SM_TICK) @(posedge clock);
        end
        
        // Stop bit (1)
        i_rx = 1'b1;
        repeat(SM_TICK) @(posedge clock);
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
        $display("            UART RX Testbench (SystemVerilog)              ");
        $display("============================================================");
        $display("NB_DATA:             %0d bits", NB_DATA);
        $display("SM_TICK:             %0d (oversampling)", SM_TICK);
        $display("Clock Period:        %.2f ns", CLK_PERIOD);
        $display("Bit Period:          %.2f ns", CLK_PERIOD * SM_TICK);
        $display("Frame time:          %.2f ns (10 bits)", CLK_PERIOD * SM_TICK * 10);
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
    
    // Monitor for debugging
    always @(posedge o_rx_done_tick) begin
        $display("    [%0t] RX Done! Data: 0x%02h", $time, o_data);
    end
    
    // VCD dump
    initial begin
        $dumpfile("tb_uart_rx.vcd");
        $dumpvars(0, tb_uart_rx);
    end
    
endmodule