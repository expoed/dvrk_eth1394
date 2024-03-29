`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:42:48 07/23/2014 
// Design Name: 
// Module Name:    Initialization 
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
module Initialization(
	input sysclk,
	input reset,
	output reg[7:0] offset,
	output reg length,
	output reg WR,
	output reg[15:0] writeData,
	input[15:0] readData,
	output reg NewCommand,
	input[3:0] state,
	output reg initDone
	);
	
	reg warmDone;
	reg[27:0] warmCount;//0.0524s is needed to warm up
	reg[4:0] step;
	wire negInitDone;
	assign negInitDone = ~initDone;//very important! to avoid error of top module MUX caused by intermediate ~initDone
	
	localparam [3:0] Addr0  = 4'b0000,
					 Addr1  = 4'b0001,
					 Addr2  = 4'b0010,
					 Read0  = 4'b0011,
					 Read1  = 4'b0100,
					 Read2  = 4'b0101,
					 Write0 = 4'b0110,
					 Write1 = 4'b0111,
					 Write2 = 4'b1000,
					 Wait   = 4'b1001;
	
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			warmCount <= 0;
			warmDone <= 0;
			step <= 0;
			initDone <= 0;
			writeData <= 16'bz;
			NewCommand <= 0;
		end
		else if(!warmDone) begin
			warmCount <= warmCount + 1;
			if(warmCount == 28'h01FFFFF) begin
				warmDone <= 1;
			end
		end
		else if(warmDone && negInitDone) begin
//========================= step 0: read device chip ID 
			if(step == 0) begin
				if(state == Wait) begin
					NewCommand <= 1;
					WR <= 0;
					offset <= 8'hC0;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 0;
					step <= step + 1;
				end
			end
//========================= step 1: verify device chip ID
			else if(step == 1) begin
				if(readData == 16'hx87x) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 2: Write QMU MAC address(low)
			else if(step == 2) begin
				if(state == Wait) begin
					WR <= 1;
					offset <= 8'h10;
					length <= 1;
					writeData <= 16'h89AB;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 3: Write QMU MAC address(medium)
			else if(step == 3) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h12;
					length <= 1;
					writeData <= 16'h4567;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 4: Write QMU MAC address(high)
			else if(step == 4) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h14;
					length <= 1;
					writeData <= 16'h0123;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 5: Enable QMU Transmit Frame Data Pointer Auto Increment
			else if(step == 5) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h84;
					length <= 1;
					writeData <= 16'h4000;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 6: Enable QMU Transmit Flow Control
			else if(step == 6) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h70;
					length <= 1;
					writeData <= 16'h01EE;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 7: Enable QMU Receive Frame Data Pointer Auto Increment
			else if(step == 7) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h86;
					length <= 1;
					writeData <= 16'h4000;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 8: Configure Receive Frame Threshold for 1 Frame
			else if(step == 8) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h9C;
					length <= 1;
					writeData <= 16'h0001;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 9: Enable QMU Receive Flow Control
			else if(step == 9) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h74;
					length <= 1;
					writeData <= 16'h74F2;//7CE0
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 10: Enable QMU Receive ICMP/UDP Lite Frame checksum verification
			else if(step == 10) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h76;
					length <= 1;
					writeData <= 16'h0016;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end			
//========================= step 11: Enable QMU Receive IP Header 2-Byte Offset
			else if(step == 11) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h82;
					length <= 1;
					writeData <= 16'h0030;//0230
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= 14;
					//step <= step + 1;
				end
			end	
//========================= step 12: Force Link in Half Duplex if Auto-Negotiation is Failed, Restart Port 1 Auto-Negotiation
//========================= (1) Read the Reg First
			else if(step == 12) begin
				if(state == Read2 || state == Write2) begin
					WR <= 0;
					offset <= 8'hF6;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 13: Force Link in Half Duplex if Auto-Negotiation is Failed, Restart Port 1 Auto-Negotiation
//========================= (2) Write Back the Reg
			else if(step == 13) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'hF6;
					length <= 1;
				end
				else if(state == Addr0) begin				
					//writeData <= (readData & ~(16'h0001 << 5)) | (16'h0001 << 13);
					//writeData <= 16'h20DF;
					writeData <= 16'h00FF;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end	
//========================= step 14: Clear the Interrupts Status
			else if(step == 14) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h92;
					length <= 1;
					writeData <= 16'hFFFF;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end	
//========================= step 15: Enable ... interrupts if your host processor can handle the interrupt, otherwise no need.
			else if(step == 15) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h90;
					length <= 1;
					writeData <= 16'h6000;//Transmit interrupt + receive interrupt
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 16: Enable QMU Transmit
//========================= (1) Read Reg
			else if(step == 16) begin
				if(state == Read2 || state == Write2) begin
					WR <= 0;
					offset <= 8'h70;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 17: Enable QMU Transmit
//========================= (2) Write Reg
			else if(step == 17) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h70;
					length <= 1;
				end
				else if(state == Addr0) begin
					//writeData <= readData | 16'h0001;
					writeData <= 16'h01EF;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 18: Enable QMU Receive
//========================= (1) Read Reg
			else if(step == 18) begin
				if(state == Read2 || state == Write2) begin
					WR <= 0;
					offset <= 8'h74;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 19: Enable QMU Receive
//========================= (2) Write Reg
			else if(step == 19) begin
				if(state == Read2 || state == Write2) begin
					WR <= 1;
					offset <= 8'h74;
					length <= 1;
				end
				else if(state == Addr0) begin
					//writeData <= readData | 16'h0001;
					writeData <= 16'h74F3;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;//1 For Verification Part
					step <= step + 1;
				end
			end
//************************* Verification Starts *****************************
			else if(step == 20) begin
				if(state == Read2 || state == Write2) begin
					WR <= 0;
					offset <= 8'hE4;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
			else if(step == 21) begin
				if(state == Read2 || state == Write2) begin
					WR <= 0;
					offset <= 8'hF6;
					length <= 1;
					writeData <= 16'bz;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 0;
					step <= step + 1;
				end
			end
//************************* Verification Ends *****************************
//******************************************************
			else if(step == 22) begin
				if(state == Read2 || state == Write2) begin
					initDone <= 1;
				end
			end
		end		
	end
	
//	wire[35:0] ILAControl;
//	Ethernet_icon icon(.CONTROL0(ILAControl));
//	Ethernet_ila ila(
//	    .CONTROL(ILAControl),
//		.CLK(sysclk),
//		.TRIG0(0),
//		.TRIG1(warmDone),
//		.TRIG2(0),
//		.TRIG3(reset),
//		.TRIG4(packetLen),
//		.TRIG5(writeData),
//		.TRIG6(readData),
//		.TRIG7(WR),
//		.TRIG8(NewCommand),
//		.TRIG9(offset),
//		.TRIG10(length),
//		.TRIG11(0),
//		.TRIG12(state),
//		.TRIG13(step[3:0]),
//		.TRIG14(0)
//	);
endmodule






