//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_breakpoint.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Hardware breakpoint unit.
//                - Maintains N breakpoint slots with enable bits.
//                - Compares current PC against active breakpoints.
//                - Asserts o_bkp_hit on any match.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module du_breakpoint
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,  // NB of PC/address width
  parameter                                                     N_BKP         = 4                   // Number of breakpoint slots
)
(
//------------------------------------------ OUTPUTS ---------------------------------------------//
  output wire                                                   o_bkp_hit                           ,  // Breakpoint hit (PC matches any active bkp)
//------------------------------------------- INPUTS ---------------------------------------------//
  input  wire [NB_DATA                                 - 1 : 0] i_pc                                ,  // Current program counter
  input  wire                                                   i_set                               ,  // Set breakpoint pulse
  input  wire                                                   i_clr                               ,  // Clear breakpoint pulse
  input  wire [NB_DATA                                 - 1 : 0] i_bkp_addr                          ,  // Breakpoint address to set/clear
  input  wire                                                   i_rst                               ,
  input  wire                                                   clk   
)                                                                                                   ;

//---------------------------------------- local params ------------------------------------------//
  localparam                                                    NB_BKP_SEL    = $clog2(N_BKP)       ;

//------------------------------------------ Registers -------------------------------------------//
  reg  [NB_DATA                                        - 1 : 0] bkp_addr_reg  [0 : N_BKP - 1]       ;
  reg  [N_BKP                                          - 1 : 0] bkp_valid_reg                       ;
  reg  [N_BKP                                          - 1 : 0] hit_vec                             ;
  reg  [NB_BKP_SEL                                     - 1 : 0] free_slot                           ;
  reg                                                           free_found                          ;
  integer                                                       i                                   ;

//-------------------------------------- Combinational logic -------------------------------------//
  always @(*)
  begin
    for (i = 0; i < N_BKP; i = i + 1)
    begin
      hit_vec[i] = bkp_valid_reg[i] && (bkp_addr_reg[i] == i_pc)                                    ;
    end
  end

  always @(*)
  begin
    free_slot  = {NB_BKP_SEL{1'b0}}                                                                 ;
    free_found = 1'b0                                                                               ;
    for (i = 0; i < N_BKP; i = i + 1)
    begin
      if (!bkp_valid_reg[i] && !free_found)
      begin
        free_slot  = i[NB_BKP_SEL - 1 : 0]                                                          ;
        free_found = 1'b1                                                                           ;
      end
    end
  end

//--------------------------------------- Sequential logic ---------------------------------------//
  always @(posedge clk)
  begin
    if (i_rst)
    begin
      bkp_valid_reg <= {N_BKP{1'b0}}                                                                ;
      for (i = 0; i < N_BKP; i = i + 1)
      begin
        bkp_addr_reg[i] <= {NB_DATA{1'b0}}                                                          ;
      end
    end
    else
    begin
      if (i_set && free_found)
      begin
        bkp_addr_reg [free_slot] <= i_bkp_addr                                                      ;
        bkp_valid_reg[free_slot] <= 1'b1                                                            ;
      end
      else if (i_clr)
      begin
        for (i = 0; i < N_BKP; i = i + 1)
        begin
          if (bkp_valid_reg[i] && bkp_addr_reg[i] == i_bkp_addr)
          begin
            bkp_valid_reg[i] <= 1'b0                                                                ;
          end
        end
      end
    end
  end

//--------------------------------------------- Outputs ------------------------------------------//
  assign o_bkp_hit = |hit_vec                                                                       ;

endmodule