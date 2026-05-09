`default_nettype none

module regfile
#(
//----------------------------------------- PARAMETERS --------------------------------------------//
  parameter                                                     NB_DATA       = 32                  ,
  parameter                                                     NB_ADDRESS    = $clog2(NB_DATA)
) 
(
//------------------------------------------ OUTPUTS PORTS ----------------------------------------//
  // Register File Outputs Ports
  output wire [NB_DATA                                - 1 : 0]  o_data_a                            ,  
  output wire [NB_DATA                                - 1 : 0]  o_data_b                            ,
//------------------------------------------- INPUTS PORTS ----------------------------------------//
  // Register File Input Ports
  input  wire [NB_ADDRESS                             - 1 : 0]  i_read_address_a                    ,
  input  wire [NB_ADDRESS                             - 1 : 0]  i_read_address_b                    , 
  input  wire [NB_ADDRESS                             - 1 : 0]  i_write_address                     , 
  input  wire [NB_DATA                                - 1 : 0]  i_write_data                        ,
  input  wire                                                   i_write_enable                      ,
  input  wire                                                   i_reset                             , 
  input  wire                                                   clock       
)                                                                                                   ;

//----------------------------------------- Local Params ------------------------------------------//
  localparam                                                    REGFILE_DEPTH = 2**NB_ADDRESS       ;   

//--------------------------------------- Bank of Registers ---------------------------------------//
  reg       [NB_DATA                                  - 1 : 0]  regfile [REGFILE_DEPTH - 1 : 0]     ;

//------------------------------------------- Constants ------------------------------------------//
  integer                                                       index                               ;

//--------------------------------------- Sequential Logic ---------------------------------------//
  // Write Operation
  always @(posedge clock) 
  begin
    if (i_reset) 
    begin
      for (index = 0; index < REGFILE_DEPTH; index = index + 1)
      begin
        regfile[index]                  <= {NB_DATA{1'b0}}                                          ;
      end
    end
    else 
    begin
      if (i_write_enable)
      begin
        if (i_write_address != {NB_ADDRESS{1'b0}}) 
        begin 
          regfile[i_write_address]      <= i_write_data                                             ;
        end
      end
    end
  end

//-------------------------------------------- Outputs -------------------------------------------//
  assign o_data_a                           = regfile[i_read_address_a]                             ;
  assign o_data_b                           = regfile[i_read_address_b]                             ;

endmodule