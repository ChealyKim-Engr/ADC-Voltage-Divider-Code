`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Digilent Inc.
// Engineer: Samuel Lowe
// 
// Create Date: 4/14/2016
// Design Name: Cmod A7 Xadc reference project 
// Module Name: XADC
// Target Devices: Digilent Cmod A7 15t rev. B
// Tool Versions: Vivado 2015.4
// Description: Demo that will take input from a button to decide which xadc channel to drive a pwm'd led
// Dependencies: 
// 
// Revision:  
// Revision 0.01 - File Created
// Additional Comments: 
//               
// 
//////////////////////////////////////////////////////////////////////////////////
 

module xadc_user_logic(
    input S_AXI_ACLK,
    input slv_reg_wren,
	input slv_reg_rden,
    input [2:0] axi_awaddr,
	input [2:0] axi_araddr,
    input [31:0] S_AXI_WDATA,
    input S_AXI_ARESETN,
	
    output [7:0] data_out,
    output wire [3:0] led,
    input [3:0] xa_n,
    input [3:0] xa_p
);
   
    //XADC signals
    wire enable;                     //enable into the xadc to continuosly get data out
    reg [6:0] Address_in = 7'h14;    //Adress of register in XADC drp corresponding to data
    wire ready;                      //XADC port that declares when data is ready to be taken
    wire [15:0] data;                //XADC data   
    reg [15:0] data0, data1, data2, data3;
    wire [11:0] shifted_data0, shifted_data1, shifted_data2, shifted_data3;
    wire [4:0] channel_out;
    reg [1:0] sel;
	reg [3:0] sw_reg;
    
    ///////////////////////////////////////////////////////////////////
    //XADC Instantiation
    //////////////////////////////////////////////////////////////////
    
    xadc_wiz_0  xadc_wiz_instance (
        .daddr_in    (Address_in), 
        .dclk_in     (S_AXI_ACLK), 
        .den_in      (enable & |sw_reg), 
        .di_in       (0),
        .dwe_in      (0),
        .busy_out    (),
        .vauxp15     (xa_p[2]),
        .vauxn15     (xa_n[2]),
        .vauxp14     (xa_p[0]),
        .vauxn14     (xa_n[0]),               
        .vauxp7      (xa_p[1]),
        .vauxn7      (xa_n[1]),
        .vauxp6      (xa_p[3]),
        .vauxn6      (xa_n[3]),               
        .do_out      (data),
        .vp_in       (),
        .vn_in       (),
        .eoc_out     (enable),
        .channel_out (channel_out),
        .drdy_out    (ready)
    ); 
                                  
    ///////////////////////////////////////////////////////////////////
    //Address Handling Controlled by button
    //////////////////////////////////////////////////////////////////   

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
         sw_reg <= 4'b0;
     else 
        begin
            if (slv_reg_wren && (axi_awaddr == 3'h3)) 
	            begin
                    sw_reg <= S_AXI_WDATA[3:0];
		        end
        end
   end	
    
    always @(sel)      
        case(sel)
        0: Address_in <= 8'h1e;
        1: Address_in <= 8'h17;  
        2: Address_in <= 8'h1f;  
        3: Address_in <= 8'h16;
        default: Address_in <= 8'h14;
        endcase
    always@(negedge ready)
        case (sel)//next select is always next enabled channel, example: sel=0, sw=1001 -> sel=3
        0: sel <= (sw_reg[1] ? 1 : (sw_reg[2] ? 2 : (sw_reg[3] ? 3 : 0)));
        1: sel <= (sw_reg[2] ? 2 : (sw_reg[3] ? 3 : (sw_reg[0] ? 0 : 1)));
        2: sel <= (sw_reg[3] ? 3 : (sw_reg[0] ? 0 : (sw_reg[1] ? 1 : 2)));
        3: sel <= (sw_reg[0] ? 0 : (sw_reg[1] ? 1 : (sw_reg[2] ? 2 : 3)));
        default: sel <= 0;
        endcase
    assign data_out = {ready, 2'b0, channel_out[4:0]};
    always@(posedge ready) begin
        case (sel)
        0: data0 <= (channel_out == 8'h1E) ? data : data0;
        1: data1 <= (channel_out == 8'h17) ? data : data1;
        2: data2 <= (channel_out == 8'h1F) ? data : data2;
        3: data3 <= (channel_out == 8'h16) ? data : data3;
        endcase
    end
    ///////////////////////////////////////////////////////////////////
    //LED PWM
    //////////////////////////////////////////////////////////////////  
    
    integer pwm_end = 4070;
    //filter out tiny noisy part of signal to achieve zero at ground
    assign shifted_data0 = (data0 >> 4) & 12'hff0;
    assign shifted_data1 = (data1 >> 4) & 12'hff0;
    assign shifted_data2 = (data2 >> 4) & 12'hff0;
    assign shifted_data3 = (data3 >> 4) & 12'hff0;

    integer pwm_count = 0;  

    //Pwm the data to show the voltage level
    always @(posedge(S_AXI_ACLK))begin
        if(pwm_count < pwm_end)begin
            pwm_count = pwm_count+1;
        end           
        else begin
            pwm_count=0;
        end
    end
    //leds are active high
    assign led[0] = (sw_reg[0] == 1'b0) ? 1'b0 : (pwm_count < shifted_data0 ? 1'b1 : 1'b0);
    assign led[1] = (sw_reg[1] == 1'b0) ? 1'b0 : (pwm_count < shifted_data1 ? 1'b1 : 1'b0);
    assign led[2] = (sw_reg[2] == 1'b0) ? 1'b0 : (pwm_count < shifted_data2 ? 1'b1 : 1'b0);
    assign led[3] = (sw_reg[3] == 1'b0) ? 1'b0 : (pwm_count < shifted_data3 ? 1'b1 : 1'b0);
       
endmodule
