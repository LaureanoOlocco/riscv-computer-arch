// File name   : alu.v
// Date        : 2025-10-09
// Author      : Sofía Avalos - Laureano Olocco
// Description : Synthesizable, parameterizable ALU intended for FPGA targets.
//                - Datapath width is configurable via NB_DATA (default: 8), enabling reuse in larger designs.
//                - Opcode width is configurable via NB_OP (default: 6). Supported operations include, at minimum:
//                    * ADD, SUB, AND, OR, XOR, NOT, logical shifts (SRA/SRL); extendable via parameters/generate.
//                - Purely combinational core (no clock/reset) for the arithmetic/logic stage.
//                - Flag outputs:
//                    * o_zero     = (o_result == 0)
//                    * o_carry    = carry-out from ADD/SUB
//                - Interface:
//                    * i_a[NB_DATA-1:0], i_b[NB_DATA-1:0], i_op[NB_OP-1:0]
//                    * o_result[NB_DATA-1:0], o_zero, o_carry, o_overflow
//    
//                - Parameters:
//                    * NB_DATA    = 8   // data bus width
//                    * NB_OP_CODE = 6   // opcode width
//                
//                - This module is designed to be reusable and easily extended: add new opcodes by
//                allocating codes in i_op and extending the combinational case, alongside testbench checks.

//--------------------------------------------------------------------------------------------------

module ALU 
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
    parameter                                  NB_DATA    = 8                                       ,   // Tamaño del bus de datos
    parameter                                  NB_OP_CODE = 6                                           // Número de bits del código de operación
)           
(       
//------------------------------------------ OUTPUTS ---------------------------------------------//    
    output  wire                               o_zero                                               ,
    output  wire                               o_carry                                              ,
    output  wire [NB_DATA            - 1 : 0]  o_result                                             ,  // Salida de la alu
//------------------------------------------- INPUTS ---------------------------------------------// 
    input   wire [NB_DATA            - 1 : 0]  i_data_a                                             ,  // 8 bits para a
    input   wire [NB_DATA            - 1 : 0]  i_data_b                                             ,  // 8 bits para b
    input   wire [NB_OP_CODE         - 1 : 0]  i_op_code                                               // 8 bits para operador
)                                                                                                   ;

//---------------------------------------- local params ------------------------------------------// 
    localparam                                 ADD_OP = 6'b100000                                   ;   
    localparam                                 SUB_OP = 6'b100010                                   ;
    localparam                                 AND_OP = 6'b100100                                   ;
    localparam                                 OR_OP  = 6'b100101                                   ;
    localparam                                 XOR_OP = 6'b100110                                   ;
    localparam                                 SRA_OP = 6'b000011                                   ;
    localparam                                 SRL_OP = 6'b000010                                   ;
    localparam                                 NOR_OP = 6'b100111                                   ;

//------------------------------------------ Registers -------------------------------------------// 
    reg          [NB_DATA               : 0]   result                                               ;

//-------------------------------------- Combinational logic -------------------------------------// 
    always @(*) 
    begin        
        case (i_op_code)
            ADD_OP  : result = {1'b0, i_data_a} + {1'b0, i_data_b}                                  ; 
            SUB_OP  : result = {1'b0, i_data_a} - {1'b0, i_data_b}                                  ; 
            AND_OP  : result = {1'b0, (i_data_a & i_data_b)}                                        ; 
            OR_OP   : result = {1'b0, (i_data_a | i_data_b)}                                        ; 
            XOR_OP  : result = {1'b0, (i_data_a ^ i_data_b)}                                        ; 
            SRA_OP  : result = {1'b0, ($signed(i_data_a) >>> i_data_b[$clog2(NB_DATA)-1:0])}        ; 
            SRL_OP  : result = {1'b0, (i_data_a >>  i_data_b[$clog2(NB_DATA)-1:0])}                 ; 
            NOR_OP  : result = {1'b0, ~(i_data_a | i_data_b)}                                       ; 
            default : result = {(NB_DATA+1){1'b0}}                                                  ; 
        endcase                             
    end

//--------------------------------------------- Outputs ------------------------------------------// 
    assign o_zero   = ~(|result)                                                                     ;
    assign o_carry  = ((i_op_code == ADD_OP && result[NB_DATA])                                     || 
                       (i_op_code == SUB_OP && ~result[NB_DATA]))                                    ; 
    assign o_result = result[NB_DATA - 1 : 0]                                                        ; 

endmodule
