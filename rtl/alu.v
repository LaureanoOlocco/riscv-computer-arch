// Implementar en FPGA una ALU:
//  - La ALU debe ser parametrizable (bus de datos) para poder ser utilizada posteriormente
//  - Validar el desarrollo con test bench
//  - Debe incluir generacion de entradas aleatorias y codigo de chequeo
//  - Simular el diseno usando vivado con analisis de tiempo

module ALU 
#(
    parameter                                  NB_DATA    = 8           ,   // Tamaño del bus de datos
    parameter                                  NB_OP_CODE = 6               // Número de bits del código de operación
)           
(           
    output  wire                               o_zero                   ,
    output  wire                               o_carry                  ,
    output  wire [NB_DATA            - 1 : 0]  o_result                 ,  // Salida de la alu
    input   wire [NB_DATA            - 1 : 0]  i_data_a                 ,  // 8 bits para a
    input   wire [NB_DATA            - 1 : 0]  i_data_b                 ,  // 8 bits para b
    input   wire [NB_OP_CODE         - 1 : 0]  i_op_code                   // 8 bits para operador
)                                                                       ;

    localparam                                 ADD_OP = 6'b100000       ;   
    localparam                                 SUB_OP = 6'b100010       ;
    localparam                                 AND_OP = 6'b100100       ;
    localparam                                 OR_OP  = 6'b100101       ;
    localparam                                 XOR_OP = 6'b100110       ;
    localparam                                 SRA_OP = 6'b000011       ;
    localparam                                 SRL_OP = 6'b000010       ;
    localparam                                 NOR_OP = 6'b100111       ;

    wire signed          [NB_DATA        : 0]  result                   ;

    always @(*) 
    begin        
        case (i_op_code)
            ADD_OP  : result = i_data_a +   i_data_b                    ; 
            SUB_OP  : result = i_data_a -   i_data_b                    ; 
            AND_OP  : result = i_data_a &   i_data_b                    ; 
            OR_OP   : result = i_data_a |   i_data_b                    ; 
            XOR_OP  : result = i_data_a ^   i_data_b                    ; 
            SRA_OP  : result = i_data_a >>> i_data_b                    ; 
            SRL_OP  : result = i_data_a >>  i_data_b                    ; 
            NOR_OP  : result = ~(i_data_a | i_data_b)                   ; 
            default : result = {NB_DATA{1'b0}}                          ; 
        endcase   
    end

    assign o_zero   = ~(|result)                                        ;
    assign o_carry  = ((i_op_code == ADD_OP && result[NB_DATA])        || 
                       (i_op_code == SUB_OP && ~result[NB_DATA]))       ; 
    assign o_result = result[NB_DATA - 1 : 0]                           ; 

endmodule
