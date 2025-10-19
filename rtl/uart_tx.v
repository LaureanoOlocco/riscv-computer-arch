module uart_tx
#(
	parameter																		NB_DATA    = 8                  		,
																				    	SM_TICK    = 16
)
(
	output  wire																o_tx                                ,
	output  wire																o_tx_done_tick                      ,
	input   wire [NB_DATA              - 1 : 0] i_data                              ,
	input   wire																i_tx_start                          ,
	input   wire																i_s_tick                            ,
	input   wire																i_rst                               ,
	input   wire																clock
);

	localparam																	NB_STATE   = 2                      ;
	localparam																	NB_SAMPLE  = $clog2(SM_TICK)        ;
	localparam																	NB_BIT_CNT = $clog2(NB_DATA)        ;
	localparam  [NB_STATE                                              - 1 : 0]
																				STATE_IDLE  = 2'b00                 ,
																				STATE_START = 2'b01                 ,
																				STATE_DATA  = 2'b10                 ,
																				STATE_STOP  = 2'b11                 ;

	reg        [NB_STATE                                              - 1 : 0] state_reg, state_next                ;
	reg        [NB_SAMPLE                                             - 1 : 0] sample_reg, sample_next              ;
	reg        [NB_BIT_CNT                                            - 1 : 0] bit_index_reg, bit_index_next        ;
	reg        [NB_DATA                                               - 1 : 0] shifter_reg, shifter_next            ;
	reg                                                                        tx_reg, tx_next                      ;
	reg                                                                        tx_done_tick                         ;


	always @(*) 
    begin
		tx_done_tick                = 1'b0                                                                          ;
		tx_next                     = tx_reg                                                                        ;
		sample_next                 = sample_reg                                                                    ;
		bit_index_next              = bit_index_reg                                                                 ;
		shifter_next                = shifter_reg                                                                   ;
		state_next                  = state_reg                                                                     ;

		case (state_reg)
		STATE_IDLE                                                                                                  :     
        begin
		    tx_done_tick            = 1'b0                                                                          ;
			tx_next                 = 1'b1                                                                          ;
			if (i_tx_start) 
            begin
				sample_next         = {NB_SAMPLE{1'b0}}                                                             ;
				bit_index_next      = {NB_BIT_CNT{1'b0}}                                                            ;
				shifter_next        = i_data                                                                        ;
				state_next          = STATE_START                                                                   ;
			end
            else
            begin
                sample_next          = sample_reg                                                                   ;
                bit_index_next       = bit_index_reg                                                                ;
                shifter_next         = shifter_reg                                                                  ;
                state_next           = state_reg                                                                    ;
            end
		end
		STATE_START                                                                                                 : 
        begin
		    tx_done_tick            = 1'b0                                                                          ;
			tx_next                 = 1'b0                                                                          ;
            bit_index_next          = bit_index_reg                                                                 ;
            shifter_next            = shifter_reg                                                                   ;
			if (i_s_tick) 
            begin
				if (sample_reg == (SM_TICK / 2 - 1)) 
                begin
					sample_next     = {NB_SAMPLE{1'b0}}                                                             ;
					state_next      = STATE_DATA                                                                    ;
				end 
                else 
                begin
					sample_next     = sample_reg + {{NB_SAMPLE - 1 {1'b0}}, 1'b1}                                   ;
                    state_next      = state_reg                                                                     ;
				end
			end
		end
		STATE_DATA                                                                                                  : 
        begin
		    tx_done_tick            = 1'b0                                                                          ;
			tx_next                 = shifter_reg[0]                                                                ;
			if (i_s_tick)
            begin
				if (&sample_reg) 
                begin
					sample_next     = {NB_SAMPLE{1'b0}}                                                             ;
					shifter_next    = {1'b0, shifter_reg[NB_DATA - 1 : 1]}                                          ;
					if (&bit_index_reg) 
                    begin
                        bit_index_next = bit_index_reg                                                              ;
						state_next  = STATE_STOP                                                                    ;
					end 
                    else 
                    begin
						bit_index_next  = bit_index_reg + {{NB_BIT_CNT - 1 {1'b0}}, 1'b1}                           ;
                        state_next      = state_reg                                                                 ;
					end
				end 
                else 
                begin
                    bit_index_next      = bit_index_reg                                                             ;
					sample_next         = sample_reg + {{NB_SAMPLE - 1 {1'b0}}, 1'b1}                               ;
                    shifter_next        = shifter_reg                                                               ;
                    state_next          = state_reg                                                                 ;
				end
			end
		end

		STATE_STOP                                                                                                  : 
        begin
            tx_next                     = 1'b1                                                                      ;
            bit_index_next              = bit_index_reg                                                             ;
            shifter_next                = shifter_reg                                                               ;
			if (i_s_tick) 
            begin
				if (&sample_reg) 
                begin
					tx_done_tick        = 1'b1                                                                      ;
					sample_next         = {NB_SAMPLE{1'b0}}                                                         ;
					state_next          = STATE_IDLE                                                                ;
				end 
                else 
                begin
                    tx_done_tick        = 1'b0                                                                      ;
					sample_next         = sample_reg + {{NB_SAMPLE-1{1'b0}}, 1'b1}                                  ;
                    state_next          = state_reg                                                                 ;
				end
			end
            else
            begin
                tx_done_tick            = 1'b0                                                                      ;
                sample_next             = sample_reg                                                                ;
                state_next              = state_reg                                                                 ;
            end
		end

		endcase
	end

	always @(posedge clock or posedge i_rst) 
    begin
		if (i_rst) 
        begin
			state_reg       <= STATE_IDLE                                                                       ;
			sample_reg      <= {NB_SAMPLE{1'b0}}                                                                ;
			bit_index_reg   <= {NB_BIT_CNT{1'b0}}                                                               ;
			shifter_reg     <= {NB_DATA{1'b0}}                                                                  ;
			tx_reg          <= 1'b1                                                                             ;
		end 
        else 
        begin
			state_reg       <= state_next                                                                       ;
			sample_reg      <= sample_next                                                                      ;
			bit_index_reg   <= bit_index_next                                                                   ;
			shifter_reg     <= shifter_next                                                                     ;
			tx_reg          <= tx_next                                                                          ;
		end
	end

	assign o_tx            = tx_reg                                                                             ;
	assign o_tx_done_tick  = tx_done_tick                                                                       ;

endmodule
