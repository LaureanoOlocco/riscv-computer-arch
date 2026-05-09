//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : du_master.v
// Date        : 2025-02
// Author      : Sofia Avalos - Laureano Olocco
// Description : Interactive command-based debug controller.
//                - Receives 6-byte command frames (opcode + 32-bit payload + XOR checksum).
//                - Dispatches to loaders/tx/rx/breakpoint control and CPU run/step/halt/reset.
//                - Builds 5-byte responses (status + 32-bit data) via du_resp_builder.
//--------------------------------------------------------------------------------------------------

module du_master
#(
    parameter NB_UART_DATA  = 8,   // NB of UART data
    parameter NB_DATA       = 32,  // NB of data width
    parameter NB_ADDR       = 8,   // NB of memory address width
    parameter NB_STATE      = 16,  // NB of FSM states (one-hot)
    parameter NB_STEP_CNT   = 32,  // NB of step counter
    parameter HALT_INST     = 32'h1A1A1A1A  // Halt instruction
) (
    // Outputs — CPU control
    output reg                         o_cpu_enable        ,  // CPU pipeline enable
    output reg                         o_cpu_reset         ,  // CPU reset pulse
    output reg                         o_imem_loader_start ,  // Start du_imem_loader
    output reg                         o_regfile_tx_start  ,  // Start du_regfile_tx (full dump)
    output reg                         o_dmem_tx_start     ,  // Start du_dmem_tx
    output reg                         o_regfile_rd        ,  // Register file read enable
    output reg [4 : 0]                 o_regfile_raddr     ,  // Register file read address
    output reg                         o_regfile_rx_start  ,  // Start du_regfile_rx
    output reg [4 : 0]                 o_regfile_rx_addr   ,  // Register write address
    output reg                         o_dmem_rx_start     ,  // Start du_dmem_rx
    output reg [NB_DATA - 1 : 0]       o_dmem_rx_addr      ,  // Memory write address
    output reg                         o_mem_rd            ,  // Memory read enable
    output reg [NB_ADDR - 1 : 0]       o_mem_raddr         ,  // Memory read address
    output reg                         o_bkp_set           ,  // Set breakpoint
    output reg                         o_bkp_clr           ,  // Clear breakpoint
    output reg [NB_DATA - 1 : 0]       o_bkp_addr          ,  // Breakpoint address
    output reg                         o_resp_valid        ,  // Response valid pulse
    output reg [NB_UART_DATA - 1 : 0]  o_resp_status       ,  // Response status byte
    output reg [NB_DATA - 1 : 0]       o_resp_data         ,  // Response data
    
    input wire                         i_imem_loader_done  ,  // du_imem_loader done
    input wire                         i_regfile_tx_done   ,  // du_regfile_tx done
    input wire                         i_dmem_tx_done      ,  // du_dmem_tx done
    input wire                         i_regfile_rx_done   ,  // du_regfile_rx done
    input wire                         i_dmem_rx_done      ,  // du_dmem_rx done
    input wire [NB_DATA - 1 : 0]       i_pc                ,  // Current PC
    input wire [NB_DATA - 1 : 0]       i_instruction       ,  // Current instruction
    input wire [NB_DATA - 1 : 0]       i_regfile_data      ,  // Register read data
    input wire [NB_DATA - 1 : 0]       i_mem_data          ,  // Memory read data
    input wire                         i_bkp_hit           ,  // Breakpoint hit signal
    input wire                         i_rx_done           ,  // UART RX byte received
    input wire [NB_UART_DATA - 1 : 0]  i_rx_data           ,  // UART RX data byte
    input wire                         i_rst               ,
    input wire                         clk
);

    localparam [NB_UART_DATA - 1 : 0] CMD_LOAD_FW   = 8'h01;
    localparam [NB_UART_DATA - 1 : 0] CMD_RUN       = 8'h02;
    localparam [NB_UART_DATA - 1 : 0] CMD_STEP      = 8'h03;
    localparam [NB_UART_DATA - 1 : 0] CMD_HALT      = 8'h04;
    localparam [NB_UART_DATA - 1 : 0] CMD_READ_REG  = 8'h05;
    localparam [NB_UART_DATA - 1 : 0] CMD_READ_MEM  = 8'h06;
    localparam [NB_UART_DATA - 1 : 0] CMD_WRITE_REG = 8'h07;
    localparam [NB_UART_DATA - 1 : 0] CMD_WRITE_MEM = 8'h08;
    localparam [NB_UART_DATA - 1 : 0] CMD_SET_BKP   = 8'h09;
    localparam [NB_UART_DATA - 1 : 0] CMD_CLR_BKP   = 8'h0A;
    localparam [NB_UART_DATA - 1 : 0] CMD_RESET     = 8'h0B;
    localparam [NB_UART_DATA - 1 : 0] CMD_STATUS    = 8'h0F;
    localparam [NB_UART_DATA - 1 : 0] STATUS_OK    = 8'h00;
    localparam [NB_UART_DATA - 1 : 0] STATUS_ERROR = 8'h01;
    localparam [NB_UART_DATA - 1 : 0] STATUS_BUSY  = 8'h02;
    localparam [NB_STATE - 1 : 0] S_IDLE       = 16'h0001;
    localparam [NB_STATE - 1 : 0] S_RECV_CMD   = 16'h0002;
    localparam [NB_STATE - 1 : 0] S_VALIDATE   = 16'h0004;
    localparam [NB_STATE - 1 : 0] S_DISPATCH   = 16'h0008;
    localparam [NB_STATE - 1 : 0] S_LOAD_FW    = 16'h0010;
    localparam [NB_STATE - 1 : 0] S_EXECUTING  = 16'h0020;
    localparam [NB_STATE - 1 : 0] S_STEPPING   = 16'h0040;
    localparam [NB_STATE - 1 : 0] S_READ_REG   = 16'h0080;
    localparam [NB_STATE - 1 : 0] S_READ_MEM   = 16'h0100;
    localparam [NB_STATE - 1 : 0] S_SEND_REGS  = 16'h0200;
    localparam [NB_STATE - 1 : 0] S_SEND_MEM   = 16'h0400;
    localparam [NB_STATE - 1 : 0] S_WRITE_REG  = 16'h0800;
    localparam [NB_STATE - 1 : 0] S_WRITE_MEM  = 16'h1000;
    localparam [NB_STATE - 1 : 0] S_RESPOND    = 16'h2000;
    localparam [NB_STATE - 1 : 0] S_WAIT_RESP  = 16'h4000;
    localparam NB_BYTE_CNT   = 3;
    localparam NB_FRAME_SIZE = 6;
    reg [NB_STATE - 1 : 0] state_reg, next_state;
    reg [NB_STATE - 1 : 0] prev_state_reg;
    reg [NB_UART_DATA - 1 : 0] frame_reg  [0 : 5];
    reg [NB_UART_DATA - 1 : 0] frame_next [0 : 5];
    reg [NB_BYTE_CNT - 1 : 0] byte_cnt_reg, byte_cnt_next;
    reg [NB_UART_DATA - 1 : 0] cmd_opcode_reg, cmd_opcode_next;
    reg [NB_DATA - 1 : 0]      cmd_payload_reg, cmd_payload_next;

    reg cpu_running_reg, cpu_running_next;
    reg cpu_halted_reg, cpu_halted_next;
    reg bkp_hit_reg, bkp_hit_next;
    reg [NB_STEP_CNT - 1 : 0] step_cnt_reg, step_cnt_next;
    reg [2 : 0] step_cycle_reg, step_cycle_next;
    reg [NB_DATA - 1 : 0]      resp_data_reg, resp_data_next;
    reg [NB_UART_DATA - 1 : 0] resp_status_reg, resp_status_next;
    reg [1 : 0] read_delay_reg, read_delay_next;
    wire [NB_UART_DATA - 1 : 0] computed_checksum;
    assign computed_checksum = frame_reg[0] ^ frame_reg[1] ^ frame_reg[2]
                             ^ frame_reg[3] ^ frame_reg[4];

    wire entering_load_fw  = (state_reg == S_LOAD_FW)   && (prev_state_reg != S_LOAD_FW);
    wire entering_send_regs= (state_reg == S_SEND_REGS) && (prev_state_reg != S_SEND_REGS);
    wire entering_send_mem = (state_reg == S_SEND_MEM)  && (prev_state_reg != S_SEND_MEM);
    wire entering_write_reg= (state_reg == S_WRITE_REG) && (prev_state_reg != S_WRITE_REG);
    wire entering_write_mem= (state_reg == S_WRITE_MEM) && (prev_state_reg != S_WRITE_MEM);

    integer i;

    always @(posedge clk) begin
        if (i_rst) begin
            state_reg       <= S_IDLE;
            prev_state_reg  <= S_IDLE;
            byte_cnt_reg    <= {NB_BYTE_CNT{1'b0}};
            cmd_opcode_reg  <= {NB_UART_DATA{1'b0}};
            cmd_payload_reg <= {NB_DATA{1'b0}};
            cpu_running_reg <= 1'b0;
            cpu_halted_reg  <= 1'b0;
            bkp_hit_reg     <= 1'b0;
            step_cnt_reg    <= {NB_STEP_CNT{1'b0}};
            step_cycle_reg  <= 3'b000;
            resp_data_reg   <= {NB_DATA{1'b0}};
            resp_status_reg <= STATUS_OK;
            read_delay_reg  <= 2'b00;
            for (i = 0; i < NB_FRAME_SIZE; i = i + 1) begin
                frame_reg[i] <= {NB_UART_DATA{1'b0}};
            end
        end
        else begin
            state_reg       <= next_state;
            prev_state_reg  <= state_reg;
            byte_cnt_reg    <= byte_cnt_next;
            cmd_opcode_reg  <= cmd_opcode_next;
            cmd_payload_reg <= cmd_payload_next;
            cpu_running_reg <= cpu_running_next;
            cpu_halted_reg  <= cpu_halted_next;
            bkp_hit_reg     <= bkp_hit_next;
            step_cnt_reg    <= step_cnt_next;
            step_cycle_reg  <= step_cycle_next;
            resp_data_reg   <= resp_data_next;
            resp_status_reg <= resp_status_next;
            read_delay_reg  <= read_delay_next;
            for (i = 0; i < NB_FRAME_SIZE; i = i + 1) begin
                frame_reg[i] <= frame_next[i];
            end
        end
    end

    // Next-State Logic
    always @(*) begin
        next_state = state_reg;

        case (state_reg)
            S_IDLE: begin
                if (i_rx_done) begin
                    next_state = S_RECV_CMD;
                end
            end

            S_RECV_CMD: begin
                if (i_rx_done && byte_cnt_reg == 3'd5) begin
                    next_state = S_VALIDATE;
                end
            end

            S_VALIDATE: begin
                next_state = S_DISPATCH;
            end

            S_DISPATCH: begin
                if (computed_checksum != frame_reg[5]) begin
                    // Checksum error — respond with error
                    next_state = S_RESPOND;
                end
                else begin
                    case (cmd_opcode_reg)
                        CMD_LOAD_FW:   next_state = S_LOAD_FW;
                        CMD_RUN:       next_state = S_RESPOND;
                        CMD_STEP:      next_state = S_STEPPING;
                        CMD_HALT:      next_state = S_RESPOND;
                        CMD_READ_REG: begin
                            if (cmd_payload_reg[7 : 0] == 8'hFF) begin
                                next_state = S_SEND_REGS;
                            end
                            else begin
                                next_state = S_READ_REG;
                            end
                        end
                        CMD_READ_MEM: begin
                            if (cmd_payload_reg == 32'hFFFFFFFF) begin
                                next_state = S_SEND_MEM;
                            end
                            else begin
                                next_state = S_READ_MEM;
                            end
                        end
                        CMD_WRITE_REG: next_state = S_WRITE_REG;
                        CMD_WRITE_MEM: next_state = S_WRITE_MEM;
                        CMD_SET_BKP:   next_state = S_RESPOND;
                        CMD_CLR_BKP:   next_state = S_RESPOND;
                        CMD_RESET:     next_state = S_RESPOND;
                        CMD_STATUS:    next_state = S_RESPOND;
                        default:       next_state = S_RESPOND;
                    endcase
                end
            end

            S_LOAD_FW: begin
                if (i_imem_loader_done) begin
                    next_state = S_RESPOND;
                end
            end

            S_EXECUTING: begin
                if (i_instruction == HALT_INST || i_bkp_hit) begin
                    next_state = S_RESPOND;
                end
                // Can be interrupted by CMD_HALT via host (checked at IDLE re-entry)
                if (i_rx_done) begin
                    next_state = S_RECV_CMD;
                end
            end

            S_STEPPING: begin
                if (step_cnt_reg == {{(NB_STEP_CNT-1){1'b0}}, 1'b1} && step_cycle_reg == 3'd5) begin
                    next_state = S_RESPOND;
                end
            end

            S_READ_REG: begin
                if (read_delay_reg == 2'd2) begin
                    next_state = S_RESPOND;
                end
            end

            S_READ_MEM: begin
                if (read_delay_reg == 2'd2) begin
                    next_state = S_RESPOND;
                end
            end

            S_SEND_REGS: begin
                if (i_regfile_tx_done) begin
                    next_state = S_RESPOND;
                end
            end

            S_SEND_MEM: begin
                if (i_dmem_tx_done) begin
                    next_state = S_RESPOND;
                end
            end

            S_WRITE_REG: begin
                if (i_regfile_rx_done) begin
                    next_state = S_RESPOND;
                end
            end

            S_WRITE_MEM: begin
                if (i_dmem_rx_done) begin
                    next_state = S_RESPOND;
                end
            end

            S_RESPOND: begin
                next_state = S_WAIT_RESP;
            end

            S_WAIT_RESP: begin
                if (cmd_opcode_reg == CMD_RUN) begin
                    next_state = S_EXECUTING;
                end
                else begin
                    next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Output & Data Path Logic
    always @(*) begin
        // Default outputs
        o_cpu_enable        = cpu_running_reg;
        o_cpu_reset         = 1'b0;
        o_imem_loader_start = entering_load_fw;
        o_regfile_tx_start  = entering_send_regs;
        o_dmem_tx_start     = entering_send_mem;
        o_regfile_rd        = 1'b0;
        o_regfile_raddr     = 5'b0;
        o_regfile_rx_start  = entering_write_reg;
        o_regfile_rx_addr   = 5'b0;
        o_dmem_rx_start     = entering_write_mem;
        o_dmem_rx_addr      = {NB_DATA{1'b0}};
        o_mem_rd            = 1'b0;
        o_mem_raddr         = {NB_ADDR{1'b0}};
        o_bkp_set           = 1'b0;
        o_bkp_clr           = 1'b0;
        o_bkp_addr          = {NB_DATA{1'b0}};
        o_resp_valid        = 1'b0;
        o_resp_status       = STATUS_OK;
        o_resp_data         = {NB_DATA{1'b0}};

        // Default register next values
        byte_cnt_next    = byte_cnt_reg;
        cmd_opcode_next  = cmd_opcode_reg;
        cmd_payload_next = cmd_payload_reg;
        cpu_running_next = cpu_running_reg;
        cpu_halted_next  = cpu_halted_reg;
        bkp_hit_next     = bkp_hit_reg;
        step_cnt_next    = step_cnt_reg;
        step_cycle_next  = step_cycle_reg;
        resp_data_next   = resp_data_reg;
        resp_status_next = resp_status_reg;
        read_delay_next  = read_delay_reg;

        for (i = 0; i < NB_FRAME_SIZE; i = i + 1) begin
            frame_next[i] = frame_reg[i];
        end

        case (state_reg)
            S_IDLE: begin
                byte_cnt_next   = {NB_BYTE_CNT{1'b0}};
                read_delay_next = 2'b00;
                if (i_rx_done) begin
                    frame_next[0] = i_rx_data;
                    byte_cnt_next = 3'd1;
                end
            end

            S_RECV_CMD: begin
                if (i_rx_done) begin
                    frame_next[byte_cnt_reg] = i_rx_data;
                    byte_cnt_next = byte_cnt_reg + 1'b1;
                end
            end

            S_VALIDATE: begin
                // Parse fields from frame buffer
                cmd_opcode_next  = frame_reg[0];
                cmd_payload_next = {frame_reg[4], frame_reg[3], frame_reg[2], frame_reg[1]};
            end

            S_DISPATCH: begin
                if (computed_checksum != frame_reg[5]) begin
                    // Checksum mismatch
                    resp_status_next = STATUS_ERROR;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
                else begin
                    case (cmd_opcode_reg)
                        CMD_LOAD_FW: begin
                            o_cpu_reset      = 1'b1;
                            cpu_running_next = 1'b0;
                            cpu_halted_next  = 1'b0;
                        end

                        CMD_RUN: begin
                            cpu_running_next = 1'b1;
                            cpu_halted_next  = 1'b0;
                            bkp_hit_next     = 1'b0;
                            resp_status_next = STATUS_OK;
                            resp_data_next   = {NB_DATA{1'b0}};
                        end

                        CMD_STEP: begin
                            step_cnt_next   = (cmd_payload_reg == {NB_DATA{1'b0}}) ? 32'd1 : cmd_payload_reg;
                            step_cycle_next = 2'd0;
                        end

                        CMD_HALT: begin
                            cpu_running_next = 1'b0;
                            cpu_halted_next  = 1'b1;
                            resp_status_next = STATUS_OK;
                            resp_data_next   = i_pc;
                        end

                        CMD_READ_REG: begin
                            // Payload[4:0] = register address, 0xFF = full dump
                        end

                        CMD_READ_MEM: begin
                            // Payload = address, 0xFFFFFFFF = full dump
                        end

                        CMD_WRITE_REG: begin
                            o_regfile_rx_addr = cmd_payload_reg[4 : 0];
                        end

                        CMD_WRITE_MEM: begin
                            o_dmem_rx_addr = cmd_payload_reg;
                        end

                        CMD_SET_BKP: begin
                            o_bkp_set        = 1'b1;
                            o_bkp_addr       = cmd_payload_reg;
                            resp_status_next = STATUS_OK;
                            resp_data_next   = {NB_DATA{1'b0}};
                        end

                        CMD_CLR_BKP: begin
                            o_bkp_clr        = 1'b1;
                            o_bkp_addr       = cmd_payload_reg;
                            resp_status_next = STATUS_OK;
                            resp_data_next   = {NB_DATA{1'b0}};
                        end

                        CMD_RESET: begin
                            o_cpu_reset      = 1'b1;
                            cpu_running_next = 1'b0;
                            cpu_halted_next  = 1'b0;
                            bkp_hit_next     = 1'b0;
                            resp_status_next = STATUS_OK;
                            resp_data_next   = {NB_DATA{1'b0}};
                        end

                        CMD_STATUS: begin
                            resp_status_next = STATUS_OK;
                            resp_data_next   = {29'b0, bkp_hit_reg, cpu_halted_reg, cpu_running_reg};
                        end

                        default: begin
                            resp_status_next = STATUS_ERROR;
                            resp_data_next   = {NB_DATA{1'b0}};
                        end
                    endcase
                end
            end

            S_LOAD_FW: begin
                o_cpu_enable = 1'b0;
                if (i_imem_loader_done) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
            end

            S_EXECUTING: begin
                o_cpu_enable = 1'b1;
                if (i_instruction == HALT_INST) begin
                    cpu_running_next = 1'b0;
                    cpu_halted_next  = 1'b1;
                    resp_status_next = STATUS_OK;
                    resp_data_next   = i_pc;
                end
                else if (i_bkp_hit) begin
                    cpu_running_next = 1'b0;
                    cpu_halted_next  = 1'b1;
                    bkp_hit_next     = 1'b1;
                    resp_status_next = STATUS_OK;
                    resp_data_next   = i_pc;
                end
                // If host sends a byte while executing, interrupt and parse new command
                if (i_rx_done) begin
                    cpu_running_next = 1'b0;
                    frame_next[0]    = i_rx_data;
                    byte_cnt_next    = 3'd1;
                end
            end

            S_STEPPING: begin
                // Enable CPU for 1 cycle, wait 3 cycles (pipeline settle)
                if (step_cycle_reg == 3'd0) begin
                    o_cpu_enable = 1'b1;
                end
                else begin
                    o_cpu_enable = 1'b0;
                end

                step_cycle_next = step_cycle_reg + 1'b1;

                if (step_cycle_reg == 3'd5) begin
                    step_cnt_next   = step_cnt_reg - 1'b1;
                    step_cycle_next = 3'd0;

                    if (step_cnt_reg == {{(NB_STEP_CNT-1){1'b0}}, 1'b1}) begin
                        // Last step completed
                        cpu_running_next = 1'b0;
                        resp_status_next = STATUS_OK;
                        resp_data_next   = i_pc;
                    end
                end
            end

            S_READ_REG: begin
                o_cpu_enable    = 1'b0;
                o_regfile_rd    = 1'b1;
                o_regfile_raddr = cmd_payload_reg[4 : 0];
                read_delay_next = read_delay_reg + 1'b1;

                if (read_delay_reg == 2'd2) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = i_regfile_data;
                end
            end

            S_READ_MEM: begin
                o_cpu_enable = 1'b0;
                o_mem_rd     = 1'b1;
                o_mem_raddr  = cmd_payload_reg[NB_ADDR - 1 : 0];
                read_delay_next = read_delay_reg + 1'b1;

                if (read_delay_reg == 2'd2) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = i_mem_data;
                end
            end

            S_SEND_REGS: begin
                o_cpu_enable = 1'b0;
                if (i_regfile_tx_done) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
            end

            S_SEND_MEM: begin
                o_cpu_enable = 1'b0;
                if (i_dmem_tx_done) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
            end

            S_WRITE_REG: begin
                o_cpu_enable      = 1'b0;
                o_regfile_rx_addr = cmd_payload_reg[4 : 0];
                if (i_regfile_rx_done) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
            end

            S_WRITE_MEM: begin
                o_cpu_enable  = 1'b0;
                o_dmem_rx_addr = cmd_payload_reg;
                if (i_dmem_rx_done) begin
                    resp_status_next = STATUS_OK;
                    resp_data_next   = {NB_DATA{1'b0}};
                end
            end

            S_RESPOND: begin
                o_resp_valid  = 1'b1;
                o_resp_status = resp_status_reg;
                o_resp_data   = resp_data_reg;

                // For CMD_RUN, transition to S_EXECUTING happens after response
                if (cmd_opcode_reg == CMD_RUN) begin
                    cpu_running_next = 1'b1;
                end
            end

            S_WAIT_RESP: begin
                // After response sent, return to IDLE or EXECUTING
                if (cmd_opcode_reg == CMD_RUN) begin
                    o_cpu_enable = 1'b1;
                end
            end

            default: begin
                // noop
            end
        endcase
    end

endmodule
