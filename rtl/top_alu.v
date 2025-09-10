module top_alu
#(
    parameter                                  NB_DATA_OUT     = 10         ,
    parameter                                  NB_DATA_IN      = 8          ,   // Tamaño del bus de datos
    parameter                                  NB_OP_CODE_IN   = 6              // Número de bits del código de operación
    parameter                                  NB_INPUT_SELECT = 3
)
(
    output  wire [NB_DATA             - 1 : 0] o_led                        ,  
    input   wire [NB_INPUT_SELECT     - 1 : 0] i_btn                        ,
    input   wire [NB_DATA             - 1 : 0] i_sw_data                    ,
    input   wire                               i_valid                      ,
    input   wire                               i_rst                        ,
    input   wire                               clock                          
);

    localparam                                 DATA_A          = 2'b00      ;
    localparam                                 DATA_B          = 2'b01      ;
    localparam                                 OP_CODE         = 2'b10      ;

    wire                                       zero_out                     ;
    wire                                       carry_out                    ;
    wire         [NB_DATA             - 1 : 0] result_out                   ;
    reg          [NB_DATA             - 1 : 0] data_a_in                    ; 
    reg          [NB_DATA             - 1 : 0] data_b_in                    ;
    reg          [NB_OP               - 1 : 0] op_code_in                   ;
   
    ALU #(
        .NB_DATA    (NB_DATA_IN                                            ),
        .NB_OP      (NB_OP_CODE_IN                                         )
    ) 
    u_alu 
    (
        .o_zero     (zero_out                                              ),
        .o_carry    (carry_out                                             ),
        .o_result   (result_out                                            ),
        .i_data_a   (data_a_in                                             ),
        .i_data_b   (data_b_in                                             ),
        .i_op       (op_in                                                 ),
    )                                                                       ;

    always@(posedge clk or posedge i_rst) 
    begin
        if (i_rst) 
        begin
            data_a_in       <= 0                                            ;
            data_b_in       <= 0                                            ;
            op_code_in      <= 0                                            ;
        end
        else if(i_valid)
        begin
            if(i_btn[DATA_A])
            begin
                data_a_in   <= i_sw_data                                    ;
                data_b_in   <= data_b_in                                    ;
                op_code_in  <= op_code_in                                   ;
            end
            else if (i_btn[DATA_B]) 
            begin
                data_a_in   <= data_a_in                                    ;
                data_b_in   <= i_sw_data                                    ;
                op_code_in  <= op_code_in                                   ;
            end
            else if(i_btn[OP_CODE])
            begin
                data_a_in   <= data_a_in                                    ;
                data_b_in   <= data_b_in                                    ;
                op_code_in  <= i_sw_data[NB_OP_CODE_IN  - 1 : 0]            ;
            end
            else
            begin
                data_a_in   <= data_a_in                                    ;
                data_b_in   <= data_b_in                                    ;
                op_code_in  <= op_code_in                                   ;
            end
        end    
        else
        begin
            data_a_in       <= data_a_in                                    ;
            data_b_in       <= data_b_in                                    ;
            op_code_in      <= op_code_in                                   ;
        end
    end    

    assign o_led = {zero_out, carry_out, result_out}                        ;
    
endmodule
