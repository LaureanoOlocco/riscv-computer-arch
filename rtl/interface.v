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
    output wire [NB_DATA                                               - 1 : 0] o_alu_out                       , 
    output wire [NB_REG                                                - 1 : 0] o_alu_data_a                    , 
    output wire [NB_REG                                                - 1 : 0] o_alu_data_b                    , 
    output wire [NB_OP_CODE                                            - 1 : 0] o_alu_op_code                   , 
    input  wire [NB_REG                                                - 1 : 0] i_alu_out                       , 
    input  wire [NB_DATA                                               - 1 : 0] i_rx_data                       , 
    input  wire                                                                 i_rx_done                       , 
    input  wire                                                                 i_rx_empty                      , 
    input  wire                                                                 i_tx_done                       , 
    input  wire                                                                 i_rst                           , 
    input  wire                                                                 clock          
)                                                                                                               ;
    localparam                                                                  NB_STATE        = 3             ;
    localparam                                                                  START_CHAR      = 8'hFB         ;
    localparam                                                                  END_CHAR        = 8'hFD         ;
    localparam                                                                  ERROR_CHAR      = 32'hFEFEFEFE  ;

    localparam                                                                  NB_CNT          = NB_REG/NB_DATA;

    localparam [NB_STATE                                               - 1 : 0] STATE_IDLE      = 3'b000        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_A    = 3'b001        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_B    = 3'b010        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_DATA_OP   = 3'b011        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_END_RX    = 3'b100        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_FIFO_OUT  = 3'b101        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_SEND      = 3'b110        ;
    localparam [NB_STATE                                               - 1 : 0] STATE_ERROR     = 3'b111        ;

    reg        [NB_STATE                                               - 1 : 0] state_reg                       ;
    reg        [NB_STATE                                               - 1 : 0] state_next                      ;
                             
    reg        [NB_REG                                                 - 1 : 0] alu_data_a                      ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_a_next                 ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_b                      ;
    reg        [NB_REG                                                 - 1 : 0] alu_data_b_next                 ;
    reg        [NB_OP_CODE                                             - 1 : 0] alu_op_code                     ;
    reg        [NB_OP_CODE                                             - 1 : 0] alu_op_code_next                ;
    reg        [NB_REG                                                 - 1 : 0] alu_out                         ;
    reg        [NB_REG                                                 - 1 : 0] alu_out_next                    ;
                         
    reg        [NB_COUNT                                               - 1 : 0] data_count                      ;
    reg        [NB_COUNT                                               - 1 : 0] data_count_next                 ;
                          
    reg                                                                         rx_done_reg                     ;
    reg                                                                         tx_done_reg                     ;
    
    reg                                                                         tx_start_out                    ;
    reg                                                                         read_out                        ;
    reg                                                                         wr_out                          ;
    reg         [NB_DATA                                               - 1 : 0] alu_output                      ;

    always @(*) 
    begin
        tx_start_out                    = 1'b0                                                                  ;
        read_out                        = 1'b0                                                                  ;
        wr_out                          = 1'b0                                                                  ;
        alu_output                      = {NB_DATA{1'b0}}                                                       ;
        alu_data_a_next                 = alu_data_a                                                            ;   
        alu_data_b_next                 = alu_data_b                                                            ; 
        alu_op_code_next                = alu_op_code                                                           ;
        alu_out_next                    = alu_out                                                               ;
        data_count_next                 = data_count                                                            ;
        state_next                      = state_reg                                                             ;
        case (state_reg)
            STATE_IDLE                                                                                          : 
            begin
                if (rx_done_reg) 
                begin
                    tx_start_out        = 1'b0                                                                  ;
                    read_out            = 1'b1                                                                  ;
                    wr_out              = 1'b0                                                                  ;
                    alu_output          = {NB_DATA{1'b0}}                                                       ;
                    alu_data_a_next     = alu_data_a                                                            ;   
                    alu_data_b_next     = alu_data_b                                                            ; 
                    alu_op_code_next    = alu_op_code                                                           ;
                    alu_out_next        = alu_out                                                               ;
                    data_count_next     = data_count                                                            ;
                    if (i_rx_data == START_CHAR)
                    begin
                        state_next      = STATE_DATA_A                                                          ;
                    end
                    else
                    begin
                        state_next      = state_reg                                                            ;
                    end
                end
                else
                begin
                    tx_start_out        = 1'b0                                                                  ;
                    read_out            = 1'b0                                                                  ;
                    wr_out              = 1'b0                                                                  ;
                    alu_output          = {NB_DATA{1'b0}}                                                       ;
                    alu_data_a_next     = alu_data_a                                                            ;   
                    alu_data_b_next     = alu_data_b                                                            ; 
                    alu_op_code_next    = alu_op_code                                                           ;
                    alu_out_next        = alu_out                                                               ;
                    data_count_next     = data_count                                                            ;
                    state_next          = state_reg                                                             ;
                end
            end
            STATE_DATA_A                                                                                        : 
            begin
                tx_start_out            = 1'b0                                                                  ;
                wr_out                  = 1'b0                                                                  ;
                alu_output              = {NB_DATA{1'b0}}                                                       ;
                alu_data_b_next         = alu_data_b                                                            ; 
                alu_op_code_next        = alu_op_code                                                           ;
                alu_out_next            = alu_out                                                               ;  
                if (data_count == NB_CNT) 
                begin       
                    read_out            = 1'b0                                                                  ;
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    alu_data_a_next     = alu_data_a                                                            ;
                    state_next          = STATE_DATA_B                                                          ;
                end
                else if (rx_done_reg) 
                begin
                    read_out            = 1'b1                                                                  ;
                    data_count_next     = data_count + {{NB_COUNT - 1 {1'b0}}, 1'b1}                            ;
                    alu_data_a_next     = {i_rx_data, alu_data_a[NB_REG - 1 : NB_DATA]}                         ;
                    state_next          = state_reg                                                             ;
                end 
                else    
                begin   
                    read_out            = 1'b0                                                                  ;
                    data_count_next     = data_count                                                            ;
                    alu_data_a_next     = alu_data_a                                                            ;
                    state_next          = state_reg                                                             ;
                end
            end
            STATE_DATA_B                                                                                        : 
            begin
                tx_start_out            = 1'b0                                                                  ;
                wr_out                  = 1'b0                                                                  ;
                alu_output              = {NB_DATA{1'b0}}                                                       ;
                alu_data_a_next         = alu_data_a                                                            ; 
                alu_op_code_next        = alu_op_code                                                           ;
                alu_out_next            = alu_out                                                               ;    
                if (data_count == NB_CNT) 
                begin       
                    read_out            = 1'b0                                                                  ;
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    alu_data_b_next     = alu_data_b                                                            ;
                    state_next          = STATE_DATA_OP                                                         ;
                end
                else if (rx_done_reg) 
                begin
                    read_out            = 1'b1                                                                  ;
                    data_count_next     = data_count + {{NB_COUNT - 1 {1'b0}}, 1'b1}                            ;
                    alu_data_b_next     = {i_rx_data, alu_data_b[NB_REG - 1 : NB_DATA]}                         ;
                    state_next          = state_reg                                                             ;
                end 
                else    
                begin   
                    read_out            = 1'b0                                                                  ;
                    data_count_next     = data_count                                                            ;
                    alu_data_b_next     = alu_data_b                                                            ;
                    state_next          = state_reg                                                             ;
                end
            end
            STATE_DATA_OP                                                                                       :   
            begin
                tx_start_out            = 1'b0                                                                  ;
                wr_out                  = 1'b0                                                                  ;
                alu_output              = {NB_DATA{1'b0}}                                                       ;
                alu_data_a_next         = alu_data_a                                                            ; 
                alu_data_b_next         = alu_data_b                                                            ; 
                alu_out_next            = alu_out                                                               ;    
                if (rx_done_reg) 
                begin
                    read_out            = 1'b1                                                                  ;
                    data_count_next     = data_count + {{NB_COUNT - 1 {1'b0}}, 1'b1}                            ;
                    alu_op_code_next    = {i_rx_data[NB_OP_CODE - 1 : 0]}                                       ;
                    state_next          = STATE_END_RX                                                          ;
                end 
                else    
                begin   
                    read_out            = 1'b0                                                                  ;
                    data_count_next     = data_count                                                            ;
                    alu_op_code_next    = alu_op_code                                                           ;
                    state_next          = state_reg                                                             ;
                end
            end
            STATE_END_RX                                                                                        : 
            begin
                tx_start_out            = 1'b0                                                                  ;
                wr_out                  = 1'b0                                                                  ;
                alu_output              = {NB_DATA{1'b0}}                                                       ;
                alu_data_a_next         = alu_data_a                                                            ; 
                alu_data_b_next         = alu_data_b                                                            ; 
                alu_op_code_next        = alu_op_code                                                           ;
                if (rx_done_reg) 
                begin
                    read_out            = 1'b1                                                                  ;
                    if (i_rx_data == END_CHAR) 
                    begin
                        read_out        = 1'b0                                                                  ;
                        alu_out_next    = i_alu_out                                                             ; 
                        state_next      = STATE_FIFO_OUT                                                        ;
                    end
                    else
                    begin
                        read_out        = 1'b0                                                                  ;
                        alu_out_next    = alu_out                                                               ; 
                        state_next      = STATE_ERROR                                                           ;
                    end
                end
                else
                begin
                    read_out            = 1'b1                                                                  ;
                    alu_out_next        = alu_out                                                               ; 
                    state_next          = state_reg                                                             ;
                end
            end
            STATE_FIFO_OUT                                                                                      : 
            begin
                tx_start_out            = 1'b0                                                                  ;
                read_out                = 1'b0                                                                  ;
                alu_data_a_next         = alu_data_a                                                            ;   
                alu_data_b_next         = alu_data_b                                                            ; 
                alu_op_code_next        = alu_op_code                                                           ;
                alu_out_next            = alu_out                                                               ;
                if (data_count == NB_CNT) 
                begin
                    wr_out              = 1'b0                                                                  ;
                    alu_output          = {NB_DATA{1'b0}}                                                       ;
                    data_count_next     = {NB_COUNT{1'b0}}                                                      ;
                    state_next          = STATE_SEND                                                            ;
                end
                else 
                begin
                    wr_out              = 1'b1                                                                  ;
                    alu_output          = alu_out[(data_count * NB_DATA) +: NB_DATA]                            ;
                    data_count_next     = data_count + {{NB_COUNT - 1 {1'b0}}, 1'b1}                            ;
                    state_next          = state_reg                                                             ;
                end
            end
           STATE_SEND:
begin
    wr_out          = 1'b0;
    alu_output      = {NB_DATA{1'b0}};
    alu_data_a_next = alu_data_a;
    alu_data_b_next = alu_data_b;
    alu_op_code_next= alu_op_code;
    
    if (data_count == NB_CNT) 
    begin
        tx_start_out    = 1'b0;
        data_count_next = {NB_COUNT{1'b0}};
        state_next      = STATE_IDLE;
    end
    else if (tx_done_reg)  // Esperar tx_done entre bytes
    begin
        tx_start_out    = 1'b1;  // Pulso para siguiente byte
        data_count_next = data_count + 1;
        state_next      = state_reg;
    end
    else if (data_count == {NB_COUNT{1'b0}})  // Primera vez (count=0)
    begin
        tx_start_out    = 1'b1;  // Pulso para primer byte
        data_count_next = data_count + 1;
        state_next      = state_reg;
    end
    else  // Esperando tx_done
    begin
        tx_start_out    = 1'b0;
        data_count_next = data_count;
        state_next      = state_reg;
    end
end
            STATE_ERROR                                                                                         : 
            begin
                tx_start_out            = 1'b0                                                                  ;
                wr_out                  = 1'b0                                                                  ;
                alu_data_a_next         = {NB_REG{1'b0}}                                                        ;
                alu_data_b_next         = {NB_REG{1'b0}}                                                        ;
                alu_op_code_next        = {NB_OP_CODE{1'b0}}                                                    ;
                data_count_next         = {NB_COUNT{1'b0}}                                                      ;
                alu_output              = {NB_DATA{1'b0}}                                                       ;
                if (~i_rx_empty)
                begin
                    read_out            = 1'b1                                                                  ;
                    alu_out_next        = alu_out                                                               ;
                    state_next          = state_reg                                                             ;
                end
                else 
                begin
                    read_out            = 1'b0                                                                  ;
                    alu_out_next        = ERROR_CHAR                                                            ;
                    state_next          = STATE_FIFO_OUT                                                        ;
                end
            end
        endcase
    end

    always @(posedge clock or posedge i_rst) 
    begin
        if (i_rst) 
        begin
            state_reg                   <= STATE_IDLE                                                           ;
            alu_data_a                  <= {NB_REG{1'b0}}                                                       ;
            alu_data_b                  <= {NB_REG{1'b0}}                                                       ;
            alu_op_code                 <= {NB_OP_CODE{1'b0}}                                                   ;
            alu_out                     <= {NB_REG{1'b0}}                                                       ;
            data_count                  <= {NB_COUNT{1'b0}}                                                     ;
        end         
        else            
        begin           
            state_reg                   <= state_next                                                           ;
            alu_data_a                  <= alu_data_a_next                                                      ;
            alu_data_b                  <= alu_data_b_next                                                      ;
            alu_op_code                 <= alu_op_code_next                                                     ;
            alu_out                     <= alu_out_next                                                         ;
            data_count                  <= data_count_next                                                      ;
        end
    end


    always @(posedge clock or posedge i_rst) 
    begin
        if (i_rst) 
        begin
            rx_done_reg                 <= 1'b0                                                                 ;
            tx_done_reg                 <= 1'b0                                                                 ;
        end         
        else            
        begin           
            if (&i_rx_done)         
            begin           
                rx_done_reg             <= 1'b1                                                                 ;
            end         
            else            
            begin           
                rx_done_reg             <= 1'b0                                                                 ;
            end         
            if (&i_tx_done)         
            begin           
                tx_done_reg             <= 1'b1                                                                 ;
            end         
            else            
            begin           
                tx_done_reg             <= 1'b0                                                                 ;
            end
        end
    end

    assign o_tx_start       = tx_start_out                                                                      ;    
    assign o_read           = read_out                                                                          ;    
    assign o_write             = wr_out                                                                            ;    
    assign o_alu_out        = alu_output                                                                        ;
    assign o_alu_data_a     = alu_data_a                                                                        ;
    assign o_alu_data_b     = alu_data_b                                                                        ;
    assign o_alu_op_code    = alu_op_code                                                                       ;

endmodule