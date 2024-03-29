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
	
	reg [23:0] count;//7
	assign CSN = 0;
//	assign RSTN = 1;
	reg [15:0] SDReg;//8
	reg [15:0] outData;//9
	
	assign LED = 1;
	
//	always @(posedge clk40m) begin//period = 2.5ns
//		count = count + 1;
//		if(count == 12'h100) begin
//			CMD = 1;
//			WRN = 0;
//			SDReg = 16'h30C0;		
//		end
//		else if(count == 12'h102) begin//WRN active time = 10ns + 40ns(data is valid)
//			WRN = 1;//latch address
//		end
//		else if(count == 12'h103) begin//WRN inactive time = 25ns
//			SDReg = 16'hz;//high-impedance
//			CMD = 0;
//			RDN = 0;
//		end
//		else if(count == 12'h105) begin//RDN active time = 50ns in between
//			RDN = 1;
//			outData = SD;
//		end
//		//Another write
//		else if(count == 12'h106) begin
//			CMD = 1;
//			WRN = 0;
//			SDReg = 16'h3010;		
//		end
//		else if(count == 12'h108) begin//WRN active time = 10ns + 40ns(data is valid)
//			WRN = 1;//latch address
//		end
//		else if(count == 12'h109) begin//WRN inactive time = 25ns
//			SDReg = 16'h89AB;//inData
//			CMD = 0;
//			WRN = 0;
//		end
//		else if(count == 12'h10B) begin//RDN active time = 50ns in between
//			WRN = 1;
//			outData = 16'hFFFF;
//		end
//	end

	always @(posedge clk40m or negedge RSTN) begin
		if(!RSTN) begin
			WRN <= 1;
			RDN <= 1;
			CMD <= 1;
			count <= 24'h00_0000;
			outData <= 16'hFFFF;
		end
		else begin
			count <= count + 24'h00_0001;
			if(count == 24'h20_0001) begin
				CMD <= 1;
				WRN <= 0;
				SDReg <= 16'h30C0;		
			end
			else if(count == 24'h20_0003) begin//WRN active time = 10ns + 40ns(data is valid)
				WRN <= 1;//latch address
			end
			else if(count == 24'h20_0004) begin//WRN inactive time = 25ns
				SDReg <= 16'hz;//high-impedance
				CMD <= 0;
				RDN <= 0;
			end
			else if(count == 24'h20_0005) begin
				outData <= SD;
			end
			else if(count == 24'h20_0006) begin//RDN active time = 50ns in between
				RDN <= 1;
			end
//			//Another write
//			else if(count == 12'h106) begin
//				CMD = 1;
//				WRN = 0;
//				SDReg = 16'h3010;		
//			end
//			else if(count == 12'h108) begin//WRN active time = 10ns + 40ns(data is valid)
//				WRN = 1;//latch address
//			end
//			else if(count == 12'h109) begin//WRN inactive time = 25ns
//				SDReg = 16'h89AB;//inData
//				CMD = 0;
//				WRN = 0;
//			end
//			else if(count == 12'h10B) begin//RDN active time = 50ns in between
//				WRN = 1;
//				count = count - 1;
//			end
		end
	end
	
	
	assign SD = RDN ? SDReg:16'hz;	
	

	wire[35:0] ILAControl;
	NewAttempt_icon ICON(
		.CONTROL0(ILAControl)
	);
	NewAttempt_ila ILA(
		.CONTROL(ILAControl),
		.CLK(clk40m),
		.TRIG0(clk40m),
		.TRIG1(RSTN),
		.TRIG2(CMD),
		.TRIG3(RDN),
		.TRIG4(WRN),
		.TRIG5(SD),
		.TRIG6({count[23:16],count[3:0]}),
		.TRIG7(SDReg),
		.TRIG8(outData)
	);

endmodule
