`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:51:03 07/22/2014 
// Design Name: 
// Module Name:    NewAttempt 
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
module NewAttempt(
	input clk40m,//0
	output wire CSN,//1
	input wire RSTN,
	input wire PME,
	output reg CMD,//2
	input wire INTRN,
	output reg RDN,//3
	output reg WRN,//4
	inout [15:0] SD,//5
	output wire LED
    );

//	wire clk200m;
//	wire clk400m;
//	
//	CLK_Gen Gen(
//		.clk40m(clk40m),
//		.clk200m(clk200m),
//		.clk400m(clk400m)
//	);
	
	reg [11:0] count;//7
	assign CSN = 0;
//	assign RSTN = 1;
	reg [15:0] SDReg;//8
	assign SD = RDN ? SDReg:16'bz;
	reg [15:0] outData;//9
	
	assign LED = RSTN;
	
//	always @(posedge RDN) begin		
//		outData <= SD;
//	end
	
	always @(posedge clk40m) begin//period = 2.5ns
		count = count + 1;
		if(count == 12'h100) begin
			CMD = 1;
			WRN = 0;
			SDReg = 16'h30C0;			
		end
		else if(count == 12'h102) begin//WRN active time = 10ns + 40ns(data is valid)
			WRN = 1;//latch address
		end
		else if(count == 12'h103) begin//WRN inactive time = 25ns
			SDReg = 16'hz;//high-impedance
			CMD = 0;
			RDN = 0;
		end
		else if(count == 12'h105) begin//RDN active time = 50ns in between
			RDN = 1;
			outData = SD;
		end
		//Another write
		else if(count == 12'h106) begin
			CMD = 1;
			WRN = 0;
			SDReg = 16'h3010;		
		end
		else if(count == 12'h108) begin//WRN active time = 10ns + 40ns(data is valid)
			WRN = 1;//latch address
		end
		else if(count == 12'h109) begin//WRN inactive time = 25ns
			SDReg = 16'h89AB;//inData
			CMD = 0;
			WRN = 0;
		end
		else if(count == 12'h10B) begin//RDN active time = 50ns in between
			WRN = 1;
			outData = 16'hFFFF;
			count = 12'h0FF;
		end
	end

	wire[35:0] ILAControl;
	NewAttempt_icon ICON(
		.CONTROL0(ILAControl)
	);
	NewAttempt_ila ILA(
		.CONTROL(ILAControl),
		.CLK(clk40m),
		.TRIG0(clk40m),
		.TRIG1(CSN),
		.TRIG2(CMD),
		.TRIG3(RDN),
		.TRIG4(WRN),
		.TRIG5(SD),
		.TRIG6(count),
		.TRIG7(SDReg),
		.TRIG8(outData)
	);

endmodule
