//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_regfile_tx.v
// Date        : 2026-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Register file transmitter over UART.
//                - Sends current PC first, then reads registers sequentially.
//                - Serializes each 32-bit value as 4 bytes (little-endian).
//                - Asserts done after the last register is transmitted.
//--------------------------------------------------------------------------------------------------

module du_regfile_tx
#(
    parameter NB_PC        = 32,  // NB of Program Counter
    parameter NB_REG       = 32,
    parameter NB_UART_DATA = 8
) (
    // Outputs
    output wire                        o_done         ,
    output wire                        o_tx_start     ,  // UART Tx start output
    output wire                        o_wr           ,  // UART FIFO Tx write enable output
    output wire [NB_UART_DATA - 1 : 0] o_wdata        ,  // UART FIFO Tx write data
    output wire                        o_regfile_rd   ,
    output wire [4 : 0]                o_regfile_raddr,
    
    // Inputs
    input wire                        i_start       ,
    input wire [NB_PC        - 1 : 0] i_pc          ,  // PC input
    input wire [NB_REG       - 1 : 0] i_regfile_data,  // CPU's register file input
    input wire                        i_tx_done     ,
    input wire                        i_rst         ,
    input wire                        clk            
);
    
    // Local Parameters
    localparam NB_STATE   = 4;
    localparam NB_COUNTER = 3;
    
    // Internal States
    localparam [NB_STATE - 1 : 0] IDLE     = 4'b0001;
    localparam [NB_STATE - 1 : 0] SEND_PC  = 4'b0010;
    localparam [NB_STATE - 1 : 0] READ_REG = 4'b0100;
    localparam [NB_STATE - 1 : 0] SEND_REG = 4'b1000;
    
    // Internal Signals
    // State Register
    reg [NB_STATE - 1 : 0] state_reg ;
    reg [NB_STATE - 1 : 0] next_state;
    
    // Data Received Registers                         
    reg [NB_REG - 1 : 0] rx_data_reg ;
    reg [NB_REG - 1 : 0] rx_data_next;
    
    // Regfile Read Address Registers
    reg [4 : 0] regfile_addr_reg ;
    reg [4 : 0] regfile_addr_next;
    
    // Word's bytes counter registers
    reg [NB_COUNTER - 1 : 0] counter_reg ;
    reg [NB_COUNTER - 1 : 0] counter_next;

   reg                        done_out;         
   reg                        tx_start_out;     
   reg                        wr_out;           
   reg [NB_UART_DATA - 1 : 0] wdata_out;        
   reg                        regfile_rd_out;   

    // Read Address Output Logic
    assign o_regfile_raddr = regfile_addr_reg;
    assign o_regfile_rd    = regfile_rd_out;
    assign o_wdata         = wdata_out;
    assign o_tx_start      = tx_start_out;
    assign o_wr            = wr_out;
    assign o_done          = done_out;
    
    // FSMD states and data registers
    always @(posedge clk) begin
        if (i_rst) begin
            state_reg        <= IDLE;
            rx_data_reg      <= {NB_REG{1'b0}};
            regfile_addr_reg <= {5{1'b0}};
            counter_reg      <= {NB_COUNTER{1'b0}};
        end
        else begin
            state_reg        <= next_state;
            rx_data_reg      <= rx_data_next;
            regfile_addr_reg <= regfile_addr_next;
            counter_reg      <= counter_next;
        end
    end
    
    // Next-State Logic
    always @(*) begin
        // Default values
        next_state = state_reg;
        
        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    next_state = SEND_PC;
                end
            end
            
            SEND_PC: begin
                if (counter_reg == 3'b100 && i_tx_done) begin
                    next_state = READ_REG;
                end
            end
            
            READ_REG: begin
                if (counter_reg == 3'b100) begin
                    next_state = SEND_REG;
                end
            end
            
            SEND_REG: begin
                if (counter_reg == 3'b100 && i_tx_done) begin
                    if (regfile_addr_reg == 5'd0) begin
                        next_state = IDLE;
                    end
                    else begin
                        next_state = READ_REG;
                    end
                end
            end
            
            default: next_state = state_reg;
        endcase
    end
    
    // State Logic
    always @(*) begin
        // Default values
        done_out            = 1'b0;
        regfile_rd_out      = 1'b0;
        tx_start_out        = 1'b0;  
        wr_out              = 1'b0;
        wdata_out           = 8'h00;
        rx_data_next      = rx_data_reg;
        regfile_addr_next = regfile_addr_reg;
        counter_next = counter_reg;
        
        case (state_reg)
            SEND_PC: begin
                if (counter_reg == 3'b100) begin
                    if (i_tx_done) begin
                        counter_next = {NB_COUNTER{1'b0}};
                    end
                end
                else if (counter_reg == 3'b000) begin
                    wdata_out      = i_pc[7 : 0];
                    wr_out         = 1'b1;
                    tx_start_out   = 1'b1;
                    counter_next = counter_reg + 1'b1;
                end
                else if (counter_reg == 3'b001) begin
                    if (i_tx_done) begin
                        wdata_out           = i_pc[15 : 8];
                        wr_out              = 1'b1;
                        tx_start_out        = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b010) begin
                    if (i_tx_done) begin
                        wdata_out           = i_pc[23 : 16];
                        wr_out              = 1'b1;
                        tx_start_out        = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b011) begin
                    if (i_tx_done) begin
                        wdata_out           = i_pc[31 : 24];
                        wr_out              = 1'b1;
                        tx_start_out        = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
            end
            
            READ_REG: begin
                regfile_rd_out  = 1'b1;
                counter_next    = counter_reg + 1'b1;

                if (counter_reg == 3'b100) begin
                    rx_data_next = i_regfile_data;
                    regfile_addr_next = regfile_addr_reg + 1'b1;
                    counter_next = {NB_COUNTER{1'b0}};
                end
            end
            
            SEND_REG: begin
                if (counter_reg == 3'b100) begin
                    if (i_tx_done) begin
                        counter_next = {NB_COUNTER{1'b0}};
                    end

                    if (regfile_addr_reg == 5'd0) begin
                        done_out = 1'b1;
                    end
                end
                else if (counter_reg == 3'b000) begin
                    wdata_out      = rx_data_reg[7 : 0];
                    wr_out         = 1'b1;
                    tx_start_out   = 1'b1;
                    counter_next = counter_reg + 1'b1;
                end
                else if (counter_reg == 3'b001) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[15 : 8];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b010) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[23 : 16];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
                else if (counter_reg == 3'b011) begin
                    if (i_tx_done) begin
                        wdata_out      = rx_data_reg[31 : 24];
                        wr_out         = 1'b1;
                        tx_start_out   = 1'b1;
                        counter_next = counter_reg + 1'b1;
                    end
                end
            end 
            
            default: begin
                done_out            = 1'b0;
                regfile_rd_out      = 1'b0;
                tx_start_out        = 1'b0;  
                wr_out              = 1'b0;
                wdata_out           = 8'h00;
                rx_data_next      = rx_data_reg;
                regfile_addr_next = regfile_addr_reg;
                counter_next      = counter_reg;
            end
            
        endcase
    end
    
endmodule
