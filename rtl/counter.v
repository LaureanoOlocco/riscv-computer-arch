//! @title COUNTER
//! @file counter.v
//! @author Felipe Montero Bruni
//! @date 10-2023
//! @version 0.1

module counter
#(
    parameter NB_COUNTER = 9                    //! NB of COUNTER REG
) (
    output wire [NB_COUNTER - 1 : 0] o_counter, //! Counter status output
    output reg                       o_tick,    //! Output tick
    input                            i_rst  ,   //! Reset
    input                            clock        //! Clock
);

    //! Internal Signals
    reg [NB_COUNTER - 1 : 0] counter_reg;  //! Counter Reg

    //! Counter Model
    always @(posedge clock) begin
        if (i_rst) begin
            counter_reg <= {NB_COUNTER{1'b0}};
        end
        else begin
            if (counter_reg == 9'h146)
                counter_reg <= {NB_COUNTER{1'b0}};
            else
                counter_reg <= counter_reg + 1'b1;
        end
    end

    //! Tick output logic
    always @(*) begin
        o_tick = 1'b0;
        if (counter_reg == 9'h146)
            o_tick = 1'b1;
    end

    assign o_counter = counter_reg;
    
endmodule