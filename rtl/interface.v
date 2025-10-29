module interface_uart
#(
    parameter                                                                   NB_DATA    = 8                  ,
    parameter                                                                   NB_REG     = 32                 ,
    parameter                                                                   NB_OP_CODE = 6                  ,
    parameter                                                                   NB_COUNT   = 3
)
(
    output wire                                                                 o_tx_start                      ,
    output wire                                                                 o_read                          ,
    output wire                                                                 o_write                         ,
    output wire                                                                 o_fifo_tx_rd                    ,
    output wire [NB_DATA                                               - 1 : 0] o_alu_out                       ,
    output wire [NB_REG                                                - 1 : 0] o_alu_data_a                    ,
    output wire [NB_REG                                                - 1 : 0] o_alu_data_b                    ,
    output wire [NB_OP_CODE                                            - 1 : 0] o_alu_op_code                   ,
    input  wire [NB_REG                                                - 1 : 0] i_alu_out                       ,
    input  wire [NB_DATA                                               - 1 : 0] i_rx_data                       ,
    input  wire                                                                 i_rx_done                       ,
    input  wire                                                                 i_rx_empty                      ,
    input  wire                                                                 i_fifo_tx_empty                 ,
    input  wire                                                                 i_tx_done                       ,
    input  wire                                                                 i_rst                           ,
    input  wire                                                                 clock
)                                                                                                               ;

    localparam                                                                  NB_STATE        = 4             ;
    localparam                                                                  START_CHAR      = 8'hFB         ;
    localparam                                                                  END_CHAR        = 8'hFD         ;
    localparam                                                                  ERROR_CHAR      = 32'hFEFEFEFE  ;
    localparam                                                                  NB_CNT          = NB_REG/NB_DATA;

    localparam [NB_STATE                                               - 1 : 0] STATE_IDLE       = 0            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_A     = 1            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_B     = 2            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_OP    = 3            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_END_RX     = 4            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_FLUSH_FIFO = 5            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_FIFO_OUT   = 6            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_SEND       = 7            ;
    localparam [NB_STATE                                               - 1 : 0] STATE_ERROR      = 8            ;

    reg        [NB_STATE                                               - 1 : 0] state_reg                       ;
    reg        [NB_STATE                                               - 1 : 0] state_next                      ;

    reg        [NB_REG                                                 - 1 : 0] alu_data_a_reg                  ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_a_next                 ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_b_reg                  ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_b_next                 ;
    reg        [NB_OP_CODE                                             - 1 : 0] alu_op_code_reg                 ;
    reg        [NB_OP_CODE                                             - 1 : 0] alu_op_code_next                ;
    reg        [NB_REG                                                 - 1 : 0] alu_out_reg                     ;
    reg        [NB_REG                                                 - 1 : 0] alu_out_next                    ;

    reg        [NB_COUNT                                               - 1 : 0] data_count_reg                  ;
    reg        [NB_COUNT                                               - 1 : 0] data_count_next                 ;

    reg                                                                         rx_done_reg                     ;
    reg                                                                         tx_done_reg                     ;

    reg                                                                         tx_start_reg                    ;
    reg                                                                         read_reg                        ;
    reg                                                                         write_reg                       ;
    reg                                                                         fifo_tx_rd_reg                  ;
    reg        [NB_DATA                                                - 1 : 0] alu_out_data_reg                ;

    always @(*)
    begin
        tx_start_reg            = 1'b0                                                                          ;
        read_reg                = 1'b0                                                                          ;
        write_reg               = 1'b0                                                                          ;
        fifo_tx_rd_reg          = 1'b0                                                                          ;
        alu_out_data_reg        = {NB_DATA{1'b0}}                                                               ;

        alu_data_a_next         = alu_data_a_reg                                                                ;
        alu_data_b_next         = alu_data_b_reg                                                                ;
        alu_op_code_next        = alu_op_code_reg                                                               ;
        alu_out_next            = alu_out_reg                                                                   ;
        data_count_next         = data_count_reg                                                                ;
        state_next              = state_reg                                                                     ;

        case (state_reg)
            STATE_IDLE:
            begin
                if (rx_done_reg)
                begin
                    read_reg            = 1'b1                                                                  ;
                    if (i_rx_data == START_CHAR)
                        state_next      = STATE_DATA_A                                                          ;
                end
            end

            STATE_DATA_A:
            begin
                if (rx_done_reg)
                begin
                    read_reg            = 1'b1                                                                  ;
                    alu_data_a_next     = {i_rx_data, alu_data_a_reg[NB_REG - 1 : NB_DATA]}                     ;

                    if (data_count_reg == NB_CNT - 1'b1)
                    begin
                        data_count_next = {NB_COUNT{1'b0}}                                                      ;
                        state_next      = STATE_DATA_B                                                          ;
                    end
                    else
                    begin
                        data_count_next = data_count_reg + 1'b1                                                 ;
                    end
                end
            end

            STATE_DATA_B:
            begin
                if (rx_done_reg)
                begin
                    read_reg            = 1'b1                                                                  ;
                    alu_data_b_next     = {i_rx_data, alu_data_b_reg[NB_REG - 1 : NB_DATA]}                    ;

                    if (data_count_reg == NB_CNT - 1'b1)
                    begin
                        data_count_next = {NB_COUNT{1'b0}}                                                      ;
                        state_next      = STATE_DATA_OP                                                         ;
                    end
                    else
                    begin
                        data_count_next = data_count_reg + 1'b1                                                 ;
                    end
                end
            end

            STATE_DATA_OP:
            begin
                if (rx_done_reg)
                begin
                    read_reg            = 1'b1                                                                  ;
                    alu_op_code_next    = i_rx_data[NB_OP_CODE - 1 : 0]                                        ;
                    state_next          = STATE_END_RX                                                          ;
                end
            end

            STATE_END_RX:
            begin
                if (rx_done_reg)
                begin
                    read_reg            = 1'b1                                                                  ;
                    if (i_rx_data == END_CHAR)
                    begin
                        alu_out_next    = i_alu_out                                                             ;
                        data_count_next = {NB_COUNT{1'b0}}                                                      ;
                        state_next      = STATE_FLUSH_FIFO                                                      ;
                    end
                    else
                    begin
                        state_next      = STATE_ERROR                                                           ;
                    end
                end
            end

            STATE_FLUSH_FIFO:
            begin
                if (i_fifo_tx_empty)
                begin
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    state_next          = STATE_FIFO_OUT                                                        ;
                end
                else
                begin
                    fifo_tx_rd_reg      = 1'b1                                                                  ;
                end
            end

            STATE_FIFO_OUT:
            begin
                if (data_count_reg == NB_CNT)
                begin
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    state_next          = STATE_SEND                                                            ;
                end
                else
                begin
                    write_reg           = 1'b1                                                                  ;
                    alu_out_data_reg    = alu_out_reg[(data_count_reg * NB_DATA) +: NB_DATA]                    ;
                    data_count_next     = data_count_reg + 1'b1                                                 ;
                end
            end

            STATE_SEND:
            begin
                if (data_count_reg == NB_CNT)
                begin
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    state_next          = STATE_IDLE                                                            ;
                end
                else if (data_count_reg == {NB_COUNT{1'b0}})
                begin
                    fifo_tx_rd_reg      = 1'b1                                                                  ;
                    tx_start_reg        = 1'b1                                                                  ;
                    data_count_next     = data_count_reg + 1'b1                                                 ;
                end
                else if (tx_done_reg)
                begin
                    fifo_tx_rd_reg      = 1'b1                                                                  ;
                    tx_start_reg        = 1'b1                                                                  ;
                    data_count_next     = data_count_reg + 1'b1                                                 ;
                end
            end

            STATE_ERROR:
            begin
                if (~i_rx_empty)
                begin
                    read_reg            = 1'b1                                                                  ;
                end
                else
                begin
                    alu_out_next        = ERROR_CHAR                                                            ;
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    state_next          = STATE_FLUSH_FIFO                                                      ;
                end
            end

            default:
            begin
                state_next              = STATE_IDLE                                                            ;
            end

        endcase
    end

    always @(posedge clock or posedge i_rst)
    begin
        if (i_rst)
        begin
            state_reg               <= STATE_IDLE                                                               ;
            alu_data_a_reg          <= {NB_REG{1'b0}}                                                           ;
            alu_data_b_reg          <= {NB_REG{1'b0}}                                                           ;
            alu_op_code_reg         <= {NB_OP_CODE{1'b0}}                                                       ;
            alu_out_reg             <= {NB_REG{1'b0}}                                                           ;
            data_count_reg          <= {NB_COUNT{1'b0}}                                                         ;
        end
        else
        begin
            state_reg               <= state_next                                                               ;
            alu_data_a_reg          <= alu_data_a_next                                                          ;
            alu_data_b_reg          <= alu_data_b_next                                                          ;
            alu_op_code_reg         <= alu_op_code_next                                                         ;
            alu_out_reg             <= alu_out_next                                                             ;
            data_count_reg          <= data_count_next                                                          ;
        end
    end

    always @(posedge clock or posedge i_rst)
    begin
        if (i_rst)
        begin
            rx_done_reg             <= 1'b0                                                                     ;
            tx_done_reg             <= 1'b0                                                                     ;
        end
        else
        begin
            rx_done_reg             <= i_rx_done                                                                ;
            tx_done_reg             <= i_tx_done                                                                ;
        end
    end

    assign o_tx_start               = tx_start_reg                                                              ;
    assign o_read                   = read_reg                                                                  ;
    assign o_write                  = write_reg                                                                 ;
    assign o_fifo_tx_rd             = fifo_tx_rd_reg                                                            ;
    assign o_alu_out                = alu_out_data_reg                                                          ;
    assign o_alu_data_a             = alu_data_a_reg                                                            ;
    assign o_alu_data_b             = alu_data_b_reg                                                            ;
    assign o_alu_op_code            = alu_op_code_reg                                                           ;

endmodule