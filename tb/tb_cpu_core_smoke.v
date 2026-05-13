`timescale 1ns / 1ps

module tb_cpu_core_smoke;

    localparam CLK_PERIOD = 10;

    reg         clk;
    reg         i_rst;
    reg         i_du_rst;
    reg         i_en;
    reg [31:0]  i_imem_data;
    reg [9:0]   i_imem_waddr;
    reg         i_imem_wen;
    reg         i_du_rgfile_rd;
    reg [4:0]   i_regfile_addr;
    reg [9:0]   i_dmem_raddr;
    reg [1:0]   i_dmem_rsize;
    reg         i_dmem_ren;

    wire [31:0] o_pc;
    wire [31:0] o_instr;
    wire [31:0] o_regfile_data;
    wire [31:0] o_dmem_data;

    wire [31:0] o_ifid_pc;
    wire [31:0] o_ifid_instr;
    wire [8:0]  o_idex_ctrl;
    wire [31:0] o_idex_rs1_data;
    wire [31:0] o_idex_rs2_data;
    wire [31:0] o_idex_imm;
    wire [4:0]  o_idex_rd_addr;
    wire [4:0]  o_idex_rs1_addr;
    wire [4:0]  o_idex_rs2_addr;
    wire [3:0]  o_exmem_ctrl;
    wire [31:0] o_exmem_alu;
    wire [31:0] o_exmem_data2;
    wire [4:0]  o_exmem_rd_addr;
    wire [1:0]  o_memwb_ctrl;
    wire [31:0] o_memwb_data;
    wire [31:0] o_memwb_alu;
    wire [4:0]  o_memwb_rd_addr;

    integer errors;
    integer cycle;

    cpu_core dut (
        .o_pc           (o_pc),
        .o_instr        (o_instr),
        .o_regfile_data (o_regfile_data),
        .o_dmem_data    (o_dmem_data),
        .o_ifid_pc       (o_ifid_pc),
        .o_ifid_instr    (o_ifid_instr),
        .o_idex_ctrl     (o_idex_ctrl),
        .o_idex_rs1_data (o_idex_rs1_data),
        .o_idex_rs2_data (o_idex_rs2_data),
        .o_idex_imm      (o_idex_imm),
        .o_idex_rd_addr  (o_idex_rd_addr),
        .o_idex_rs1_addr (o_idex_rs1_addr),
        .o_idex_rs2_addr (o_idex_rs2_addr),
        .o_exmem_ctrl    (o_exmem_ctrl),
        .o_exmem_alu     (o_exmem_alu),
        .o_exmem_data2   (o_exmem_data2),
        .o_exmem_rd_addr (o_exmem_rd_addr),
        .o_memwb_ctrl    (o_memwb_ctrl),
        .o_memwb_data    (o_memwb_data),
        .o_memwb_alu     (o_memwb_alu),
        .o_memwb_rd_addr (o_memwb_rd_addr),
        .i_imem_data     (i_imem_data),
        .i_imem_waddr    (i_imem_waddr),
        .i_imem_wen      (i_imem_wen),
        .i_du_rgfile_rd  (i_du_rgfile_rd),
        .i_regfile_addr  (i_regfile_addr),
        .i_dmem_raddr    (i_dmem_raddr),
        .i_dmem_rsize    (i_dmem_rsize),
        .i_dmem_ren      (i_dmem_ren),
        .i_en            (i_en),
        .i_du_rst        (i_du_rst),
        .i_rst           (i_rst),
        .clk             (clk)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    task write_imem;
        input [9:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            i_imem_waddr = addr;
            i_imem_data  = data;
            i_imem_wen   = 1'b1;
            @(posedge clk);
            i_imem_wen   = 1'b0;
        end
    endtask

    task read_reg;
        input [4:0] addr;
        output [31:0] data;
        begin
            i_regfile_addr = addr;
            i_du_rgfile_rd = 1'b1;
            @(posedge clk);
            #1;
            data = o_regfile_data;
            i_du_rgfile_rd = 1'b0;
        end
    endtask

    reg [31:0] x5;
    reg [31:0] x6;
    reg [31:0] x7;

    initial begin
        $dumpfile("tb_cpu_core_smoke.vcd");
        $dumpvars(0, tb_cpu_core_smoke);

        errors          = 0;
        i_rst           = 1'b1;
        i_du_rst        = 1'b0;
        i_en            = 1'b0;
        i_imem_data     = 32'h0;
        i_imem_waddr    = 10'h0;
        i_imem_wen      = 1'b0;
        i_du_rgfile_rd  = 1'b0;
        i_regfile_addr  = 5'h0;
        i_dmem_raddr    = 10'h0;
        i_dmem_rsize    = 2'b11;
        i_dmem_ren      = 1'b0;

        #(CLK_PERIOD * 5);
        i_rst = 1'b0;

        write_imem(10'd0, 32'h00100293); // addi x5, x0, 1
        write_imem(10'd1, 32'h00200313); // addi x6, x0, 2
        write_imem(10'd2, 32'h006283B3); // add  x7, x5, x6
        write_imem(10'd3, 32'h1A1A1A1A);

        @(posedge clk);
        i_du_rst = 1'b1;
        @(posedge clk);
        i_du_rst = 1'b0;

        i_en = 1'b1;
        for (cycle = 0; cycle < 20; cycle = cycle + 1) begin
            @(posedge clk);
        end
        i_en = 1'b0;

        read_reg(5'd5, x5);
        read_reg(5'd6, x6);
        read_reg(5'd7, x7);

        $display("PC=0x%08h instr=0x%08h x5=%0d x6=%0d x7=%0d", o_pc, o_instr, x5, x6, x7);

        if (x5 !== 32'd1) begin
            $display("ERROR: x5 expected 1");
            errors = errors + 1;
        end
        if (x6 !== 32'd2) begin
            $display("ERROR: x6 expected 2");
            errors = errors + 1;
        end
        if (x7 !== 32'd3) begin
            $display("ERROR: x7 expected 3");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("\n*** CPU CORE SMOKE TEST PASSED ***");
        else
            $display("\n*** %0d ERRORS ***", errors);

        $finish;
    end

endmodule
