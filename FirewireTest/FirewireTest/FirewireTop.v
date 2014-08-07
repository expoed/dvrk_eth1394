`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:13:15 08/04/2014 
// Design Name: 
// Module Name:    FirewireTop 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "Constants.v"
module FirewireTop(
    // ieee 1394 phy-link interface
    input            clk1394,   // 49.152 MHz
    inout [7:0]      data,
    inout [1:0]      ctl,
    output wire      lreq,
    output wire      reset_phy,
	// for debugging
	input [3:0]      wenid,
	output wire      LED,
	input RSTN
	);
	
	wire reset;
	assign reset = RSTN;
    wire lreq_trig;
    wire[2:0] lreq_type;
    wire reg_wen;               // register write signal
    wire[10:0] addra;       // 11-bit reg read address
	wire[31:0] dina, douta;
    reg[10:0] addrb;       // 11-bit reg write address
    wire[31:0] dout;       // reg read data
	reg[31:0] dinb;
	reg web;
	reg[10:0] PC_Req_len;
	wire[10:0] Resp_Data_len;
	wire PC_REQ_Done, PC_REQ_Done_Prev;
	reg PC_REQ_NEW;
	
	BUFG clksysclk(.I(clk1394), .O(sysclk));
	// 1394 phy low reset, never reset
	assign reset_phy = 1'b1;
	
	reg [19:0] count;
	
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			PC_Req_len <= 11'd160;
			addrb <= `ADDR_DEFAULT;
			dinb <= 32'bz;
			count <= 0;
			PC_REQ_NEW <= 0;
		end
		else if(PC_REQ_Done)begin
			case(count)
//				0: begin
//					addrb <= `ADDR_PC_REQ;
//					web <= 01;
//					dinb <= 32'hFFC0_0040;
//				end
//				1: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hFFFF_0000;
//				end
//				2: begin
//					addrb <= addrb + 1;
//					dinb <= 32'h0000_0000;//Status
//				end
//				3: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hdaad_a572;
//				end
//				4: begin
//					addrb <= `ADDR_DEFAULT;
//					dinb <= 32'hz;
//					web <= 0;
//				end
//				5: begin
//					PC_REQ_NEW <= 1;
//				end
//				6: begin
//					PC_REQ_NEW <= 0;
//				end
//				200: begin
//					addrb <= `ADDR_PC_REQ;
//					web <= 01;
//					dinb <= 32'hFFC0_0040;
//				end
//				201: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hFFFF_0000;
//				end
//				202: begin
//					addrb <= addrb + 1;
//					dinb <= 32'h0000_0001;//Status
//				end
//				203: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hde6c_b8c5;
//				end
//				204: begin
//					addrb <= `ADDR_DEFAULT;
//					dinb <= 32'hz;
//					web <= 0;
//				end
//				205: begin
//					PC_REQ_NEW <= 1;
//				end
//				206: begin
//					PC_REQ_NEW <= 0;
//				end
//				300: begin
//					addrb <= `ADDR_PC_REQ;
//					web <= 01;
//					dinb <= 32'hFFC0_0040;
//				end
//				301: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hFFFF_0000;
//				end
//				302: begin
//					addrb <= addrb + 1;
//					dinb <= 32'h0000_0002;//Status
//				end
//				303: begin
//					addrb <= addrb + 1;
//					dinb <= 32'hd32f_9e1c;
//				end
//				304: begin
//					addrb <= `ADDR_DEFAULT;
//					dinb <= 32'hz;
//					web <= 0;
//				end
//				305: begin
//					PC_REQ_NEW <= 1;
//				end
//				306: begin
//					PC_REQ_NEW <= 0;
//				end
				400: begin
					addrb <= `ADDR_PC_REQ;
					web <= 01;
					dinb <= 32'hFFC0_0000;
				end
				401: begin
					addrb <= addrb + 1;
					dinb <= 32'hFFFF_0000;
				end
				402: begin
					addrb <= addrb + 1;
					dinb <= 32'h0000_0003;
				end
				403: begin
					addrb <= addrb + 1;
					dinb <= 32'h1234_5678;
				end
				404: begin
					addrb <= addrb + 1;
					dinb <= 32'hefc6_56fc;
				end
				405: begin
					addrb <= `ADDR_DEFAULT;
					dinb <= 32'hz;
					web <= 0;
				end
				406: begin
					PC_REQ_NEW <= 1;
				end
				407: begin
					PC_REQ_NEW <= 0;
				end
			endcase
			count <= count + 1;
		end
	end
	

	// phy-link interface
	PhyLinkInterface phy(
		.sysclk(sysclk),         // in: global clk  
		.reset(reset),           // in: global reset
		.board_id(~wenid),       // in: board id (rotary switch)
		.ctl_ext(ctl),           // bi: phy ctl lines
		.data_ext(data),         // bi: phy data lines
		.reg_wen(wea),       // out: reg write signal
		
		.reg_addr(addra),     // out: register address
		.reg_rdata(douta),   // in:  read data to external register
		.reg_wdata(dina),   // out: write data to external register

		.lreq_trig(lreq_trig),   // out: phy request trigger
		.lreq_type(lreq_type),    // out: phy request type

		.PC_Req_len(PC_Req_len),
		.Resp_Data_len(Resp_Data_len),
		.PC_REQ_NEW(PC_REQ_NEW),
		.PC_REQ_Done(PC_REQ_Done)//1: req executed, 0: not executed
	);


	// phy request module
	PhyRequest phyreq(
		.sysclk(sysclk),          // in: global clock
		.reset(reset),            // in: reset
		.lreq(lreq),              // out: phy request line
		.trigger(lreq_trig),      // in: phy request trigger
		.rtype(lreq_type)         // in: phy request type
	);

	Block_Mem_Gen BlockMem(
		.clka(sysclk),       
		.wea(wea),
		.addra(addra),
		.dina(dina),
		.douta(douta),
		.clkb(sysclk),
		.web(web),
		.addrb(addrb),
		.dinb(dinb),
		.doutb(doutb)
	);
	
	assign LED = 1'b0;

endmodule
