// File name   : top_alu.v
// Date        : 2025-10-09
// Author      : Sofía Avalos - Laureano Olocco
// Description : Top-level wrapper for the parameterizable ALU.
//                - Parameters:
//                    * NB_DATA_OUT     = 10 // width of LED/output bus (result + flags)
//                    * NB_DATA_IN      = 8  // input data bus width
//                    * NB_OP_CODE_IN   = 6  // opcode bus width
//                    * NB_INPUT_SELECT = 3  // button input width
//                - Instantiates the ALU with given NB_DATA_IN and NB_OP_CODE_IN.
//                - Internal registers store i_sw_data depending on which button is pressed:
//                    * i_btn[DATA_A]   : load operand A
//                    * i_btn[DATA_B]   : load operand B
//                    * i_btn[OP_CODE] : load opcode (truncated/zero-extended to NB_OP_CODE_IN)
//                - Reset logic clears internal registers on i_rst.
//                - Sequential process (@posedge clock or posedge reset) updates ALU inputs.
//                - Output mapping:
//                    * o_led = {o_zero, o_carry, o_result}
//                      where:
//                        - o_zero   : 1 if ALU result is zero
//                        - o_carry  : carry flag from ALU
//                        - o_result : ALU computed value (NB_DATA_IN bits)
//                - Purpose: Provide an FPGA-friendly interface where inputs are controlled
//                  via push-buttons (i_btn) and switches (i_sw_data), with real-time
//                  LED visualization of ALU results and flags.
//--------------------------------------------------------------------------------------------------

module top_alu
#(
//----------------------------------------- PARAMETERS --------------------------------------------//

    parameter                                  NB_DATA_OUT     = 10                                 ,
    parameter                                  NB_DATA_IN      = 8                                  ,   // Tamaño del bus de datos
    parameter                                  NB_OP_CODE_IN   = 6                                  ,    // Número de bits del código de operación
    parameter                                  NB_INPUT_SELECT = 3                      
)
(
//------------------------------------------ OUTPUTS ---------------------------------------------//    
    output  wire [NB_DATA_OUT         - 1 : 0] o_led                                                , 
//------------------------------------------- INPUTS ---------------------------------------------// 
    input   wire [NB_INPUT_SELECT     - 1 : 0] i_btn                                                ,
    input   wire [NB_DATA_IN          - 1 : 0] i_sw_data                                            ,
    input   wire                               i_rst                                                ,
    input   wire                               clock                          
);

//---------------------------------------- local params ------------------------------------------// 
    localparam                                 DATA_A          = 2'b00                              ;
    localparam                                 DATA_B          = 2'b01                              ;
    localparam                                 OP_CODE         = 2'b10                              ;

//-------------------------------------------- Wires ---------------------------------------------// 
    wire                                       zero_out                                             ;
    wire                                       carry_out                                            ;
    wire         [NB_DATA_IN          - 1 : 0] result_out                                           ;

//------------------------------------------ Registers -------------------------------------------// 
    reg          [NB_DATA_IN          - 1 : 0] data_a_in                                            ; 
    reg          [NB_DATA_IN          - 1 : 0] data_b_in                                            ;
    reg          [NB_OP_CODE_IN       - 1 : 0] op_code_in                                           ;

//----------------------------------------- Sequential logic -------------------------------------// 
    always@(posedge clock or posedge i_rst) 
    begin
        if (i_rst) 
        begin
            data_a_in       <= 0                                                                    ;
            data_b_in       <= 0                                                                    ;
            op_code_in      <= 0                                                                    ;
        end                     
        else if(i_btn[DATA_A])                      
        begin                       
            data_a_in       <= i_sw_data                                                            ;
            data_b_in       <= data_b_in                                                            ;
            op_code_in      <= op_code_in                                                           ;
        end                     
        else if (i_btn[DATA_B])                         
        begin                       
            data_a_in       <= data_a_in                                                            ;
            data_b_in       <= i_sw_data                                                            ;
            op_code_in      <= op_code_in                                                           ;
        end                     
        else if(i_btn[OP_CODE])                     
        begin                       
            data_a_in       <= data_a_in                                                            ;
            data_b_in       <= data_b_in                                                            ;
            op_code_in      <= i_sw_data[NB_OP_CODE_IN  - 1 : 0]                                    ;
        end                     
        else                        
        begin                       
            data_a_in       <= data_a_in                                                            ;
            data_b_in       <= data_b_in                                                            ;
            op_code_in      <= op_code_in                                                           ;
        end                     
    end                         

//---------------------------------------------Instances -----------------------------------------// 
    ALU #(
        .NB_DATA    (NB_DATA_IN                                                                     ),
        .NB_OP_CODE (NB_OP_CODE_IN                                                                  )
    )                           
    u_alu                           
    (                           
        .o_zero     (zero_out                                                                       ),
        .o_carry    (carry_out                                                                      ),
        .o_result   (result_out                                                                     ),
        .i_data_a   (data_a_in                                                                      ),
        .i_data_b   (data_b_in                                                                      ),
        .i_op_code  (op_code_in                                                                     )
    )                                                                                                ;

//--------------------------------------------- Outputs ------------------------------------------// 
    assign o_led = {zero_out, carry_out, result_out}                                                ;

endmodule
