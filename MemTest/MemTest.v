`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:51:47 07/30/2014 
// Design Name: 
// Module Name:    MemTest 
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
module MemTest(
	input RSTN,
	input clk40m,
	output LED
    );
	
	assign LED = RSTN;
	reg[15:0] writeData;
	wire[15:0] readData;
	reg[7:0] AddrA, AddrB;
	reg WEA;
	
	BlockMem(
		.clka(clk40m),
		.wea(WEA),
		.addra(AddrA),
		.dina(writeData),
		.clkb(clk40m),
		.addrb(AddrB),
		.doutb(readData)
	);
	
	wire[35:0] CONTROL;
	Mem_icon ICON(.CONTROL0(CONTROL));
	Mem_ila ILA(
		.CONTROL(CONTROL),
		.CLK(clk40m),
		.TRIG0(AddrA),
		.TRIG1(AddrB),
		.TRIG2(writeData),
		.TRIG3(readData)
	);

	always @(posedge clk40m or negedge RSTN) begin
		if(~RSTN) begin
			WEA <= 1'b1;
			AddrA <= 8'b0;
			AddrB <= 8'b0;
			writeData <= 16'b0;
		end
		else if(WEA) begin
			AddrA <= AddrA + 1;
			writeData <= {~AddrA,AddrA};
			AddrB <= AddrA;
		end
	end

endmodule
