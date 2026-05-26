//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_resp_builder.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Response frame serializer over UART.
//                - Formats a 5-byte response: status + 32-bit data.
//                - Latches inputs on i_valid and streams bytes little-endian.
//                - Asserts done after the last byte is transmitted.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module du_resp_builder
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_UART_DATA  = 8                   ,  // NB of UART data
  parameter                                                     NB_DATA       = 32                     // NB of data width
)
(
//------------------------------------------ OUTPUTS ---------------------------------------------//
  output reg                                                    o_done                            ,  // Response transmission done
  output reg                                                    o_tx_start                        ,  // UART Tx start
  output reg                                                    o_wr                              ,  // UART FIFO Tx write enable
  output reg  [NB_UART_DATA                           - 1 : 0] o_wdata                            ,  // UART FIFO Tx write data
//------------------------------------------- INPUTS ---------------------------------------------//
  input  wire                                                   i_valid                           ,  // Response valid pulse (latch inputs)
  input  wire [NB_UART_DATA                           - 1 : 0] i_status                           ,  // Response status byte
  input  wire [NB_DATA                                - 1 : 0] i_data                             ,  // Response data (32 bits)
  input  wire                                                   i_tx_done                         ,  // UART Tx done signal
  input  wire                                                   i_rst                             ,
  input  wire                                                   clk
)                                                                                                 ;

//---------------------------------------- local params ------------------------------------------//
  localparam                                                    NB_STATE      = 3                 ;
  localparam                                                    NB_COUNTER    = 3                 ;
  localparam                                                    NB_RESP_BYTES = 5                 ;  // status + 4 data bytes

  localparam [NB_STATE                                 - 1 : 0] IDLE          = 3'b001            ;
  localparam [NB_STATE                                 - 1 : 0] SEND_BYTE     = 3'b010            ;
  localparam [NB_STATE                                 - 1 : 0] WAIT_TX       = 3'b100            ;

//------------------------------------------ Registers -------------------------------------------//
  reg  [NB_STATE                                      - 1 : 0] state_reg                          ;
  reg  [NB_STATE                                      - 1 : 0] next_state                         ;

  reg  [NB_UART_DATA                                  - 1 : 0] status_reg                         ;
  reg  [NB_UART_DATA                                  - 1 : 0] status_next                        ;
  reg  [NB_DATA                                       - 1 : 0] data_reg                           ;
  reg  [NB_DATA                                       - 1 : 0] data_next                          ;

  reg  [NB_COUNTER                                    - 1 : 0] byte_cnt_reg                       ;
  reg  [NB_COUNTER                                    - 1 : 0] byte_cnt_next                      ;

//--------------------------------------- Sequential logic ---------------------------------------//
  always @(posedge clk)
  begin
    if (i_rst)
    begin
      state_reg    <= IDLE                                                                        ;
      status_reg   <= {NB_UART_DATA{1'b0}}                                                        ;
      data_reg     <= {NB_DATA{1'b0}}                                                             ;
      byte_cnt_reg <= {NB_COUNTER{1'b0}}                                                          ;
    end
    else
    begin
      state_reg    <= next_state                                                                  ;
      status_reg   <= status_next                                                                 ;
      data_reg     <= data_next                                                                   ;
      byte_cnt_reg <= byte_cnt_next                                                               ;
    end
  end

//-------------------------------------- Next-state logic ---------------------------------------//
  always @(*)
  begin
    next_state = state_reg                                                                        ;

    case (state_reg)
      IDLE                                                                                        :
      begin
        if (i_valid)
        begin
          next_state = SEND_BYTE                                                                  ;
        end
      end

      SEND_BYTE                                                                                   :
      begin
        next_state = WAIT_TX                                                                      ;
      end

      WAIT_TX                                                                                     :
      begin
        if (i_tx_done)
        begin
          if (byte_cnt_reg == NB_RESP_BYTES)
          begin
            next_state = IDLE                                                                     ;
          end
          else
          begin
            next_state = SEND_BYTE                                                                ;
          end
        end
      end

      default   : next_state = IDLE                                                               ;
    endcase
  end

//------------------------------------ Output / datapath logic ----------------------------------//
  always @(*)
  begin
    // Defaults
    o_done        = 1'b0                                                                          ;
    o_tx_start    = 1'b0                                                                          ;
    o_wr          = 1'b0                                                                          ;
    o_wdata       = {NB_UART_DATA{1'b0}}                                                          ;
    status_next   = status_reg                                                                    ;
    data_next     = data_reg                                                                      ;
    byte_cnt_next = byte_cnt_reg                                                                  ;

    case (state_reg)
      IDLE      :
      begin
        byte_cnt_next = {NB_COUNTER{1'b0}}                                                        ;
        if (i_valid)
        begin
          status_next = i_status                                                                  ;
          data_next   = i_data                                                                    ;
        end
      end

      SEND_BYTE :
      begin
        o_wr          = 1'b1                                                                      ;
        o_tx_start    = 1'b1                                                                      ;
        byte_cnt_next = byte_cnt_reg + 1'b1                                                       ;

        case (byte_cnt_reg)
          3'd0    : o_wdata = status_reg                                                          ;
          3'd1    : o_wdata = data_reg[ 7 :  0]                                                   ;
          3'd2    : o_wdata = data_reg[15 :  8]                                                   ;
          3'd3    : o_wdata = data_reg[23 : 16]                                                   ;
          3'd4    : o_wdata = data_reg[31 : 24]                                                   ;
          default : o_wdata = {NB_UART_DATA{1'b0}}                                                ;
        endcase
      end

      WAIT_TX                                                                                     :
      begin
        if (i_tx_done && byte_cnt_reg == NB_RESP_BYTES)
        begin
          o_done = 1'b1                                                                           ;
        end
      end

      default                                                                                     :
      begin
        // noop
      end
    endcase
  end

endmodule