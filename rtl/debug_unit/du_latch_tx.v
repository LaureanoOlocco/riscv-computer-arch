//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_latch_tx.v
// Date        : 2026-05
// Author      : Sofia Avalos - Laureano Olocco
// Description : Pipeline-latch transmitter over UART.
//                - Serializes the contents of the 4 pipeline registers
//                  (IF/ID, ID/EX, EX/MEM, MEM/WB) as 45 bytes, little-endian per field.
//                - Asserts done after the last byte is transmitted.
//
//   Byte layout (LE per multi-byte field):
//      [ 0..3 ] IF/ID  PC
//      [ 4..7 ] IF/ID  Instr
//      [ 8..9 ] ID/EX  Ctrl       (9b, byte 8 = ctrl[7:0], byte 9 = {7'b0, ctrl[8]})
//      [10..13] ID/EX  rs1_data
//      [14..17] ID/EX  rs2_data
//      [18..21] ID/EX  imm
//      [22]     ID/EX  rd_addr    ({3'b0, rd[4:0]})
//      [23]     ID/EX  rs1_addr
//      [24]     ID/EX  rs2_addr
//      [25]     EX/MEM Ctrl       ({4'b0, ctrl[3:0]})
//      [26..29] EX/MEM ALU
//      [30..33] EX/MEM data2
//      [34]     EX/MEM rd_addr
//      [35]     MEM/WB Ctrl       ({6'b0, ctrl[1:0]})
//      [36..39] MEM/WB Data
//      [40..43] MEM/WB ALU
//      [44]     MEM/WB rd_addr
//--------------------------------------------------------------------------------------------------

module du_latch_tx
#(
    parameter NB_DATA      = 32,
    parameter NB_PC        = 32,
    parameter NB_UART_DATA = 8
) (
    // Outputs
    output wire                        o_done       ,
    output wire                        o_tx_start   ,
    output wire                        o_wr         ,
    output wire [NB_UART_DATA - 1 : 0] o_wdata      ,

    // Inputs — pipeline latch state
    input wire                         i_start      ,
    input wire [NB_PC        - 1 : 0]  i_ifid_pc    ,
    input wire [NB_DATA      - 1 : 0]  i_ifid_instr ,
    input wire [8 : 0]                  i_idex_ctrl  ,
    input wire [NB_DATA      - 1 : 0]  i_idex_rs1_data,
    input wire [NB_DATA      - 1 : 0]  i_idex_rs2_data,
    input wire [NB_DATA      - 1 : 0]  i_idex_imm   ,
    input wire [4 : 0]                  i_idex_rd_addr,
    input wire [4 : 0]                  i_idex_rs1_addr,
    input wire [4 : 0]                  i_idex_rs2_addr,
    input wire [3 : 0]                  i_exmem_ctrl ,
    input wire [NB_DATA      - 1 : 0]  i_exmem_alu  ,
    input wire [NB_DATA      - 1 : 0]  i_exmem_data2,
    input wire [4 : 0]                  i_exmem_rd_addr,
    input wire [1 : 0]                  i_memwb_ctrl ,
    input wire [NB_DATA      - 1 : 0]  i_memwb_data ,
    input wire [NB_DATA      - 1 : 0]  i_memwb_alu  ,
    input wire [4 : 0]                  i_memwb_rd_addr,

    input wire                         i_tx_done    ,
    input wire                         i_rst        ,
    input wire                         clk
);

    localparam NB_STATE   = 3;
    localparam NB_BYTES   = 45;
    localparam NB_BYTECNT = 6;  // ceil(log2(46))

    localparam [NB_STATE - 1 : 0] IDLE       = 3'b001;
    localparam [NB_STATE - 1 : 0] SEND_BYTE  = 3'b010;
    localparam [NB_STATE - 1 : 0] WAIT_TXD   = 3'b100;

    reg [NB_STATE   - 1 : 0] state_reg, next_state;
    reg [NB_BYTECNT - 1 : 0] byte_cnt_reg, byte_cnt_next;

    // Packed byte stream: byte 0 at LSB
    wire [NB_BYTES*8 - 1 : 0] pkt_data;

    // IF/ID
    assign pkt_data[ 0*8 +: 8] = i_ifid_pc[ 7: 0];
    assign pkt_data[ 1*8 +: 8] = i_ifid_pc[15: 8];
    assign pkt_data[ 2*8 +: 8] = i_ifid_pc[23:16];
    assign pkt_data[ 3*8 +: 8] = i_ifid_pc[31:24];
    assign pkt_data[ 4*8 +: 8] = i_ifid_instr[ 7: 0];
    assign pkt_data[ 5*8 +: 8] = i_ifid_instr[15: 8];
    assign pkt_data[ 6*8 +: 8] = i_ifid_instr[23:16];
    assign pkt_data[ 7*8 +: 8] = i_ifid_instr[31:24];

    // ID/EX
    assign pkt_data[ 8*8 +: 8] = i_idex_ctrl[7:0];
    assign pkt_data[ 9*8 +: 8] = {7'b0, i_idex_ctrl[8]};
    assign pkt_data[10*8 +: 8] = i_idex_rs1_data[ 7: 0];
    assign pkt_data[11*8 +: 8] = i_idex_rs1_data[15: 8];
    assign pkt_data[12*8 +: 8] = i_idex_rs1_data[23:16];
    assign pkt_data[13*8 +: 8] = i_idex_rs1_data[31:24];
    assign pkt_data[14*8 +: 8] = i_idex_rs2_data[ 7: 0];
    assign pkt_data[15*8 +: 8] = i_idex_rs2_data[15: 8];
    assign pkt_data[16*8 +: 8] = i_idex_rs2_data[23:16];
    assign pkt_data[17*8 +: 8] = i_idex_rs2_data[31:24];
    assign pkt_data[18*8 +: 8] = i_idex_imm[ 7: 0];
    assign pkt_data[19*8 +: 8] = i_idex_imm[15: 8];
    assign pkt_data[20*8 +: 8] = i_idex_imm[23:16];
    assign pkt_data[21*8 +: 8] = i_idex_imm[31:24];
    assign pkt_data[22*8 +: 8] = {3'b0, i_idex_rd_addr};
    assign pkt_data[23*8 +: 8] = {3'b0, i_idex_rs1_addr};
    assign pkt_data[24*8 +: 8] = {3'b0, i_idex_rs2_addr};

    // EX/MEM
    assign pkt_data[25*8 +: 8] = {4'b0, i_exmem_ctrl};
    assign pkt_data[26*8 +: 8] = i_exmem_alu[ 7: 0];
    assign pkt_data[27*8 +: 8] = i_exmem_alu[15: 8];
    assign pkt_data[28*8 +: 8] = i_exmem_alu[23:16];
    assign pkt_data[29*8 +: 8] = i_exmem_alu[31:24];
    assign pkt_data[30*8 +: 8] = i_exmem_data2[ 7: 0];
    assign pkt_data[31*8 +: 8] = i_exmem_data2[15: 8];
    assign pkt_data[32*8 +: 8] = i_exmem_data2[23:16];
    assign pkt_data[33*8 +: 8] = i_exmem_data2[31:24];
    assign pkt_data[34*8 +: 8] = {3'b0, i_exmem_rd_addr};

    // MEM/WB
    assign pkt_data[35*8 +: 8] = {6'b0, i_memwb_ctrl};
    assign pkt_data[36*8 +: 8] = i_memwb_data[ 7: 0];
    assign pkt_data[37*8 +: 8] = i_memwb_data[15: 8];
    assign pkt_data[38*8 +: 8] = i_memwb_data[23:16];
    assign pkt_data[39*8 +: 8] = i_memwb_data[31:24];
    assign pkt_data[40*8 +: 8] = i_memwb_alu[ 7: 0];
    assign pkt_data[41*8 +: 8] = i_memwb_alu[15: 8];
    assign pkt_data[42*8 +: 8] = i_memwb_alu[23:16];
    assign pkt_data[43*8 +: 8] = i_memwb_alu[31:24];
    assign pkt_data[44*8 +: 8] = {3'b0, i_memwb_rd_addr};

    // Output regs
    reg                        wr_out;
    reg                        tx_start_out;
    reg [NB_UART_DATA - 1 : 0] wdata_out;
    reg                        done_out;

    assign o_wr       = wr_out;
    assign o_tx_start = tx_start_out;
    assign o_wdata    = wdata_out;
    assign o_done     = done_out;

    always @(posedge clk) begin
        if (i_rst) begin
            state_reg    <= IDLE;
            byte_cnt_reg <= {NB_BYTECNT{1'b0}};
        end
        else begin
            state_reg    <= next_state;
            byte_cnt_reg <= byte_cnt_next;
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = state_reg;

        case (state_reg)
            IDLE: begin
                if (i_start) begin
                    next_state = SEND_BYTE;
                end
            end

            SEND_BYTE: begin
                next_state = WAIT_TXD;
            end

            WAIT_TXD: begin
                if (i_tx_done) begin
                    if (byte_cnt_reg == NB_BYTES - 1) begin
                        next_state = IDLE;
                    end
                    else begin
                        next_state = SEND_BYTE;
                    end
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath / output logic
    always @(*) begin
        wr_out        = 1'b0;
        tx_start_out  = 1'b0;
        wdata_out     = 8'h00;
        done_out      = 1'b0;
        byte_cnt_next = byte_cnt_reg;

        case (state_reg)
            IDLE: begin
                byte_cnt_next = {NB_BYTECNT{1'b0}};
            end

            SEND_BYTE: begin
                wr_out       = 1'b1;
                tx_start_out = 1'b1;
                wdata_out    = pkt_data[byte_cnt_reg*8 +: 8];
            end

            WAIT_TXD: begin
                if (i_tx_done) begin
                    if (byte_cnt_reg == NB_BYTES - 1) begin
                        done_out      = 1'b1;
                        byte_cnt_next = {NB_BYTECNT{1'b0}};
                    end
                    else begin
                        byte_cnt_next = byte_cnt_reg + 1'b1;
                    end
                end
            end

            default: begin
            end
        endcase
    end

endmodule
