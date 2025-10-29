`timescale 1ns/1ps

module tb_top_uart;

    //========================================
    // Parameters
    //========================================
    localparam                                  CLK_FREQ            = 100_000_000               ;   // 100 MHz
    localparam                                  BAUD_RATE           = 115_200                   ;
    localparam                                  SM_TICK             = 16                        ;
    
    //========================================
    // Calculated timing
    //========================================
    localparam real                             CLK_PERIOD_NS       = 1_000_000_000.0/CLK_FREQ  ;
    localparam real                             BIT_PERIOD_NS       = 1_000_000_000.0/BAUD_RATE ;

    //========================================
    // Protocol constants
    //========================================
    localparam      [7:0]                       START_CHAR          = 8'hFB                     ;
    localparam      [7:0]                       END_CHAR            = 8'hFD                     ;
    localparam      [31:0]                      ERROR_CHAR          = 32'hFEFEFEFE              ;

    //========================================
    // ALU operation codes (from alu.v)
    //========================================
    localparam      [5:0]                       ADD_OP              = 6'b100000                 ;   // 0x20
    localparam      [5:0]                       SUB_OP              = 6'b100010                 ;   // 0x22
    localparam      [5:0]                       AND_OP              = 6'b100100                 ;   // 0x24
    localparam      [5:0]                       OR_OP               = 6'b100101                 ;   // 0x25
    localparam      [5:0]                       XOR_OP              = 6'b100110                 ;   // 0x26
    localparam      [5:0]                       SRA_OP              = 6'b000011                 ;   // 0x03
    localparam      [5:0]                       SRL_OP              = 6'b000010                 ;   // 0x02
    localparam      [5:0]                       NOR_OP              = 6'b100111                 ;   // 0x27

    //========================================
    // DUT signals
    //========================================
    logic                                       clock                                           ;
    logic                                       i_rst                                           ;
    logic                                       i_rx                                            ;
    wire                                        i_tx                                            ;

    //========================================
    // DUT instantiation
    //========================================
    top_uart dut (
        .o_uart     (                                                                           ),
        .i_tx       (i_tx                                                                       ),
        .i_rx       (i_rx                                                                       ),
        .i_rst      (i_rst                                                                      ),
        .clock      (clock                                                                      )
    )                                                                                           ;

    //========================================
    // Clock generation
    //========================================
    initial 
    begin
        clock = 1'b0                                                                            ;
        forever #(CLK_PERIOD_NS/2) clock = ~clock                                               ;
    end

    //========================================
    // UART Task: Send single byte
    //========================================
    task automatic uart_send_byte(input logic [7:0] data);
        integer i                                                                               ;
        begin
            i_rx = 1'b0                                                                         ;   // Start bit
            #(BIT_PERIOD_NS)                                                                    ;
            for (i = 0; i < 8; i = i + 1) 
            begin
                i_rx = data[i]                                                                  ;   // Data bits LSB first
                #(BIT_PERIOD_NS)                                                                ;
            end
            i_rx = 1'b1                                                                         ;   // Stop bit
            #(BIT_PERIOD_NS)                                                                    ;
        end
    endtask

    //========================================
    // UART Task: Send 32-bit word BIG-ENDIAN
    // MSB byte first, as expected by interface_uart
    //========================================
    task automatic uart_send_word32_be(input logic [31:0] w);
        begin
            uart_send_byte(w[31:24])                                                            ;   // Byte 3 (MSB)
            uart_send_byte(w[23:16])                                                            ;   // Byte 2
            uart_send_byte(w[15:8])                                                             ;   // Byte 1
            uart_send_byte(w[7:0])                                                              ;   // Byte 0 (LSB)
        end
    endtask

    //========================================
    // UART Task: Send complete frame
    // Format: START_CHAR + A(32) + B(32) + OP(8) + END_CHAR
    //========================================
    task automatic send_frame(
        input logic [31:0] A,
        input logic [31:0] B,
        input logic [7:0]  OP
    );
        begin
            i_rx = 1'b1                                                                         ;   // Ensure idle state
            #(BIT_PERIOD_NS * 2)                                                                ;
            uart_send_byte(START_CHAR)                                                          ;
            uart_send_word32_be(A)                                                              ;
            uart_send_word32_be(B)                                                              ;
            uart_send_byte(OP)                                                                  ;
            uart_send_byte(END_CHAR)                                                            ;
        end
    endtask

    //========================================
    // UART Task: Receive single byte
    //========================================
    task automatic uart_recv_byte(
        output logic       valid,
        output logic [7:0] data
    );
        integer i                                                                               ;
        time    t_start                                                                         ;
        begin
            valid   = 1'b0                                                                      ;
            data    = 8'h00                                                                     ;
            t_start = $time                                                                     ;

            // Wait for start bit with timeout
            while (i_tx == 1'b1) 
            begin
                if (($time - t_start) > (BIT_PERIOD_NS * 20)) 
                begin
                    $display("  [TIMEOUT] No start bit detected on i_tx @ %0t ns", $time)      ;
                    return                                                                      ;
                end
                #(BIT_PERIOD_NS / 16)                                                           ;
            end

            // Sample at center of start bit
            #(BIT_PERIOD_NS / 2)                                                                ;
            if (i_tx != 1'b0) 
            begin
                $display("  [ERROR] Invalid start bit @ %0t ns", $time)                        ;
                return                                                                          ;
            end

            // Read 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) 
            begin
                #(BIT_PERIOD_NS)                                                                ;
                data[i] = i_tx                                                                  ;
            end

            // Verify stop bit
            #(BIT_PERIOD_NS)                                                                    ;
            if (i_tx == 1'b1) 
            begin
                valid = 1'b1                                                                    ;
            end 
            else 
            begin
                $display("  [ERROR] Invalid stop bit @ %0t ns", $time)                         ;
            end
        end
    endtask

    //========================================
    // UART Task: Receive 32-bit word LITTLE-ENDIAN
    // LSB byte first, as transmitted by interface_uart
    //========================================
    task automatic uart_recv_word32_le(
        output logic        valid,
        output logic [31:0] word
    );
        logic       ok                                                                          ;
        logic [7:0] b0, b1, b2, b3                                                              ;
        begin
            valid = 1'b0                                                                        ;
            word  = 32'h0                                                                       ;

            uart_recv_byte(ok, b0)                                                              ; 
            if (!ok) return                                                                     ;
            uart_recv_byte(ok, b1)                                                              ; 
            if (!ok) return                                                                     ;
            uart_recv_byte(ok, b2)                                                              ; 
            if (!ok) return                                                                     ;
            uart_recv_byte(ok, b3)                                                              ; 
            if (!ok) return                                                                     ;

            // Assemble little-endian: b0 is LSB
            word  = {b3, b2, b1, b0}                                                            ;
            valid = 1'b1                                                                        ;
        end
    endtask

    //========================================
    // ALU Reference Model
    // Matches operations from alu.v
    //========================================
    function automatic logic [31:0] alu_reference(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [5:0]  op
    );
        case (op)
            ADD_OP  : return a + b                                                              ;
            SUB_OP  : return a - b                                                              ;
            AND_OP  : return a & b                                                              ;
            OR_OP   : return a | b                                                              ;
            XOR_OP  : return a ^ b                                                              ;
            SRA_OP  : return $signed(a) >>> b[$clog2(32)-1:0]                                   ;
            SRL_OP  : return a >> b[$clog2(32)-1:0]                                             ;
            NOR_OP  : return ~(a | b)                                                           ;
            default : return 32'hDEADBEEF                                                       ;
        endcase
    endfunction

    //========================================
    // Debug signals monitoring
    //========================================
    initial 
    begin
        forever 
        begin
            @(posedge dut.u_uart_rx.o_rx_done_tick)                                            ;
            $display("[DEBUG] UART_RX done @ %0t ns - Data: 0x%02h", 
                     $time, dut.u_uart_rx.o_data)                                               ;
        end
    end

    initial 
    begin
        forever 
        begin
            @(posedge clock)                                                                    ;
            if (dut.u_interface_uart.state_reg !== dut.u_interface_uart.state_next)
            begin
                $display("[DEBUG] Interface: State %0d -> %0d @ %0t ns", 
                         dut.u_interface_uart.state_reg, 
                         dut.u_interface_uart.state_next, $time)                                ;
            end
        end
    end

    initial 
    begin
        forever 
        begin
            @(posedge dut.u_interface_uart.o_read)                                             ;
            $display("[DEBUG] Interface READ pulse @ %0t ns - FIFO data: 0x%02h", 
                     $time, dut.u_fifo_rx.o_data)                                               ;
        end
    end

    initial 
    begin
        forever 
        begin
            @(posedge clock)                                                                    ;
            if (dut.u_interface_uart.state_reg == 3'b110)  // STATE_SEND
            begin
                $display("[DEBUG] In SEND: data_count=%0d tx_done=%b tx_start=%b @ %0t", 
                         dut.u_interface_uart.data_count,
                         dut.u_interface_uart.tx_done_reg,
                         dut.u_interface_uart.o_tx_start,
                         $time)                                                                 ;
            end
        end
    end

    initial 
    begin
        forever 
        begin
            @(posedge dut.u_interface_uart.o_tx_start)                                         ;
            $display("[DEBUG] TX_START activated @ %0t ns - FIFO_TX data: 0x%02h", 
                     $time, dut.u_fifo_tx.o_data)                                               ;
        end
    end

    //========================================
    // Main test sequence
    //========================================
    initial 
    begin
        integer             k                                                                   ;
        logic       [31:0]  A, B, expected, received                                            ;
        logic       [7:0]   OP                                                                  ;
        logic               rx_valid                                                            ;
        integer             pass_cnt, fail_cnt                                                  ;

        //----------------------------------------
        // Initialization
        //----------------------------------------
        i_rx        = 1'b1                                                                      ;   // UART idle
        i_rst       = 1'b1                                                                      ;   // Assert reset (active high)
        pass_cnt    = 0                                                                         ;
        fail_cnt    = 0                                                                         ;

        //----------------------------------------
        // Apply reset sequence
        //----------------------------------------
        repeat (10) @(posedge clock)                                                            ;
        i_rst = 1'b0                                                                            ;   // Deassert reset
        repeat (20) @(posedge clock)                                                            ;

        //----------------------------------------
        // Display test header
        //----------------------------------------
        $display("========================================")                                    ;
        $display("UART ALU Testbench")                                                          ;
        $display("========================================")                                    ;
        $display("CLK_FREQ  = %0d Hz", CLK_FREQ)                                                ;
        $display("BAUD_RATE = %0d bps", BAUD_RATE)                                              ;
        $display("SM_TICK   = %0d", SM_TICK)                                                    ;
        $display("Expected counter divisor = %0d", CLK_FREQ/(BAUD_RATE*SM_TICK))               ;
        $display("========================================\n")                                  ;

        //----------------------------------------
        // Test case loop
        //----------------------------------------
        for (k = 0; k < 10; k = k + 1) 
        begin
            // Define test vectors
            case (k)
                0: begin A = 32'h0000_0005; B = 32'h0000_0003; OP = {2'b00, ADD_OP}; end            // ADD: 5+3=8
                1: begin A = 32'h0000_000A; B = 32'h0000_0002; OP = {2'b00, ADD_OP}; end            // ADD: 10+2=12
                2: begin A = 32'h0000_0008; B = 32'h0000_0003; OP = {2'b00, SUB_OP}; end            // SUB: 8-3=5
                3: begin A = 32'h0000_00FF; B = 32'h0000_000F; OP = {2'b00, AND_OP}; end            // AND: 0xFF & 0x0F = 0x0F
                4: begin A = 32'h0000_00F0; B = 32'h0000_000F; OP = {2'b00, OR_OP};  end            // OR:  0xF0 | 0x0F = 0xFF
                5: begin A = 32'h0000_5555; B = 32'h0000_AAAA; OP = {2'b00, XOR_OP}; end            // XOR: 0x5555 ^ 0xAAAA = 0xFFFF
                6: begin A = 32'hFFFF_FFFF; B = 32'h0000_0001; OP = {2'b00, ADD_OP}; end            // ADD: overflow test
                7: begin A = 32'h1234_5678; B = 32'h8765_4321; OP = {2'b00, XOR_OP}; end            // XOR: random data
                8: begin A = 32'h8000_0000; B = 32'h0000_0002; OP = {2'b00, SRA_OP}; end            // SRA: arithmetic shift right
                9: begin A = 32'h0000_0001; B = 32'h0000_0004; OP = {2'b00, SRL_OP}; end            // SRL: logical shift right
            endcase

            // Calculate expected result
            expected = alu_reference(A, B, OP[5:0])                                             ;

            $display("[Test %0d] @ %0t ns", k, $time)                                           ;
            $display("  Inputs  : A=0x%08h B=0x%08h OP=0x%02h", A, B, OP)                       ;
            $display("  Expected: 0x%08h", expected)                                            ;

            // Send frame to DUT
            send_frame(A, B, OP)                                                                ;

            // Wait for processing (need more time for internal state machine)
            // Frame has 10 bytes RX + processing + 4 bytes TX = ~14 byte times + overhead
            #(BIT_PERIOD_NS * 200)                                                              ;

            // Receive response from DUT
            uart_recv_word32_le(rx_valid, received)                                             ;

            // Verify result
            if (rx_valid) 
            begin
                if (received === expected) 
                begin
                    $display("  Result  : 0x%08h -> PASS\n", received)                          ;
                    pass_cnt = pass_cnt + 1                                                     ;
                end 
                else 
                begin
                    $display("  Result  : 0x%08h -> FAIL", received)                            ;
                    $display("  Mismatch: Expected 0x%08h\n", expected)                         ;
                    fail_cnt = fail_cnt + 1                                                     ;
                end
            end 
            else 
            begin
                $display("  Result  : NO VALID DATA -> FAIL\n")                                 ;
                fail_cnt = fail_cnt + 1                                                         ;
            end

            // Gap between frames
            #(BIT_PERIOD_NS * 20)                                                               ;
        end

        //----------------------------------------
        // Error handling test: Invalid frame
        //----------------------------------------
        $display("[Test ERROR] @ %0t ns", $time)                                                ;
        $display("  Sending invalid frame (missing END_CHAR)")                                  ;
        
        i_rx = 1'b1                                                                             ;
        #(BIT_PERIOD_NS * 2)                                                                    ;
        uart_send_byte(START_CHAR)                                                              ;
        uart_send_word32_be(32'h1234_5678)                                                      ;
        uart_send_word32_be(32'h8765_4321)                                                      ;
        uart_send_byte(8'h00)                                                                   ;
        uart_send_byte(8'hAA)                                                                   ;   // Invalid byte instead of END_CHAR
        
        #(BIT_PERIOD_NS * 10)                                                                   ;
        uart_recv_word32_le(rx_valid, received)                                                 ;
        
        if (rx_valid && received === ERROR_CHAR) 
        begin
            $display("  Received: 0x%08h (ERROR_CHAR) -> PASS\n", received)                     ;
            pass_cnt = pass_cnt + 1                                                             ;
        end 
        else 
        begin
            $display("  Expected: 0x%08h (ERROR_CHAR)", ERROR_CHAR)                             ;
            $display("  Received: 0x%08h -> FAIL\n", received)                                  ;
            fail_cnt = fail_cnt + 1                                                             ;
        end

        //----------------------------------------
        // Display summary
        //----------------------------------------
        $display("========================================")                                    ;
        $display("Test Summary")                                                                ;
        $display("========================================")                                    ;
        $display("Total tests : %0d", pass_cnt + fail_cnt)                                      ;
        $display("PASSED      : %0d", pass_cnt)                                                 ;
        $display("FAILED      : %0d", fail_cnt)                                                 ;
        $display("========================================")                                    ;
        $display("Simulation finished @ %0t ns", $time)                                         ;
        
        if (fail_cnt == 0)
            $display(">>> ALL TESTS PASSED <<<\n")                                              ;
        else
            $display(">>> SOME TESTS FAILED <<<\n")                                             ;

        #1000                                                                                   ;
        $finish                                                                                 ;
    end

    //========================================
    // Simulation timeout watchdog
    //========================================
    initial 
    begin
        #(BIT_PERIOD_NS * 10000)                                                                ;
        $display("\n[TIMEOUT] Simulation exceeded time limit @ %0t ns", $time)                 ;
        $finish                                                                                 ;
    end

endmodule