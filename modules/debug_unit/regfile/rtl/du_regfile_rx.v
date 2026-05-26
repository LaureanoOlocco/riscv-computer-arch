//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_regfile_rx.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Register file receiver/writer over UART.
//                - Receives 4 bytes following a write command.
//                - Register address is provided by du_master on start.
//                - Writes the assembled 32-bit word to the regfile and pulses done.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module du_regfile_rx
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,  // NB of data width
  parameter                                                     NB_UART_DATA  = 8                   ,  // NB of UART data
  parameter                                                     NB_REG_ADDR   = 5                      // NB of register address
)   
(
//------------------------------------------ OUTPUTS ---------------------------------------------//
  output wire                                                   o_done                              ,  // Write done signal
  output wire                                                   o_regfile_wr                        ,  // Register file write enable
  output wire [NB_REG_ADDR                             - 1 : 0] o_regfile_waddr                     ,  // Register file write address
  output wire [NB_DATA                                 - 1 : 0] o_regfile_wdata                     ,  // Register file write data
//------------------------------------------- INPUTS ---------------------------------------------//
  input  wire                                                   i_start                             ,  // Start signal from master
  input  wire [NB_REG_ADDR                             - 1 : 0] i_waddr                             ,  // Write address from master
  input  wire                                                   i_rx_done                           ,  // UART RX byte received
  input  wire [NB_UART_DATA                            - 1 : 0] i_rx_data                           ,  // UART RX data byte
  input  wire                                                   i_rst                               ,
  input  wire                                                   clk   
)                                                                                                   ;

//---------------------------------------- local params ------------------------------------------//
  localparam                                                    NB_STATE      = 3                   ;  // Number of states in the FSM 
  localparam                                                    NB_BYTE_CNT   = 2                   ;  // Number of states in the FSM 
  localparam                                                    NB_WORD_BYTES = 4                   ;  // Number of states in the FSM   // bytes per 32-bit word

  localparam [NB_STATE                                 - 1 : 0] IDLE          = 3'b001              ;  // Number of states in the FSM 
  localparam [NB_STATE                                 - 1 : 0] RECV_DATA     = 3'b010              ;  // Number of states in the FSM 
  localparam [NB_STATE                                 - 1 : 0] WRITE_REG     = 3'b100              ;  // Number of states in the FSM 

//------------------------------------------ Registers -------------------------------------------//
  reg  [NB_STATE                                       - 1 : 0] state_reg                           ;
  reg  [NB_STATE                                       - 1 : 0] next_state                          ;

  reg  [NB_DATA                                        - 1 : 0] word_reg                            ;
  reg  [NB_DATA                                        - 1 : 0] word_next                           ;

  reg  [NB_BYTE_CNT                                    - 1 : 0] byte_cnt_reg                        ;
  reg  [NB_BYTE_CNT                                    - 1 : 0] byte_cnt_next                       ;

  reg  [NB_REG_ADDR                                    - 1 : 0] addr_reg                            ;
  reg  [NB_REG_ADDR                                    - 1 : 0] addr_next                           ;

  reg                                                           done_out                            ;
  reg                                                           regfile_wr_out                      ;

//--------------------------------------- Sequential logic ---------------------------------------//
  always @(posedge clk)
  begin
    if (i_rst)
    begin
      state_reg    <= IDLE                                                                          ;
      word_reg     <= {NB_DATA{1'b0}}                                                               ;
      byte_cnt_reg <= {NB_BYTE_CNT{1'b0}}                                                           ;
      addr_reg     <= {NB_REG_ADDR{1'b0}}                                                           ;
    end
    else
    begin
      state_reg    <= next_state                                                                    ;
      word_reg     <= word_next                                                                     ;
      byte_cnt_reg <= byte_cnt_next                                                                 ;
      addr_reg     <= addr_next                                                                     ;
    end
  end

//-------------------------------------- Next-state logic ---------------------------------------//
  always @(*)
  begin
    next_state = state_reg                                                                          ;

    case (state_reg)
      IDLE                                                                                          :
      begin
        if (i_start)
        begin
          next_state = RECV_DATA                                                                    ;
        end
      end

      RECV_DATA                                                                                     :
      begin
        if (i_rx_done && byte_cnt_reg == NB_WORD_BYTES - 1)
        begin
          next_state = WRITE_REG                                                                    ;
        end
      end

      WRITE_REG                                                                                     :
      begin
        next_state = IDLE                                                                           ;
      end

      default   : next_state = IDLE                                                                 ;
    endcase
  end

//------------------------------------ Output / datapath logic ----------------------------------//
  always @(*)
  begin
    // Defaults
    done_out       = 1'b0                                                                           ;
    regfile_wr_out = 1'b0                                                                           ;
    word_next      = word_reg                                                                       ;
    byte_cnt_next  = byte_cnt_reg                                                                   ;
    addr_next      = addr_reg                                                                       ;

    case (state_reg)
      IDLE                                                                                          :
      begin
        if (i_start)
        begin
          word_next     = {NB_DATA{1'b0}}                                                           ;
          byte_cnt_next = {NB_BYTE_CNT{1'b0}}                                                       ;
          addr_next     = i_waddr                                                                   ;
        end
      end

      RECV_DATA                                                                                     :
      begin
        if (i_rx_done)
        begin
          case (byte_cnt_reg)
            2'd0    : word_next[ 7 :  0] = i_rx_data                                                ;
            2'd1    : word_next[15 :  8] = i_rx_data                                                ;
            2'd2    : word_next[23 : 16] = i_rx_data                                                ;
            2'd3    : word_next[31 : 24] = i_rx_data                                                ;
            default :                                                                               ;
          endcase
          byte_cnt_next = byte_cnt_reg + 1'b1                                                       ;
        end
      end

      WRITE_REG                                                                                     :
      begin
        regfile_wr_out = 1'b1                                                                       ;
        done_out       = 1'b1                                                                       ;
      end

      default                                                                                       :
      begin
        // noop
      end
    endcase
  end

//--------------------------------------------- Outputs ------------------------------------------//
  assign o_regfile_waddr = addr_reg                                                                 ;
  assign o_regfile_wdata = word_reg                                                                 ;
  assign o_regfile_wr    = regfile_wr_out                                                           ;
  assign o_done          = done_out                                                                 ;

endmodule