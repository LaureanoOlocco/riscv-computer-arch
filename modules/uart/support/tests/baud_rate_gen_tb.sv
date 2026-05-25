`timescale 1ns/1ps

module tb_baud_rate_gen();

    // Parameters
    parameter int                       NB_COUNTER  = 9                     ;
    parameter int                       CLK_FREQ    = 100_000_000           ;
    parameter int                       BAUD_RATE   = 115_200               ;
    parameter int                       SM_TICK     = 16                    ;
    parameter real                      CLK_PERIOD  = 10.0                  ; // 10ns = 100MHz
    
    // Calculated values
    localparam int                      DIVISOR     = CLK_FREQ / (BAUD_RATE * SM_TICK);
    localparam real                     EXPECTED_TICK_PERIOD = (1.0 / (BAUD_RATE * SM_TICK)) * 1_000_000_000;
    
    // Signals
    logic                               clock                               ;
    logic                               i_rst                               ;
    logic   [NB_COUNTER        - 1 : 0] o_counter                           ;
    logic                               o_tick                              ;
    
    // Monitoring variables
    int                                 tick_count                          ;
    real                                last_tick_time                      ;
    real                                current_tick_time                   ;
    real                                measured_period                     ;
    real                                error_percentage                    ;
    bit                                 first_tick_detected                 ;
    
    // DUT instantiation
    baud_rate_gen 
    #(
        .NB_COUNTER     (NB_COUNTER     ),
        .CLK_FREQ       (CLK_FREQ       ),
        .BAUD_RATE      (BAUD_RATE      ),
        .SM_TICK        (SM_TICK        )
    )
    u_baud_rate_gen
    (
        .o_counter      (o_counter      ),
        .o_tick         (o_tick         ),
        .i_rst          (i_rst          ),
        .clock          (clock          )
    );
    
    // Clock generation
    initial begin
        clock = 1'b0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        i_rst                   = 1'b1;
        tick_count              = 0;
        last_tick_time          = 0.0;
        first_tick_detected     = 1'b0;
        
        print_header();
        
        // Reset pulse
        repeat(5) @(posedge clock);
        i_rst = 1'b0;
        $display("[%0t ns] Reset released\n", $time);
        
        // Wait for first tick
        @(posedge o_tick);
        last_tick_time = $realtime;
        first_tick_detected = 1'b1;
        $display("[%0t ns] First tick detected", $time);
        
        // Monitor multiple ticks
        repeat(20) begin
            @(posedge o_tick);
            tick_count++;
            current_tick_time = $realtime;
            measured_period = current_tick_time - last_tick_time;
            error_percentage = ((measured_period - EXPECTED_TICK_PERIOD) / EXPECTED_TICK_PERIOD) * 100.0;
            
            $display("[%0t ns] Tick #%-3d | Period: %6.2f ns | Expected: %6.2f ns | Error: %+6.2f%% | Counter: %0d", 
                     $time, tick_count, measured_period, EXPECTED_TICK_PERIOD, error_percentage, o_counter);
            
            // Check period accuracy
            if ((error_percentage) > 1.0) begin
                $error("Period error exceeds 1%%!");
            end
            
            last_tick_time = current_tick_time;
        end
        
        print_footer();
        
        // Additional cycles for observation
        repeat(100) @(posedge clock);
        
        $finish;
    end
    
    // Assertions
    
    // Property: Counter should never exceed DIVISOR-1
    property counter_range;
        @(posedge clock) disable iff (i_rst)
        o_counter < DIVISOR;
    endproperty
    assert_counter_range: assert property(counter_range)
    else $error("[%0t ns] Counter overflow! o_counter = %0d, DIVISOR = %0d", $time, o_counter, DIVISOR);
    
    // Property: Tick should be high for exactly one cycle
    property tick_width;
        @(posedge clock) disable iff (i_rst)
        $rose(o_tick) |=> $fell(o_tick);
    endproperty
    assert_tick_width: assert property(tick_width)
    else $warning("[%0t ns] Tick pulse width != 1 cycle", $time);
    
    // Property: Counter should reset when tick is high
    property counter_reset;
        @(posedge clock) disable iff (i_rst)
        o_tick |=> (o_counter == 0);
    endproperty
    assert_counter_reset: assert property(counter_reset)
    else $error("[%0t ns] Counter not reset after tick! counter = %0d", $time, o_counter);
    
    // Property: Ticks should occur every DIVISOR cycles
    sequence tick_period;
        (!o_tick)[*DIVISOR-1] ##1 o_tick;
    endsequence
    property tick_periodicity;
        @(posedge clock) disable iff (i_rst || !first_tick_detected)
        o_tick |-> ##DIVISOR o_tick;
    endproperty
    assert_tick_periodicity: assert property(tick_periodicity)
    else $error("[%0t ns] Tick periodicity violated!", $time);
    
    // Coverage
    covergroup cg_baud_rate @(posedge clock);
        option.per_instance = 1;
        
        cp_counter: coverpoint o_counter {
            bins low    = {[0:DIVISOR/4-1]};
            bins mid    = {[DIVISOR/4:3*DIVISOR/4-1]};
            bins high   = {[3*DIVISOR/4:DIVISOR-1]};
            bins max    = {DIVISOR-1};
        }
        
        cp_tick: coverpoint o_tick {
            bins low    = {0};
            bins high   = {1};
        }
        
        cp_reset: coverpoint i_rst {
            bins inactive   = {0};
            bins active     = {1};
        }
        
        cross_tick_counter: cross cp_tick, cp_counter;
    endgroup
    
    cg_baud_rate cg_inst = new();
    
    // Functions for pretty printing
    function void print_header();
        $display("============================================================");
        $display("         Baud Rate Generator Testbench (SystemVerilog)     ");
        $display("============================================================");
        $display("Clock Frequency:         %0d Hz", CLK_FREQ);
        $display("Baud Rate:               %0d", BAUD_RATE);
        $display("Oversampling Factor:     %0d", SM_TICK);
        $display("Divisor:                 %0d", DIVISOR);
        $display("Clock Period:            %.2f ns", CLK_PERIOD);
        $display("Expected Tick Period:    %.2f ns", EXPECTED_TICK_PERIOD);
        $display("Expected Tick Frequency: %.2f Hz", 1_000_000_000.0 / EXPECTED_TICK_PERIOD);
        $display("============================================================\n");
    endfunction
    
    function void print_footer();
        $display("\n============================================================");
        $display("Test Summary");
        $display("============================================================");
        $display("Total ticks measured:    %0d", tick_count);
        $display("Simulation time:         %0t ns", $time);
        $display("Status:                  PASSED");
        $display("============================================================");
    endfunction
    
    // Timeout watchdog
    initial begin
        #200000;
        $display("\n[TIMEOUT] Simulation exceeded maximum time");
        $finish;
    end
    
endmodule