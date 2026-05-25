//! @title CPU SUBSYSTEM
//! @file cpu_subsystem.v
//! @author Laureano Olocco - Sofia Avalos
//! @date 2-2025
//! @version 2.0
//! @brief Top-level subsystem integrating the CPU core with the debug unit.
//!        Handles signal buffering and arbitration between cpu_core and
//!        debug_unit_top for shared resources (IMEM, DMEM, register file).

module cpu_subsystem
#(
    parameter NB_DATA           = 32,  //! Data width
    parameter NB_ADDR           = 8,   //! DU memory address width (NB_ADDR bits)
    parameter NB_PC             = 32,  //! Program counter width
    parameter NB_REG            = 32,  //! Register file data width
    parameter NB_UART_DATA      = 8,   //! UART data width
    parameter N_BKP             = 4,   //! Number of breakpoint slots
    parameter IMEM_ADDR_WIDTH   = 10,  //! IMEM address width (matches cpu_core)
    parameter DMEM_ADDR_WIDTH   = 10   //! DMEM address width (matches cpu_core)
) (
    // =====================================================================
    // Outputs — UART TX (from debug unit → UART module)
    // =====================================================================
    output wire                         o_tx_start        ,  //! UART TX start
    output wire                         o_uart_rd         ,  //! UART RX FIFO read enable
    output wire                         o_uart_wr         ,  //! UART TX FIFO write enable
    output wire [NB_UART_DATA - 1 : 0] o_uart_wdata      ,  //! UART TX FIFO write data

    // =====================================================================
    // Inputs — UART RX (from UART module → debug unit)
    // =====================================================================
    input wire                          i_rx_done         ,  //! UART RX byte received
    input wire [NB_UART_DATA - 1 : 0]  i_rx_data         ,  //! UART RX data byte
    input wire                          i_tx_done         ,  //! UART TX byte done
    input wire                          i_tx_fifo_empty   ,  //! UART TX FIFO empty (for drain wait)

    // =====================================================================
    // Inputs — External enable (e.g., PLL locked)
    // =====================================================================
    input wire                          i_en              ,

    // System
    input wire                          i_rst             ,
    input wire                          clk
);

    // =====================================================================
    // Internal Wires — CPU <-> Debug Unit
    // =====================================================================

    // CPU control from DU
    wire                            du_cpu_enable         ;
    wire                            du_cpu_reset          ;

    // IMEM write (DU → CPU)
    wire                            du_imem_wr            ;
    wire [NB_ADDR     - 1 : 0]     du_imem_waddr         ;
    wire [NB_DATA     - 1 : 0]     du_imem_wdata         ;

    // Regfile read (DU → CPU)
    wire                            du_regfile_rd         ;
    wire [4               : 0]      du_regfile_raddr      ;

    // Regfile write (DU → CPU)
    wire                            du_regfile_wr         ;
    wire [4               : 0]      du_regfile_waddr      ;
    wire [NB_REG      - 1 : 0]     du_regfile_wdata      ;

    // DMEM read (DU → CPU)
    wire                            du_dmem_rd            ;
    wire [NB_ADDR     - 1 : 0]     du_dmem_raddr         ;

    // DMEM write (DU → CPU)
    wire                            du_dmem_wr            ;
    wire [NB_ADDR     - 1 : 0]     du_dmem_waddr         ;
    wire [NB_DATA     - 1 : 0]     du_dmem_wdata         ;

    // Breakpoint hit (CPU → DU)
    wire                            du_bkp_hit            ;

    // CPU state observations (CPU → DU, buffered)
    wire [NB_PC       - 1 : 0]     cpu_pc_raw            ;
    wire [NB_DATA     - 1 : 0]     cpu_instr_raw         ;
    wire [NB_REG      - 1 : 0]     cpu_regfile_data_raw  ;
    wire [NB_DATA     - 1 : 0]     cpu_dmem_data_raw     ;

    // Pipeline latch observations (CPU → DU, direct — already registered inside core)
    wire [NB_PC       - 1 : 0]     cpu_ifid_pc           ;
    wire [NB_DATA     - 1 : 0]     cpu_ifid_instr        ;
    wire [8               : 0]      cpu_idex_ctrl         ;
    wire [NB_DATA     - 1 : 0]     cpu_idex_rs1_data     ;
    wire [NB_DATA     - 1 : 0]     cpu_idex_rs2_data     ;
    wire [NB_DATA     - 1 : 0]     cpu_idex_imm          ;
    wire [4               : 0]      cpu_idex_rd_addr      ;
    wire [4               : 0]      cpu_idex_rs1_addr     ;
    wire [4               : 0]      cpu_idex_rs2_addr     ;
    wire [3               : 0]      cpu_exmem_ctrl        ;
    wire [NB_DATA     - 1 : 0]     cpu_exmem_alu         ;
    wire [NB_DATA     - 1 : 0]     cpu_exmem_data2       ;
    wire [4               : 0]      cpu_exmem_rd_addr     ;
    wire [1               : 0]      cpu_memwb_ctrl        ;
    wire [NB_DATA     - 1 : 0]     cpu_memwb_data        ;
    wire [NB_DATA     - 1 : 0]     cpu_memwb_alu         ;
    wire [4               : 0]      cpu_memwb_rd_addr     ;

    // =====================================================================
    // Signal Buffering (1-cycle register for timing closure)
    // Pipeline-latch signals are also buffered to break long combinational
    // paths between cpu_core internal FFs and du_latch_tx FFs through two
    // hierarchy levels. CPU is held in halt during the latch dump, so the
    // extra cycle of latency does not affect program correctness.
    // =====================================================================
    reg [NB_PC    - 1 : 0]  pc_buf           ;
    reg [NB_DATA  - 1 : 0]  instr_buf        ;
    reg [NB_REG   - 1 : 0]  regfile_data_buf ;
    reg [NB_DATA  - 1 : 0]  dmem_data_buf    ;

    reg [NB_PC    - 1 : 0]  ifid_pc_buf       ;
    reg [NB_DATA  - 1 : 0]  ifid_instr_buf    ;
    reg [8           : 0]   idex_ctrl_buf     ;
    reg [NB_DATA  - 1 : 0]  idex_rs1_data_buf ;
    reg [NB_DATA  - 1 : 0]  idex_rs2_data_buf ;
    reg [NB_DATA  - 1 : 0]  idex_imm_buf      ;
    reg [4           : 0]   idex_rd_addr_buf  ;
    reg [4           : 0]   idex_rs1_addr_buf ;
    reg [4           : 0]   idex_rs2_addr_buf ;
    reg [3           : 0]   exmem_ctrl_buf    ;
    reg [NB_DATA  - 1 : 0]  exmem_alu_buf     ;
    reg [NB_DATA  - 1 : 0]  exmem_data2_buf   ;
    reg [4           : 0]   exmem_rd_addr_buf ;
    reg [1           : 0]   memwb_ctrl_buf    ;
    reg [NB_DATA  - 1 : 0]  memwb_data_buf    ;
    reg [NB_DATA  - 1 : 0]  memwb_alu_buf     ;
    reg [4           : 0]   memwb_rd_addr_buf ;

    always @(posedge clk) begin
        if (i_rst) begin
            pc_buf           <= {NB_PC{1'b0}}  ;
            instr_buf        <= {NB_DATA{1'b0}} ;
            regfile_data_buf <= {NB_REG{1'b0}}  ;
            dmem_data_buf    <= {NB_DATA{1'b0}} ;

            ifid_pc_buf       <= {NB_PC{1'b0}}   ;
            ifid_instr_buf    <= {NB_DATA{1'b0}} ;
            idex_ctrl_buf     <= 9'b0            ;
            idex_rs1_data_buf <= {NB_DATA{1'b0}} ;
            idex_rs2_data_buf <= {NB_DATA{1'b0}} ;
            idex_imm_buf      <= {NB_DATA{1'b0}} ;
            idex_rd_addr_buf  <= 5'b0            ;
            idex_rs1_addr_buf <= 5'b0            ;
            idex_rs2_addr_buf <= 5'b0            ;
            exmem_ctrl_buf    <= 4'b0            ;
            exmem_alu_buf     <= {NB_DATA{1'b0}} ;
            exmem_data2_buf   <= {NB_DATA{1'b0}} ;
            exmem_rd_addr_buf <= 5'b0            ;
            memwb_ctrl_buf    <= 2'b0            ;
            memwb_data_buf    <= {NB_DATA{1'b0}} ;
            memwb_alu_buf     <= {NB_DATA{1'b0}} ;
            memwb_rd_addr_buf <= 5'b0            ;
        end
        else begin
            pc_buf           <= cpu_pc_raw           ;
            instr_buf        <= cpu_instr_raw        ;
            regfile_data_buf <= cpu_regfile_data_raw ;
            dmem_data_buf    <= cpu_dmem_data_raw    ;

            ifid_pc_buf       <= cpu_ifid_pc       ;
            ifid_instr_buf    <= cpu_ifid_instr    ;
            idex_ctrl_buf     <= cpu_idex_ctrl     ;
            idex_rs1_data_buf <= cpu_idex_rs1_data ;
            idex_rs2_data_buf <= cpu_idex_rs2_data ;
            idex_imm_buf      <= cpu_idex_imm      ;
            idex_rd_addr_buf  <= cpu_idex_rd_addr  ;
            idex_rs1_addr_buf <= cpu_idex_rs1_addr ;
            idex_rs2_addr_buf <= cpu_idex_rs2_addr ;
            exmem_ctrl_buf    <= cpu_exmem_ctrl    ;
            exmem_alu_buf     <= cpu_exmem_alu     ;
            exmem_data2_buf   <= cpu_exmem_data2   ;
            exmem_rd_addr_buf <= cpu_exmem_rd_addr ;
            memwb_ctrl_buf    <= cpu_memwb_ctrl    ;
            memwb_data_buf    <= cpu_memwb_data    ;
            memwb_alu_buf     <= cpu_memwb_alu     ;
            memwb_rd_addr_buf <= cpu_memwb_rd_addr ;
        end
    end

    // =====================================================================
    // CPU Enable: external enable AND debug unit enable
    // =====================================================================
    wire cpu_en   = i_en & du_cpu_enable ;
    wire cpu_rst  = du_cpu_reset         ;

    // =====================================================================
    // CPU Core
    // =====================================================================
    cpu_core #(
        .NB_PC          (NB_PC),
        .NB_INSTRUCTION (NB_DATA),
        .NB_DATA        (NB_DATA),
        .NB_REG         (NB_REG),
        .IMEM_ADDR_WIDTH(IMEM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH(DMEM_ADDR_WIDTH)
    ) u_cpu_core (
        // Observation outputs → (buffered) → DU
        .o_pc           (cpu_pc_raw),
        .o_instr        (cpu_instr_raw),
        .o_regfile_data (cpu_regfile_data_raw),
        .o_dmem_data    (cpu_dmem_data_raw),

        // Pipeline latch observation
        .o_ifid_pc       (cpu_ifid_pc),
        .o_ifid_instr    (cpu_ifid_instr),
        .o_idex_ctrl     (cpu_idex_ctrl),
        .o_idex_rs1_data (cpu_idex_rs1_data),
        .o_idex_rs2_data (cpu_idex_rs2_data),
        .o_idex_imm      (cpu_idex_imm),
        .o_idex_rd_addr  (cpu_idex_rd_addr),
        .o_idex_rs1_addr (cpu_idex_rs1_addr),
        .o_idex_rs2_addr (cpu_idex_rs2_addr),
        .o_exmem_ctrl    (cpu_exmem_ctrl),
        .o_exmem_alu     (cpu_exmem_alu),
        .o_exmem_data2   (cpu_exmem_data2),
        .o_exmem_rd_addr (cpu_exmem_rd_addr),
        .o_memwb_ctrl    (cpu_memwb_ctrl),
        .o_memwb_data    (cpu_memwb_data),
        .o_memwb_alu     (cpu_memwb_alu),
        .o_memwb_rd_addr (cpu_memwb_rd_addr),

        // DU → IMEM write
        .i_imem_data    (du_imem_wdata),
        .i_imem_waddr   ({{(IMEM_ADDR_WIDTH - NB_ADDR){1'b0}}, du_imem_waddr}),
        .i_imem_wen     (du_imem_wr),

        // DU → Regfile read
        .i_du_rgfile_rd (du_regfile_rd),
        .i_regfile_addr (du_regfile_raddr),

        // DU → DMEM read
        .i_dmem_raddr   ({{(DMEM_ADDR_WIDTH - NB_ADDR){1'b0}}, du_dmem_raddr}),
        .i_dmem_rsize   (2'b11),           // full word (DU always reads 32-bit words)
        .i_dmem_ren     (du_dmem_rd),

        // Control
        .i_en           (cpu_en),
        .i_du_rst       (cpu_rst),
        .i_rst          (i_rst),
        .clk            (clk)
    );

    // =====================================================================
    // Debug Unit Top
    // =====================================================================
    debug_unit_top #(
        .NB_DATA      (NB_DATA),
        .NB_ADDR      (NB_ADDR),
        .NB_PC        (NB_PC),
        .NB_REG       (NB_REG),
        .NB_UART_DATA (NB_UART_DATA),
        .N_BKP        (N_BKP)
    ) u_debug_unit (
        // CPU control
        .o_cpu_enable    (du_cpu_enable),
        .o_cpu_reset     (du_cpu_reset),

        // IMEM write
        .o_imem_wr       (du_imem_wr),
        .o_imem_waddr    (du_imem_waddr),
        .o_imem_wdata    (du_imem_wdata),

        // Regfile read
        .o_regfile_rd    (du_regfile_rd),
        .o_regfile_raddr (du_regfile_raddr),

        // Regfile write
        .o_regfile_wr    (du_regfile_wr),
        .o_regfile_waddr (du_regfile_waddr),
        .o_regfile_wdata (du_regfile_wdata),

        // DMEM read
        .o_dmem_rd       (du_dmem_rd),
        .o_dmem_raddr    (du_dmem_raddr),

        // DMEM write
        .o_dmem_wr       (du_dmem_wr),
        .o_dmem_waddr    (du_dmem_waddr),
        .o_dmem_wdata    (du_dmem_wdata),

        // Breakpoint hit
        .o_bkp_hit       (du_bkp_hit),

        // UART TX
        .o_tx_start      (o_tx_start),
        .o_uart_rd       (o_uart_rd),
        .o_uart_wr       (o_uart_wr),
        .o_uart_wdata    (o_uart_wdata),

        // CPU state (buffered)
        .i_pc            (pc_buf),
        .i_instruction   (instr_buf),
        .i_regfile_data  (regfile_data_buf),
        .i_dmem_data     (dmem_data_buf),

        // Pipeline latch state (buffered for timing closure)
        .i_ifid_pc       (ifid_pc_buf),
        .i_ifid_instr    (ifid_instr_buf),
        .i_idex_ctrl     (idex_ctrl_buf),
        .i_idex_rs1_data (idex_rs1_data_buf),
        .i_idex_rs2_data (idex_rs2_data_buf),
        .i_idex_imm      (idex_imm_buf),
        .i_idex_rd_addr  (idex_rd_addr_buf),
        .i_idex_rs1_addr (idex_rs1_addr_buf),
        .i_idex_rs2_addr (idex_rs2_addr_buf),
        .i_exmem_ctrl    (exmem_ctrl_buf),
        .i_exmem_alu     (exmem_alu_buf),
        .i_exmem_data2   (exmem_data2_buf),
        .i_exmem_rd_addr (exmem_rd_addr_buf),
        .i_memwb_ctrl    (memwb_ctrl_buf),
        .i_memwb_data    (memwb_data_buf),
        .i_memwb_alu     (memwb_alu_buf),
        .i_memwb_rd_addr (memwb_rd_addr_buf),

        // UART RX / TX status
        .i_rx_done       (i_rx_done),
        .i_rx_data       (i_rx_data),
        .i_tx_done       (i_tx_done),
        .i_tx_fifo_empty (i_tx_fifo_empty),

        // System
        .i_rst           (i_rst),
        .clk             (clk)
    );

    // =====================================================================
    // NOTE: DU register write and DU DMEM write are not yet wired into
    // cpu_core because cpu_core currently handles regfile writes only
    // through the WB stage, and DMEM writes only through the MEM stage.
    // These DU write paths require mux arbitration inside cpu_core that
    // will be added in a future revision (du_regfile_wr, du_dmem_wr).
    // For now, the DU read paths (regfile + dmem) are fully connected.
    // =====================================================================

endmodule
