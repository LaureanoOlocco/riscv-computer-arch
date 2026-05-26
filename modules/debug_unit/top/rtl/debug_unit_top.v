//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : debug_unit_top.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Top-level container for the debug unit subsystem.
//                - Instantiates and connects all debug submodules.
//                - Routes CPU control, debug access, and UART paths.
//                - UART TX signals are OR-gated; only one submodule is active at a time.
//--------------------------------------------------------------------------------------------------
`default_nettype none

module debug_unit_top
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,  // NB of data width
  parameter                                                     NB_ADDR       = 8                   ,  // NB of memory address width
  parameter                                                     NB_PC         = 32                  ,  // NB of program counter
  parameter                                                     NB_REG        = 32                  ,  // NB of register data
  parameter                                                     NB_UART_DATA  = 8                   ,  // NB of UART data
  parameter                                                     N_BKP         = 4                      // Number of breakpoint slots
)
(
//------------------------------------------ OUTPUTS ---------------------------------------------//
  // CPU control
  output wire                                                   o_cpu_enable                        ,  // CPU pipeline enable
  output wire                                                   o_cpu_reset                         ,  // CPU reset pulse
  // Instruction memory write (du_imem_loader)    
  output wire                                                   o_imem_wr                           ,  // IMEM write enable
  output wire [NB_ADDR                                 - 1 : 0] o_imem_waddr                        ,  // IMEM write address
  output wire [NB_DATA                                 - 1 : 0] o_imem_wdata                        ,  // IMEM write data
  // Register file debug read
  output wire                                                   o_regfile_rd                        ,  // Regfile read enable
  output wire [4                                           : 0] o_regfile_raddr                     ,  // Regfile read address
  // Register file debug write
  output wire                                                   o_regfile_wr                        ,  // Regfile write enable
  output wire [4                                           : 0] o_regfile_waddr                     ,  // Regfile write address
  output wire [NB_REG                                  - 1 : 0] o_regfile_wdata                     ,  // Regfile write data
  // Data memory debug read   
  output wire                                                   o_dmem_rd                           ,  // DMEM read enable
  output wire [NB_ADDR                                -  1 : 0] o_dmem_raddr                        ,  // DMEM read address
  // Data memory debug write
  output wire                                                   o_dmem_wr                           ,  // DMEM write enable
  output wire [NB_ADDR                                 - 1 : 0] o_dmem_waddr                        ,  // DMEM write address
  output wire [NB_DATA                                 - 1 : 0] o_dmem_wdata                        ,  // DMEM write data
  // Breakpoint
  output wire                                                   o_bkp_hit                           ,  // Breakpoint hit signal
  // UART TX (multiplexed)    
  output wire                                                   o_tx_start                          ,  // UART Tx start
  output wire                                                   o_uart_rd                           ,  // UART FIFO RX read enable
  output wire                                                   o_uart_wr                           ,  // UART FIFO TX write enable
  output wire [NB_UART_DATA                            - 1 : 0] o_uart_wdata                        ,  // UART FIFO TX write data
//------------------------------------------- INPUTS ---------------------------------------------//
  // CPU state
  input  wire [NB_PC                                   - 1 : 0] i_pc                                ,  // Current PC
  input  wire [NB_DATA                                 - 1 : 0] i_instruction                       ,  // Current instruction
  input  wire [NB_REG                                  - 1 : 0] i_regfile_data                      ,  // Register read data
  input  wire [NB_DATA                                 - 1 : 0] i_dmem_data                         ,  // Data memory read data
  // Pipeline latch state   
  input  wire [NB_PC                                   - 1 : 0] i_ifid_pc                           ,
  input  wire [NB_DATA                                 - 1 : 0] i_ifid_instr                        ,
  input  wire [8                                           : 0] i_idex_ctrl                         ,
  input  wire [NB_DATA                                 - 1 : 0] i_idex_rs1_data                     ,
  input  wire [NB_DATA                                 - 1 : 0] i_idex_rs2_data                     ,
  input  wire [NB_DATA                                 - 1 : 0] i_idex_imm                          ,
  input  wire [4                                           : 0] i_idex_rd_addr                      ,
  input  wire [4                                           : 0] i_idex_rs1_addr                     ,
  input  wire [4                                           : 0] i_idex_rs2_addr                     ,
  input  wire [3                                           : 0] i_exmem_ctrl                        ,
  input  wire [NB_DATA                                 - 1 : 0] i_exmem_alu                         ,
  input  wire [NB_DATA                                 - 1 : 0] i_exmem_data2                       ,
  input  wire [4                                           : 0] i_exmem_rd_addr                     ,
  input  wire [1                                           : 0] i_memwb_ctrl                        ,
  input  wire [NB_DATA                                 - 1 : 0] i_memwb_data                        ,
  input  wire [NB_DATA                                 - 1 : 0] i_memwb_alu                         ,
  input  wire [4                                           : 0] i_memwb_rd_addr                     ,
  // UART RX    
  input  wire                                                   i_rx_done                           ,  // UART RX byte received
  input  wire [NB_UART_DATA                            - 1 : 0] i_rx_data                           ,  // UART RX data byte
  input  wire                                                   i_tx_done                           ,  // UART TX done signal
  input  wire                                                   i_tx_fifo_empty                     ,  // UART TX FIFO empty (drain done)
  // System   
  input  wire                                                   i_rst                               ,
  input  wire                                                   clk   
)                                                                                                   ;

//---------------------------------------- local params ------------------------------------------//
  localparam                                                    NB_DU_STATE   = 17                  ;
  localparam                                                    NB_STEP_CNT   = 32                  ;

//-------------------------------------- Internal wires ------------------------------------------//
  // du_master → submodules
  wire                                                          master_imem_loader_start            ;
  wire                                                          master_regfile_tx_start             ;
  wire                                                          master_dmem_tx_start                ;
  wire                                                          master_latch_tx_start               ;
  wire                                                          master_regfile_rx_start             ;
  wire [4                                             : 0]      master_regfile_rx_addr              ;
  wire                                                          master_dmem_rx_start                ;
  wire [NB_DATA                                   - 1 : 0]      master_dmem_rx_addr                 ;
  wire                                                          master_regfile_rd                   ;
  wire [4                                             : 0]      master_regfile_raddr                ;
  wire                                                          master_mem_rd                       ;
  wire [NB_ADDR                                   - 1 : 0]      master_mem_raddr                    ;
  wire                                                          master_bkp_set                      ;
  wire                                                          master_bkp_clr                      ;
  wire [NB_DATA                                   - 1 : 0]      master_bkp_addr                     ;
  wire                                                          master_resp_valid                   ;
  wire [NB_UART_DATA                              - 1 : 0]      master_resp_status                  ;
  wire [NB_DATA                                   - 1 : 0]      master_resp_data                    ;
  wire                                                          master_cpu_enable                   ;
  wire                                                          master_cpu_reset                    ;
  // du_imem_loader outputs
  wire                                                          imem_loader_done                    ;
  wire                                                          imem_loader_mem_wr                  ;
  wire [NB_ADDR                                   - 1 : 0]      imem_loader_mem_waddr               ;
  wire [NB_DATA                                   - 1 : 0]      imem_loader_mem_wdata               ;
  // du_regfile_tx outputs    
  wire                                                          regfile_tx_done                     ;
  wire                                                          regfile_tx_tx_start                 ;
  wire                                                          regfile_tx_wr                       ;
  wire [NB_UART_DATA                              - 1 : 0]      regfile_tx_wdata                    ;
  wire                                                          regfile_tx_regfile_rd               ;
  wire [4                                             : 0]      regfile_tx_regfile_raddr            ;
  // du_dmem_tx outputs
  wire                                                          dmem_tx_done                        ;  
  wire                                                          dmem_tx_tx_start                    ;
  wire                                                          dmem_tx_wr                          ;
  wire [NB_UART_DATA                              - 1 : 0]      dmem_tx_wdata                       ;
  wire                                                          dmem_tx_mem_rd                      ;
  wire [NB_ADDR                                   - 1 : 0]      dmem_tx_mem_raddr                   ;
  // du_latch_tx outputs    
  wire                                                          latch_tx_done                       ;
  wire                                                          latch_tx_tx_start                   ;
  wire                                                          latch_tx_wr                         ;
  wire [NB_UART_DATA                              - 1 : 0]      latch_tx_wdata                      ;
  // du_regfile_rx outputs    
  wire                                                          regfile_rx_done                     ;
  wire                                                          regfile_rx_wr                       ;
  wire [4                                             : 0]      regfile_rx_waddr                    ;
  wire [NB_REG                                    - 1 : 0]      regfile_rx_wdata                    ;
  // du_dmem_rx outputs
  wire                                                          dmem_rx_done                        ;
  wire                                                          dmem_rx_wr                          ;
  wire [NB_ADDR                                   - 1 : 0]      dmem_rx_waddr                       ;
  wire [NB_DATA                                   - 1 : 0]      dmem_rx_wdata                       ;
  // du_resp_builder outputs    
  wire                                                          resp_done                           ;
  wire                                                          resp_tx_start                       ;
  wire                                                          resp_wr                             ;
  wire [NB_UART_DATA                              - 1 : 0]      resp_wdata                          ;
  // du_breakpoint outputs    
  wire                                                          bkp_hit                             ;

//--------------------------------------- RX pulse generation ------------------------------------//
  // Convert level i_rx_done (= ~rx_fifo_empty) to a 1-cycle pulse and pop the FIFO.
  reg                                                           rx_done_pulse_r                     ;

  always @(posedge clk)
  begin
    if (i_rst)
    begin
      rx_done_pulse_r <= 1'b0                                                                       ;
    end
    else
    begin
      rx_done_pulse_r <= i_rx_done & ~rx_done_pulse_r                                               ;
    end
  end

  wire   rx_done_pulse                                                                              ;
  assign rx_done_pulse = rx_done_pulse_r                                                            ;

//------------------------------------ Module instantiations -------------------------------------//
  // Master Controller
  du_master #(
    .NB_UART_DATA         (NB_UART_DATA                                                          ),
    .NB_DATA              (NB_DATA                                                               ),
    .NB_ADDR              (NB_ADDR                                                               ),
    .NB_STATE             (NB_DU_STATE                                                           ),
    .NB_STEP_CNT          (NB_STEP_CNT                                                           )
  ) u_master (
    .o_cpu_enable         (master_cpu_enable                                                     ),
    .o_cpu_reset          (master_cpu_reset                                                      ),
    .o_imem_loader_start  (master_imem_loader_start                                              ),
    .o_regfile_tx_start   (master_regfile_tx_start                                               ),
    .o_dmem_tx_start      (master_dmem_tx_start                                                  ),
    .o_latch_tx_start     (master_latch_tx_start                                                 ),
    .o_regfile_rd         (master_regfile_rd                                                     ),
    .o_regfile_raddr      (master_regfile_raddr                                                  ),
    .o_regfile_rx_start   (master_regfile_rx_start                                               ),
    .o_regfile_rx_addr    (master_regfile_rx_addr                                                ),
    .o_dmem_rx_start      (master_dmem_rx_start                                                  ),
    .o_dmem_rx_addr       (master_dmem_rx_addr                                                   ),
    .o_mem_rd             (master_mem_rd                                                         ),
    .o_mem_raddr          (master_mem_raddr                                                      ),
    .o_bkp_set            (master_bkp_set                                                        ),
    .o_bkp_clr            (master_bkp_clr                                                        ),
    .o_bkp_addr           (master_bkp_addr                                                       ),
    .o_resp_valid         (master_resp_valid                                                     ),
    .o_resp_status        (master_resp_status                                                    ),
    .o_resp_data          (master_resp_data                                                      ),
    .i_imem_loader_done   (imem_loader_done                                                      ),
    .i_regfile_tx_done    (regfile_tx_done                                                       ),
    .i_dmem_tx_done       (dmem_tx_done                                                          ),
    .i_latch_tx_done      (latch_tx_done                                                         ),
    .i_regfile_rx_done    (regfile_rx_done                                                       ),
    .i_dmem_rx_done       (dmem_rx_done                                                          ),
    .i_pc                 (i_pc                                                                  ),
    .i_instruction        (i_instruction                                                         ),
    .i_regfile_data       (i_regfile_data                                                        ),
    .i_mem_data           (i_dmem_data                                                           ),
    .i_bkp_hit            (bkp_hit                                                               ),
    .i_rx_done            (rx_done_pulse                                                         ),
    .i_rx_data            (i_rx_data                                                             ),
    .i_tx_fifo_empty      (i_tx_fifo_empty                                                       ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Instruction Memory Loader
  du_imem_loader #(
    .NB_DATA              (NB_DATA                                                               ),
    .NB_ADDR              (NB_ADDR                                                               ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_imem_loader (
    .o_done               (imem_loader_done                                                      ),
    .o_mem_wr             (imem_loader_mem_wr                                                    ),
    .o_mem_waddr          (imem_loader_mem_waddr                                                 ),
    .o_mem_wdata          (imem_loader_mem_wdata                                                 ),
    .i_start              (master_imem_loader_start                                              ),
    .i_rx_done            (rx_done_pulse                                                         ),
    .i_rx_data            (i_rx_data                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Register File Transmitter (full dump)
  du_regfile_tx #(
    .NB_PC                (NB_PC                                                                 ),
    .NB_REG               (NB_REG                                                                ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_regfile_tx (
    .o_done               (regfile_tx_done                                                       ),
    .o_tx_start           (regfile_tx_tx_start                                                   ),
    .o_wr                 (regfile_tx_wr                                                         ),
    .o_wdata              (regfile_tx_wdata                                                      ),
    .o_regfile_rd         (regfile_tx_regfile_rd                                                 ),
    .o_regfile_raddr      (regfile_tx_regfile_raddr                                              ),
    .i_start              (master_regfile_tx_start                                               ),
    .i_pc                 (i_pc                                                                  ),
    .i_regfile_data       (i_regfile_data                                                        ),
    .i_tx_done            (i_tx_done                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Data Memory Transmitter (full dump)
  du_dmem_tx #(
    .NB_DATA              (NB_DATA                                                               ),
    .NB_ADDR              (NB_ADDR                                                               ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_dmem_tx (
    .o_done               (dmem_tx_done                                                          ),
    .o_tx_start           (dmem_tx_tx_start                                                      ),
    .o_wr                 (dmem_tx_wr                                                            ),
    .o_wdata              (dmem_tx_wdata                                                         ),
    .o_mem_rd             (dmem_tx_mem_rd                                                        ),
    .o_mem_raddr          (dmem_tx_mem_raddr                                                     ),
    .i_start              (master_dmem_tx_start                                                  ),
    .i_mem_data           (i_dmem_data                                                           ),
    .i_tx_done            (i_tx_done                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Pipeline Latch Transmitter (full dump of all 4 pipeline registers)
  du_latch_tx #(
    .NB_DATA              (NB_DATA                                                               ),
    .NB_PC                (NB_PC                                                                 ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_latch_tx (
    .o_done               (latch_tx_done                                                         ),
    .o_tx_start           (latch_tx_tx_start                                                     ),
    .o_wr                 (latch_tx_wr                                                           ),
    .o_wdata              (latch_tx_wdata                                                        ),
    .i_start              (master_latch_tx_start                                                 ),
    .i_ifid_pc            (i_ifid_pc                                                             ),
    .i_ifid_instr         (i_ifid_instr                                                          ),
    .i_idex_ctrl          (i_idex_ctrl                                                           ),
    .i_idex_rs1_data      (i_idex_rs1_data                                                       ),
    .i_idex_rs2_data      (i_idex_rs2_data                                                       ),
    .i_idex_imm           (i_idex_imm                                                            ),
    .i_idex_rd_addr       (i_idex_rd_addr                                                        ),
    .i_idex_rs1_addr      (i_idex_rs1_addr                                                       ),
    .i_idex_rs2_addr      (i_idex_rs2_addr                                                       ),
    .i_exmem_ctrl         (i_exmem_ctrl                                                          ),
    .i_exmem_alu          (i_exmem_alu                                                           ),
    .i_exmem_data2        (i_exmem_data2                                                         ),
    .i_exmem_rd_addr      (i_exmem_rd_addr                                                       ),
    .i_memwb_ctrl         (i_memwb_ctrl                                                          ),
    .i_memwb_data         (i_memwb_data                                                          ),
    .i_memwb_alu          (i_memwb_alu                                                           ),
    .i_memwb_rd_addr      (i_memwb_rd_addr                                                       ),
    .i_tx_done            (i_tx_done                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Register File Receiver (write single register)
  du_regfile_rx #(
    .NB_DATA              (NB_DATA                                                               ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_regfile_rx (
    .o_done               (regfile_rx_done                                                       ),
    .o_regfile_wr         (regfile_rx_wr                                                         ),
    .o_regfile_waddr      (regfile_rx_waddr                                                      ),
    .o_regfile_wdata      (regfile_rx_wdata                                                      ),
    .i_start              (master_regfile_rx_start                                               ),
    .i_waddr              (master_regfile_rx_addr                                                ),
    .i_rx_done            (rx_done_pulse                                                         ),
    .i_rx_data            (i_rx_data                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Data Memory Receiver (write single word)
  du_dmem_rx #(
    .NB_DATA              (NB_DATA                                                               ),
    .NB_ADDR              (NB_ADDR                                                               ),
    .NB_UART_DATA         (NB_UART_DATA                                                          )
  ) u_dmem_rx (
    .o_done               (dmem_rx_done                                                          ),
    .o_dmem_wr            (dmem_rx_wr                                                            ),
    .o_dmem_waddr         (dmem_rx_waddr                                                         ),
    .o_dmem_wdata         (dmem_rx_wdata                                                         ),
    .i_start              (master_dmem_rx_start                                                  ),
    .i_waddr              (master_dmem_rx_addr                                                   ),
    .i_rx_done            (rx_done_pulse                                                         ),
    .i_rx_data            (i_rx_data                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Response Builder (5-byte response serializer)
  du_resp_builder #(
    .NB_UART_DATA         (NB_UART_DATA                                                          ),
    .NB_DATA              (NB_DATA                                                               )
  ) u_resp_builder (
    .o_done               (resp_done                                                             ),
    .o_tx_start           (resp_tx_start                                                         ),
    .o_wr                 (resp_wr                                                               ),
    .o_wdata              (resp_wdata                                                            ),
    .i_valid              (master_resp_valid                                                     ),
    .i_status             (master_resp_status                                                    ),
    .i_data               (master_resp_data                                                      ),
    .i_tx_done            (i_tx_done                                                             ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
  // Hardware Breakpoint Unit
  du_breakpoint #(
    .NB_DATA              (NB_DATA                                                               ),
    .N_BKP                (N_BKP                                                                 )
  ) u_breakpoint (
    .o_bkp_hit            (bkp_hit                                                               ),
    .i_pc                 (i_pc                                                                  ),
    .i_set                (master_bkp_set                                                        ),
    .i_clr                (master_bkp_clr                                                        ),
    .i_bkp_addr           (master_bkp_addr                                                       ),
    .i_rst                (i_rst                                                                 ),
    .clk                  (clk                                                                   )
  );
 
//--------------------------------------- Output multiplexing -----------------------------------//
  // CPU control
  assign o_cpu_enable    = master_cpu_enable                                                     ;
  assign o_cpu_reset     = master_cpu_reset                                                      ;
  // Instruction memory write (only du_imem_loader writes to IMEM)
  assign o_imem_wr       = imem_loader_mem_wr                                                    ;
  assign o_imem_waddr    = imem_loader_mem_waddr                                                 ;
  assign o_imem_wdata    = imem_loader_mem_wdata                                                 ;
  // Register file read (master single-reg read OR regfile_tx full dump)
  assign o_regfile_rd    = master_regfile_rd    | regfile_tx_regfile_rd                          ;
  assign o_regfile_raddr = master_regfile_raddr | regfile_tx_regfile_raddr                       ;
  // Register file write (du_regfile_rx)
  assign o_regfile_wr    = regfile_rx_wr                                                         ;
  assign o_regfile_waddr = regfile_rx_waddr                                                      ;
  assign o_regfile_wdata = regfile_rx_wdata                                                      ;
  // Data memory read (master single-word read OR dmem_tx full dump)
  assign o_dmem_rd       = master_mem_rd    | dmem_tx_mem_rd                                     ;
  assign o_dmem_raddr    = master_mem_raddr | dmem_tx_mem_raddr                                  ;
  // Data memory write (du_dmem_rx)
  assign o_dmem_wr       = dmem_rx_wr                                                            ;
  assign o_dmem_waddr    = dmem_rx_waddr                                                         ;
  assign o_dmem_wdata    = dmem_rx_wdata                                                         ;
  // Breakpoint hit
  assign o_bkp_hit       = bkp_hit                                                               ;
  // UART TX multiplexing (OR-gating — only one submodule active at a time)
  assign o_tx_start      = regfile_tx_tx_start | dmem_tx_tx_start | latch_tx_tx_start | resp_tx_start ;
  assign o_uart_rd       = rx_done_pulse_r                                                       ;  // pop RX FIFO each consumed byte
  assign o_uart_wr       = regfile_tx_wr       | dmem_tx_wr       | latch_tx_wr       | resp_wr  ;
  assign o_uart_wdata    = regfile_tx_wdata    | dmem_tx_wdata    | latch_tx_wdata    | resp_wdata ;

endmodule