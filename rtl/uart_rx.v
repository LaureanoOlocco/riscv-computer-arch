module uart_rx
#(
    parameter                                                                   NB_DATA    = 8                  ,
                                                                                SM_TICK    = 16
)
(
    output wire [NB_DATA                                               - 1 : 0] o_data                          , 
    output wire                                                                 o_rx_done_tick                  , 
    input  wire                                                                 i_rx                            , 
    input  wire                                                                 i_s_tick                        , 
    input  wire                                                                 i_rst                           ,
    input  wire                                                                 clock
);

    localparam                                                                  NB_STATE   = 2                  ;
    localparam                                                                  NB_SAMPLE  = $clog2(SM_TICK)    ;
    localparam                                                                  NB_BIT_CNT = $clog2(NB_DATA)    ;
    localparam  [NB_STATE                                              - 1 : 0]
                                                                                STATE_IDLE = 2'b00              ,
                                                                                STATE_START= 2'b01              ,
                                                                                STATE_DATA = 2'b10              ,
                                                                                STATE_STOP = 2'b11              ;
        
     reg        [NB_STATE                                              - 1 : 0] state_reg, state_next           ;
     reg        [NB_SAMPLE                                             - 1 : 0] sample_reg, sample_next         ;
     reg        [NB_BIT_CNT                                            - 1 : 0] bit_index_reg, bit_index_next   ; 
     reg        [NB_DATA                                               - 1 : 0] bits_reg, bits_next             ; 
     reg                                                                        rx_done_tick                    ;
     
    
            
            
     always @(*)
     begin
         rx_done_tick    = 1'b0                                                                                  ;
         sample_next     = sample_reg                                                                            ;
         bit_index_next  = bit_index_reg                                                                         ;
         bits_next       = bits_reg                                                                              ;
         state_next      = state_reg                                                                             ;
        case (state_reg)
         STATE_IDLE                                                                                             :
         begin
            if(~i_rx)
            begin
                rx_done_tick    = 1'b0                                                                          ;
                sample_next     = {NB_SAMPLE{1'b0}}                                                             ;
                bit_index_next  = bit_index_reg                                                                 ;
                bits_next       = bits_reg                                                                      ;
                state_next      = STATE_START                                                                   ;
            end
        end
        STATE_START                                                                                             :
        begin
            if(i_s_tick)
            begin
                if(sample_reg == (SM_TICK / 2 - 1))
                begin
                    rx_done_tick    = 1'b0                                                                      ;                                                          
                    sample_next     = {NB_SAMPLE{1'b0}}                                                         ;
                    bit_index_next  = {NB_BIT_CNT{1'b0}}                                                        ;
                    bits_next       = bits_reg                                                                  ;
                    state_next      = STATE_DATA                                                                ;
                end
                else
                begin
                    rx_done_tick    = 1'b0                                                                      ;                                                          
                    sample_next     = sample_reg + {{NB_SAMPLE - 1 {1'b0}}, 1'b1}                               ;
                    bit_index_next  = bit_index_reg                                                             ;
                    bits_next       = bits_reg                                                                  ;
                    state_next      = state_reg                                                                 ;
                end
            end
            else
            begin
                rx_done_tick    = 1'b0                                                                      ;
                sample_next     = sample_reg                                                                ;
                bit_index_next  = bit_index_reg                                                             ;
                bits_next       = bits_reg                                                                  ;
                state_next      = state_reg                                                                 ;
            end
        end
        STATE_DATA                                                                                              :
        begin
            if(i_s_tick)
            begin
                if(&sample_reg)
                begin
                    rx_done_tick    = 1'b0                                                                      ;
                    sample_next     = {NB_SAMPLE{1'b0}}                                                         ;
                    bits_next       = {i_rx, bits_reg[NB_DATA - 1 : 1]}                                         ;
                    if(&bit_index_reg)
                    begin
                        bit_index_next = bit_index_reg                                                          ;   
                        state_next     = STATE_STOP                                                             ;
                    end
                    else 
                    begin
                        bit_index_next = bit_index_reg + {{NB_BIT_CNT - 1 {1'b0}}, 1'b1}                        ;   
                        state_next     = state_reg                                                              ;
                    end
                end
                else
                begin
                    rx_done_tick    = 1'b0                                                                      ;
                    sample_next     = sample_reg + {{NB_SAMPLE - 1 {1'b0}}, 1'b1}                               ;
                    bit_index_next  = bit_index_reg                                                             ;
                    bits_next       = bits_reg                                                                  ;
                    state_next      = state_reg                                                                 ;
                end
            end
        end
        STATE_STOP                                                                                              :
        begin
            if(i_s_tick)
            begin
                if(&sample_reg)
                begin
                    sample_next     = sample_reg                                                                ;
                    bit_index_next  = bit_index_reg                                                             ;
                    bits_next       = bits_reg                                                                  ;
                    state_next      = STATE_IDLE                                                                ;
                    if(i_rx)
                    begin
                        rx_done_tick= 1'b1                                                                      ;
                    end
                    else
                    begin
                        rx_done_tick= 1'b0                                                                      ;  
                    end
                end
                else
                begin
                    rx_done_tick    = 1'b0                                                                      ;
                    sample_next     = sample_reg + {{NB_SAMPLE - 1 {1'b0}}, 1'b1}                               ;
                    bit_index_next  = bit_index_reg                                                             ;
                    bits_next       = bits_reg                                                                  ;
                    state_next      = state_reg                                                                 ;
                end
            end
        end
        endcase                   
     end

     always @(posedge clock or posedge i_rst)
     begin
        if(i_rst)
        begin
            state_reg       <= STATE_IDLE                                                                       ;
            sample_reg      <= {NB_SAMPLE{1'b0}}                                                                ;
            bit_index_reg   <= {NB_BIT_CNT{1'b0}}                                                               ;
            bits_reg        <= {NB_DATA{1'b0}}                                                                  ;
        end
        else
        begin
            state_reg       <= state_next                                                                       ;
            sample_reg      <= sample_next                                                                      ;
            bit_index_reg   <= bit_index_next                                                                   ;
            bits_reg        <= bits_next                                                                        ;
           
        end
     end
       
     // salida
     assign o_data          = bits_reg                                                                          ;  
     assign o_rx_done_tick  = rx_done_tick                                                                      ;
     
     

endmodule