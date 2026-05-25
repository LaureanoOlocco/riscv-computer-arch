module synchronizer
#(
    // ------------------------------------------------------------------ //
    // Synchronization parameters
    // ------------------------------------------------------------------ //
    parameter N_LEVELS          = 2  // Number of synchronization levels
)
(
    // ------------------------------------------------------------------ //
    // Synchronization inputs and outputs
    // ------------------------------------------------------------------ //
    output wire  o_data                                                 ,  // synchronized output data
    input  wire  i_data                                                 ,  // data to be synchronized

    // ------------------------------------------------------------------ //
    // System
    // ------------------------------------------------------------------ //
    input  wire  clock               //! System clock
);
 
reg [N_LEVELS - 1 : 0] sync_regs;  // Synchronization registers

always @(posedge clock) 
begin
    sync_regs <= {sync_regs[N_LEVELS - 2 : 0], i_data};
end

assign o_data = sync_regs[N_LEVELS - 1];

endmodule