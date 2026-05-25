module baud_rate_gen
#(
    parameter                                                   NB_COUNTER = 9              ,               
    parameter                                                   CLK_FREQ   = 100_000_000    ,
    parameter                                                   BAUD_RATE  = 115_200        ,
    parameter                                                   SM_TICK    = 16
)(
    output wire [NB_COUNTER                            - 1 : 0] o_counter                   ,
    output wire                                                 o_tick                      ,
    input  wire                                                 i_rst                       ,
    input  wire                                                 clock               
);

    localparam                                                  DIVISOR = CLK_FREQ / (BAUD_RATE * SM_TICK);

    reg         [NB_COUNTER                           - 1 : 0]  counter_reg = {NB_COUNTER{1'b0}};
    reg                                                         tick_reg    = 1'b0          ;

    always @(posedge clock or posedge i_rst)
    begin
        if (i_rst) 
        begin
            counter_reg     <= {NB_COUNTER{1'b0}}                                           ;
            tick_reg        <= 1'b0                                                         ;
        end 
        else 
        begin
            if (counter_reg == DIVISOR - 1) 
            begin
                counter_reg <= {NB_COUNTER{1'b0}}                                           ;
                tick_reg    <= 1'b1                                                         ;   
            end 
            else 
                begin
                counter_reg <= counter_reg + {{NB_COUNTER-1{1'b0}}, 1'b1}                   ;
                tick_reg    <= 1'b0                                                         ;                
            end
        end
    end

    assign o_counter = counter_reg                                                          ;
    assign o_tick    = tick_reg                                                             ;

endmodule
