module fifo 
#(
    parameter                                                                   NB_DATA    = 8                  ,                         
    parameter 																		                              NB_ADDRESS = 4                                
) 
(
    output wire [NB_DATA                                               - 1 : 0] o_data                          ,                  
    output wire                                                                 o_empty_flag                    ,                  
    output wire                                                                 o_full_flag                     ,                  
    input  wire                                                                 i_rd                            ,                  
    input  wire                                                                 i_wr                            ,                  
    input  wire [NB_DATA                                               - 1 : 0] i_data                          ,                  
    input  wire                                                                 i_rst                           ,                  
    input  wire                                                                 clock                         
)                                                                                                               ;

    localparam                                                                  STATE_READ  = 2'b01             ;
    localparam                                                                  STATE_WRITE = 2'b10             ; 
    localparam                                                                  STATE_RW    = 2'b11             ;

    localparam                                                                  NB_BUFFER   = 2**NB_ADDRESS     ;

    reg         [NB_DATA                                               - 1 : 0] fifo_buffer [NB_BUFFER  - 1 : 0];
    reg         [NB_ADDRESS                                            - 1 : 0] wr_ptr                          ;
    reg         [NB_ADDRESS                                            - 1 : 0] wr_ptr_next                     ;
    reg         [NB_ADDRESS                                            - 1 : 0] rd_ptr                          ; 
    reg         [NB_ADDRESS                                            - 1 : 0] rd_ptr_next                     ;
    reg                                                                         full_flag                       ;
    reg                                                                         full_next                       ;
    reg                                                                         empty_flag                      ; 
    reg                                                                         empty_next                      ;

    wire                                                                        wr_en                           ;
    integer                                                                     ptr                             ;

    always @(*) 
    begin
        wr_ptr_next = wr_ptr                                                                                    ;
        rd_ptr_next = rd_ptr                                                                                    ;
        full_next   = full_flag                                                                                 ;
        empty_next  = empty_flag                                                                                ;

        case ({i_wr,i_rd})
          STATE_READ                                                                                            : 
          begin
              if (~empty_flag) 
              begin
                  wr_ptr_next   = wr_ptr                                                                        ;
                  rd_ptr_next   = rd_ptr + {{NB_ADDRESS - 1 {1'b0}}, 1'b1}                                      ;
                  full_next     = 1'b0                                                                          ;
                  if ((rd_ptr + 1'b1) == wr_ptr)
                  begin
                      empty_next = 1'b1                                                                         ;                        
                  end
              end
          end
          STATE_WRITE                                                                                           :
          begin
              if (~full_flag) 
              begin
                  wr_ptr_next   = wr_ptr + {NB_ADDRESS - 1 {1'b0}, 1'b1}                                        ;
                  rd_ptr_next   = rd_ptr                                                                        ;
                  empty_next    = 1'b0                                                                          ;
                  if ((wr_ptr + 1'b1) == rd_ptr)
                  begin
                      full_next = 1'b1                                                                          ;
                  end
              end
          end
          STATE_RW                                                                                              : 
          begin 
              wr_ptr_next       = wr_ptr +  {NB_ADDRESS - 1 {1'b0}, 1'b1}                                       ;
              rd_ptr_next       = rd_ptr +  {NB_ADDRESS - 1 {1'b0}, 1'b1}                                       ;
              empty_next        = empty_flag                                                                    ;
              full_next         = full_flag                                                                     ;
          end 
        endcase
    end

    always @(posedge clock) 
    begin
        if (i_rst) 
        begin
            wr_ptr              <= {NB_ADDRESS{1'b0}}                                                           ;
            rd_ptr              <= {NB_ADDRESS{1'b0}}                                                           ;
            full_flag           <= 1'b0                                                                         ;
            empty_flag          <= 1'b1                                                                         ;
        end
        else 
        begin
            wr_ptr              <= wr_ptr_next                                                                  ;
            rd_ptr              <= rd_ptr_next                                                                  ;
            full_flag           <= full_next                                                                    ;
            empty_flag          <= empty_next                                                                   ;
        end
    end

    assign wr_en  = i_wr & ~full_flag                                                                           ;

    always @(posedge clock) 
    begin
      if (i_rst)
      begin
        for (ptr = 0; ptr < NB_BUFFER; ptr = ptr + 1)
        begin
          fifo_buffer[ptr]    <= {NB_DATA{1'b0}}                                                                ;  
        end 
      end           
      else
      begin
        if (wr_en)
        begin
          fifo_buffer[wr_ptr] <= i_data                                                                         ;
        end
      end
    end

     
    assign o_data         = fifo_buffer[rd_ptr]                                                                 ;
    assign o_full_flag    = full_flag                                                                           ;
    assign o_empty_flag   = empty_flag                                                                          ;
    
endmodule