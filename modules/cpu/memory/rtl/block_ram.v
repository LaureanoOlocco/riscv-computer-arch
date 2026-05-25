//--------------------------------------------------------------------------------------------------
// Project     : RISC-V Computer Architecture
// Module name : block_ram.v
// Date        : 2025-12-08
// Author      : Sofía Avalos - Laureano Olocco
// Description : Parameterizable Block RAM module.
//                - Dual-port RAM with independent read ports A and B, and a single write port
//                - Configurable data width (NB_DATA) and address width (NB_ADDRESS).
//                - Synchronous write on clock's rising edge, asynchronous read on clock's falling edge.
//--------------------------------------------------------------------------------------------------

`default_nettype none

module block_ram
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,
  parameter                                                     NB_ADDRESS    = 8                 
) 
(
//----------------------------------------- OUTPUTS PORTS ----------------------------------------//    
  // RAM Output Ports
  output wire [NB_DATA                                - 1 : 0]  o_data_a                            ,
  output wire [NB_DATA                                - 1 : 0]  o_data_b                            ,
//------------------------------------------ INPUTS PORTS ----------------------------------------//
  // RAM Input Ports
  input  wire                                                   i_read_en_data_a                    ,
  input  wire [NB_ADDRESS                             - 1 : 0]  i_read_address_a                    ,
  input  wire                                                   i_read_en_data_b                    ,
  input  wire [NB_ADDRESS                             - 1 : 0]  i_read_address_b                    ,
  input  wire                                                   i_write_en                          ,
  input  wire [NB_ADDRESS                             - 1 : 0]  i_write_address                     ,
  input  wire [NB_DATA                                - 1 : 0]  i_write_data                        ,
  input  wire                                                   clock    
)                                                                                                   ;
    
//----------------------------------------- Local Params -----------------------------------------// 
  localparam                                                    MEMORY_DEPTH  = 2**NB_ADDRESS       ;   

//--------------------------------------- Internal Signals ---------------------------------------//
  (* ram_style = "block" *) reg [NB_DATA - 1 : 0] ram [MEMORY_DEPTH - 1 : 0]                        ;

  reg       [NB_DATA                                  - 1 : 0]  output_data_a                       ;  
  reg       [NB_DATA                                  - 1 : 0]  output_data_b                       ;  

  
//----------------------------------------- Initial State ---------------------------------------//
  integer index                                                                                     ;
  initial 
  begin
    for (index = 0; index < MEMORY_DEPTH; index = index + 1)
        ram[index] = {NB_DATA{1'b0}}                                                                ;
  end
  
//--------------------------------------- Sequential Logic ---------------------------------------//
  // Write Logic
  always @(posedge clock) 
  begin
    if (i_write_en)
    begin
      ram[i_write_address]  <= i_write_data                                                         ;
    end
  end
  
  // Read Logic data A
  always @(negedge clock) 
  begin
    if (i_read_en_data_a)
    begin
      output_data_a         <= ram[i_read_address_a]                                                ;
    end
  end

  // Read Logic data B
  always @(negedge clock) 
  begin
    if (i_read_en_data_b)
    begin
      output_data_b         <= ram[i_read_address_b]                                                ;
    end
  end


//-------------------------------------------- Outputs -------------------------------------------//
  assign o_data_a    = output_data_a                                                                ;
  assign o_data_b    = output_data_b                                                                ;
endmodule