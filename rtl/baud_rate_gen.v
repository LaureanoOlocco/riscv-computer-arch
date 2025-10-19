module baud_rate_gen 
#(
    parameter                                               CLK_FREQ  = 100_000_000 ,
    parameter                                               BAUD_RATE = 115_200
) 
(
    output wire                                             o_baud_tick             ,
    input  wire                                             i_valid                 ,
    input  wire                                             i_rst                   ,
    input  wire                                             clock                   ,
);
    localparam                                              NB_COUNTER = 32         ;

    reg [NB_COUNTER                                - 1 : 0] counter                 ;
    reg                                                     tick                    ;

    always @(posedge clock or posedge i_rst) 
    begin
        if (i_rst) 
        begin
            counter         <= {NB_COUNTER{1'b0}}                                   ;
            tick            <= 1'b0                                                 ;
        end 
        else if (i_valid) 
        begin
            {tick, counter} <= counter + BAUD_RATE >= CLK_FREQ                      ?
                               {1'b1, counter + BAUD_RATE - CLK_FREQ}               :
                               {1'b0, counter + BAUD_RATE}                          ;
        end 
        else 
        begin
            tick <= 1'b0                                                            ;
        end
    end

    assign o_baud_tick = tick                                                       ;  

endmodule
