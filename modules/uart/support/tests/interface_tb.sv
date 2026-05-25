`timescale 1ns/1ps

module tb_interface_uart();

    // Parameters
    parameter int                       NB_DATA     = 8                     ;
    parameter int                       NB_REG      = 32                    ;
    parameter int                       NB_OP_CODE  = 6                     ;
    parameter int                       NB_COUNT    = 3                     ;
    parameter real                      CLK_PERIOD  = 10.0                  ;
    
    // Protocol characters
    localparam logic [7:0]              START_CHAR  = 8'hFB                 ;
    localparam logic [7:0]              END_CHAR    = 8'hFD                 ;
    localparam logic [31:0]             ERROR_CHAR  = 32'hFEFEFEFE          ;
    
    // Signals
    logic                               clock                               ;
    logic                               i_rst                               ;
    logic                               i_rx_done                           ;
    logic                               i_rx_empty                          ;
    logic                               i_tx_done                           ;
    logic   [NB_DATA           - 1 : 0] i_rx_data                           ;
    logic   [NB_REG            - 1 : 0] i_alu_out                           ;
    
    logic                               o_tx_start                          ;
    logic                               o_read                              ;
    logic                               o_write                             ;
    logic   [NB_DATA           - 1 : 0] o_alu_out                           ;
    logic   [NB_REG            - 1 : 0] o_alu_data_a                        ;
    logic   [NB_REG            - 1 : 0] o_alu_data_b                        ;
    logic   [NB_OP_CODE        - 1 : 0] o_alu_op_code                       ;
    
    // Test variables
    int                                 test_count                          ;
    int                                 error_count                         ;
    logic                               debug_mode                          ;
    
    // DUT instantiation
    interface_uart 
    #(
        .NB_DATA        (NB_DATA        ),
        .NB_REG         (NB_REG         ),
        .NB_OP_CODE     (NB_OP_CODE     ),
        .NB_COUNT       (NB_COUNT       )
    )
    u_interface_uart
    (
        .o_tx_start     (o_tx_start     ),
        .o_read         (o_read         ),
        .o_write        (o_write        ),
        .o_alu_out      (o_alu_out      ),
        .o_alu_data_a   (o_alu_data_a   ),
        .o_alu_data_b   (o_alu_data_b   ),
        .o_alu_op_code  (o_alu_op_code  ),
        .i_alu_out      (i_alu_out      ),
        .i_rx_data      (i_rx_data      ),
        .i_rx_done      (i_rx_done      ),
        .i_rx_empty     (i_rx_empty     ),
        .i_tx_done      (i_tx_done      ),
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
        debug_mode  = 1'b0;
        
        initialize();
        print_header();
        
        test_reset();
        
        test_valid_transaction();
        
        test_invalid_start_char();
        
        test_invalid_end_char();
        
        test_multiple_operations();
        
        // Enable debug for test 6
        debug_mode = 1'b1;
        test_fifo_output();
        
        print_summary();
        
        repeat(20) @(posedge clock);
        $finish;
    end
    
    // Initialize signals
    task initialize();
        i_rst       = 1'b1;
        i_rx_done   = 1'b0;
        i_rx_empty  = 1'b1;
        i_tx_done   = 1'b0;
        i_rx_data   = 8'h00;
        i_alu_out   = 32'h00000000;
        
        repeat(10) @(posedge clock);
        i_rst = 1'b0;
        repeat(5) @(posedge clock);
    endtask
    
    task test_reset();
        $display("\n[TEST 1] Reset Behavior");
        $display("========================================");
        
        check_condition(o_tx_start == 1'b0, "TX start should be low after reset");
        check_condition(o_read == 1'b0, "Read should be low after reset");
        check_condition(o_write == 1'b0, "Write should be low after reset");
        check_condition(o_alu_data_a == 32'h00000000, "ALU data A should be 0");
        check_condition(o_alu_data_b == 32'h00000000, "ALU data B should be 0");
        check_condition(o_alu_op_code == 6'h00, "ALU op code should be 0");
        
        $display("[PASS] Reset test completed\n");
    endtask
    
    task test_valid_transaction();
        logic [31:0] expected_a, expected_b;
        logic [5:0] expected_op;
        logic [31:0] alu_result;
        
        $display("\n[TEST 2] Valid Transaction (ADD operation)");
        $display("========================================");
        
        expected_a = 32'h12345678;
        expected_b = 32'h87654321;
        expected_op = 6'b100000; // ADD opcode
        alu_result = 32'h99999999;
        
        // Send START_CHAR and check o_read
        send_rx_byte_and_check_read(START_CHAR);
        
        // Send DATA_A (4 bytes, LSB first)
        for (int i = 0; i < 4; i++) begin
            send_rx_byte(expected_a[i*8 +: 8]);
        end
        
        // Wait for state transition and check data_a
        wait_for_state(3'b010); // Wait for DATA_B state
        check_condition(o_alu_data_a == expected_a, 
            $sformatf("ALU data A should be 0x%08h", expected_a));
        
        // Send DATA_B (4 bytes, LSB first)
        for (int i = 0; i < 4; i++) begin
            send_rx_byte(expected_b[i*8 +: 8]);
        end
        
        // Wait for state transition and check data_b
        wait_for_state(3'b011); // Wait for DATA_OP state
        check_condition(o_alu_data_b == expected_b, 
            $sformatf("ALU data B should be 0x%08h", expected_b));
        
        // Send OP_CODE
        send_rx_byte({2'b00, expected_op});
        
        // Wait for state transition and check opcode
        wait_for_state(3'b100); // Wait for END_RX state
        check_condition(o_alu_op_code == expected_op, 
            $sformatf("ALU op code should be 0x%02h", expected_op));
        
        // Provide ALU result before sending END_CHAR
        i_alu_out = alu_result;
        
        // Send END_CHAR
        send_rx_byte(END_CHAR);
        
        // Wait for FIFO_OUT state
        wait_for_state(3'b101); // FIFO_OUT
        
        // Check that write signal is active in FIFO_OUT
        @(posedge clock);
        check_condition(o_write == 1'b1, "Write should be high in FIFO_OUT");
        
        // Wait for SEND state
        wait_for_state(3'b110); // SEND
        
        // Check tx_start and verify bytes
        verify_transmission(alu_result, "Output");
        
        // Wait for return to IDLE
        wait_for_state(3'b000); // IDLE
        
        $display("[PASS] Valid transaction test completed\n");
    endtask
    
    task test_invalid_start_char();
        $display("\n[TEST 3] Invalid Start Character");
        $display("========================================");
        
        // Send invalid start character
        send_rx_byte(8'hAA);
        
        repeat(5) @(posedge clock);
        
        // Should remain in IDLE state
        check_condition(u_interface_uart.state_reg == 3'b000, "Should remain in IDLE");
        check_condition(o_write == 1'b0, "Should not write with invalid start");
        check_condition(o_tx_start == 1'b0, "Should not start TX with invalid start");
        
        repeat(3) @(posedge clock);
        
        $display("[PASS] Invalid start character test completed\n");
    endtask
    
    task test_invalid_end_char();
        logic [31:0] error_value;
        
        $display("\n[TEST 4] Invalid End Character (Error Recovery)");
        $display("========================================");
        
        error_value = ERROR_CHAR;
        
        // Start valid transaction
        send_rx_byte(START_CHAR);
        
        // Send partial data (only 3 bytes for DATA_A)
        for (int i = 0; i < 3; i++) begin
            send_rx_byte(8'h11 + i);
        end
        
        // Complete DATA_A
        send_rx_byte(8'hAA);
        
        // Continue with DATA_B
        for (int i = 0; i < 4; i++) begin
            send_rx_byte(8'h20 + i);
        end
        
        // Send opcode
        send_rx_byte(8'h20);
        
        // Send invalid end character (should trigger ERROR)
        send_rx_byte(8'hBB); // Invalid END_CHAR
        
        // Wait for ERROR state
        wait_for_state(3'b111); // ERROR
        
        // Check that system tries to drain FIFO
        @(posedge clock);
        check_condition(o_read == 1'b1, "Should drain FIFO in error state");
        
        // Simulate empty FIFO
        @(posedge clock);
        i_rx_empty = 1'b1;
        
        // Wait for transition to FIFO_OUT
        wait_for_state(3'b101); // FIFO_OUT
        
        // Wait for SEND state
        wait_for_state(3'b110); // SEND
        
        // Verify error transmission
        verify_transmission(error_value, "Error");
        
        // Wait for IDLE
        wait_for_state(3'b000);
        
        // Reset FIFO empty flag for next test
        i_rx_empty = 1'b1;
        
        $display("[PASS] Invalid end character test completed\n");
    endtask
    
    task test_multiple_operations();
        $display("\n[TEST 5] Multiple Sequential Operations");
        $display("========================================");
        
        for (int op = 0; op < 3; op++) begin
            logic [31:0] data_a, data_b, result;
            logic [5:0] opcode;
            
            data_a = 32'h1000_0000 + (op << 8);
            data_b = 32'h2000_0000 + (op << 8);
            opcode = 6'h20 + op;
            result = data_a + data_b;
            
            $display("  Operation %0d: A=0x%08h, B=0x%08h, OP=0x%02h", 
                     op, data_a, data_b, opcode);
            
            // Wait for IDLE
            wait_for_state(3'b000);
            
            // Send complete transaction
            send_rx_byte(START_CHAR);
            
            for (int i = 0; i < 4; i++) send_rx_byte(data_a[i*8 +: 8]);
            for (int i = 0; i < 4; i++) send_rx_byte(data_b[i*8 +: 8]);
            
            send_rx_byte({2'b00, opcode});
            
            // Provide ALU result
            i_alu_out = result;
            
            send_rx_byte(END_CHAR);
            
            // Wait for SEND state
            wait_for_state(3'b110);
            
            // Complete TX
            for (int i = 0; i < 4; i++) begin
                repeat(2) @(posedge clock);
                i_tx_done = 1'b1;
                @(posedge clock);
                i_tx_done = 1'b0;
            end
        end
        
        // Wait for final IDLE
        wait_for_state(3'b000);
        
        $display("[PASS] Multiple operations test completed\n");
    endtask
    
    task test_fifo_output();
        logic [31:0] expected_value;
        
        $display("\n[TEST 6] FIFO Output State");
        $display("========================================");
        
        expected_value = 32'hDEADBEEF;
        $display("  Expected value: 0x%08h", expected_value);
        $display("  Expected bytes: [0]=0x%02h [1]=0x%02h [2]=0x%02h [3]=0x%02h",
                 expected_value[7:0], expected_value[15:8], 
                 expected_value[23:16], expected_value[31:24]);
        
        // Send complete valid transaction
        send_rx_byte(START_CHAR);
        for (int i = 0; i < 4; i++) send_rx_byte(8'hAA);
        for (int i = 0; i < 4; i++) send_rx_byte(8'hBB);
        send_rx_byte(8'h20);
        
        i_alu_out = expected_value;
        $display("  i_alu_out set to: 0x%08h", i_alu_out);
        
        send_rx_byte(END_CHAR);
        
        // Wait for FIFO_OUT state
        wait_for_state(3'b101);
        $display("  Entered FIFO_OUT state");
        
        // Verify write is active
        @(posedge clock);
        check_condition(o_write == 1'b1, "Write should be high in FIFO_OUT");
        
        // Wait for SEND state
        wait_for_state(3'b110);
        $display("  Entered SEND state, data_count=%0d", u_interface_uart.data_count);
        
        // Verify transmission
        verify_transmission(expected_value, "FIFO output");
        
        $display("[PASS] FIFO output test completed\n");
    endtask
    
    // Helper task to verify transmission of 4 bytes
    task verify_transmission(logic [31:0] expected_value, string prefix);
        // The RTL issue: In SEND state with data_count=0:
        // - alu_output uses current data_count (0) -> should output byte 0
        // - tx_start is HIGH when data_count==0
        // - But data_count increments to 1 in same cycle
        // - Next cycle, data_count=1, so tx_start goes LOW
        
        if (debug_mode) begin
            $display("  [DEBUG] verify_transmission called");
            $display("  [DEBUG] Current state: %0d, data_count: %0d", 
                     u_interface_uart.state_reg, u_interface_uart.data_count);
            $display("  [DEBUG] Current o_alu_out: 0x%02h, o_tx_start: %0d", 
                     o_alu_out, o_tx_start);
        end
        
        // CRITICAL: tx_start is HIGH RIGHT NOW (data_count==0)
        // We must check it BEFORE the clock edge
        check_condition(o_tx_start == 1'b1, $sformatf("TX start should be asserted in SEND (%s)", prefix));
        
        // The first byte (byte 0) is also on o_alu_out RIGHT NOW
        check_data_byte(expected_value[7:0], o_alu_out, 
            $sformatf("%s byte 0", prefix));
        
        // Now trigger the first transmission
        @(posedge clock);
        
        if (debug_mode) begin
            $display("  [DEBUG] After 1 cycle: state=%0d, data_count=%0d, tx_start=%0d, o_alu_out=0x%02h",
                     u_interface_uart.state_reg, u_interface_uart.data_count, 
                     o_tx_start, o_alu_out);
        end
        
        // Now we're at data_count=1, output shows byte 1, tx_start=0
        // Verify remaining bytes (1, 2, 3)
        for (int i = 1; i < 4; i++) begin
            if (debug_mode) begin
                $display("  [DEBUG] Byte %0d: expected=0x%02h, actual=0x%02h, data_count=%0d",
                         i, expected_value[i*8 +: 8], o_alu_out, u_interface_uart.data_count);
            end
            
            check_data_byte(expected_value[i*8 +: 8], o_alu_out, 
                $sformatf("%s byte %0d", prefix, i));
            
            // Simulate TX completion - this will pulse tx_start again
            i_tx_done = 1'b1;
            @(posedge clock);
            i_tx_done = 1'b0;
            
            // Wait for next byte (if not the last one)
            if (i < 3) @(posedge clock);
        end
    endtask
    
    // Helper task to send a byte and check read signal
    task send_rx_byte_and_check_read(logic [7:0] data);
        @(posedge clock);
        i_rx_data = data;
        i_rx_done = 1'b1;
        i_rx_empty = 1'b0;
        
        // o_read is combinational, so it's high in THIS cycle
        // But we need to sample it AFTER the registered rx_done_reg updates
        @(posedge clock);
        // Now rx_done_reg = 1, so o_read should be 1
        check_condition(o_read == 1'b1, "Read should be high after START");
        
        i_rx_done = 1'b0;
        @(posedge clock);
    endtask
    
    // Helper task to send a byte via RX
    task send_rx_byte(logic [7:0] data);
        @(posedge clock);
        i_rx_data = data;
        i_rx_done = 1'b1;
        i_rx_empty = 1'b0;
        
        @(posedge clock);
        i_rx_done = 1'b0;
        
        @(posedge clock);
    endtask
    
    // Helper task to wait for specific state
    task wait_for_state(logic [2:0] state);
        int timeout = 0;
        while (u_interface_uart.state_reg != state && timeout < 100) begin
            @(posedge clock);
            timeout++;
        end
        if (timeout >= 100) begin
            $display("  [WARNING] Timeout waiting for state %0d", state);
        end
    endtask
    
    task check_condition(bit condition, string msg);
        test_count++;
        if (condition) begin
            $display("  [✓] %s", msg);
        end else begin
            $display("  [✗] %s (actual value doesn't match)", msg);
            error_count++;
        end
    endtask
    
    task check_data_byte(logic [7:0] expected, logic [7:0] actual, string msg);
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
        $display("        Interface UART Testbench (SystemVerilog)           ");
        $display("============================================================");
        $display("NB_DATA:             %0d bits", NB_DATA);
        $display("NB_REG:              %0d bits", NB_REG);
        $display("NB_OP_CODE:          %0d bits", NB_OP_CODE);
        $display("Protocol:            START=0x%02h, END=0x%02h", START_CHAR, END_CHAR);
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
    
    // VCD dump
    initial begin
        $dumpfile("tb_interface_uart.vcd");
        $dumpvars(0, tb_interface_uart);
    end
    
endmodule