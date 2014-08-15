/*******************************************************************************    
 *
 * Copyright(C) 2011-2014 ERC CISST, Johns Hopkins University.
 *
 * This is the initialization module for ksz8851-16mll for the Ethernet-FPGA1394-QLA motor controller interface.
 * Note that 0.05s is needed to warm up the device before any IO operation.
 *
 * Revision history
 *     08/14/14    Long Qian
 */
 
`timescale 1ns / 1ps
module Initialization(
	// global clock and reset
	input sysclk,
	input reset,
	// parameters for register IO
	output reg[7:0] offset,
	output reg length,
	output reg WR,
	output reg[15:0] writeData,
	input[15:0] readData,
	output reg NewCommand,
	input[3:0] state,
	// trigger
	output reg Init_Done
	);
	
	reg warmDone;			// record if warmimg-up is done or not
	reg[20:0] warmCount;	// 0.0524s is needed to warm up
	reg[4:0] step;			// steps needed to warm up
	wire negInit_Done;
	// very important! to avoid error of top module MUX caused by intermediate ~Init_Done	
	assign negInit_Done = ~Init_Done;
	
	// state machine of lower level register operation
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
	
	// step by step configuration
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			warmCount <= 0;
			warmDone <= 0;
			step <= 0;			// start from step 0
			Init_Done <= 0;		// clear the trigger
			writeData <= 16'bz;	// set writeData to be high-impedance
			NewCommand <= 0;
		end
		else if(!warmDone) begin
			warmCount <= warmCount + 1;
			if(warmCount == 21'h1FFFFF) begin
				warmDone <= 1;
			end
		end
		else if(warmDone && negInit_Done) begin
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
				if(readData == 16'h887x) begin
					NewCommand <= 1;
					step <= step + 1;
				end
			end
//========================= step 2: Write QMU MAC address(low): 0x89AB
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
//========================= step 3: Write QMU MAC address(medium): 0x4567
			else if(step == 3) begin
				if(state == Read2 || state == Write2) begin
				// Note: here, the lower-module state machine is still in the Read2|Write2 state,
				//		which, theoritical belongs to last step. Adavancing the "step" count is 
				//		for the sake of saving time. (Preload some parameters so that Wait state
				//		is not needed for continuous register operation.)
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
//========================= step 4: Write QMU MAC address(high): 0x0123
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
					writeData <= 16'h74F2;	// 0x7CE0 recommended by guide
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
					writeData <= 16'h0030;	// 0x0230 recommended by guide
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 1;
					step <= step + 1;
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
					writeData <= (readData & ~(16'h0001 << 5)) | (16'h0001 << 13);
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
					writeData <= 16'h6000;	// only transmit interrupt + receive interrupt
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
					writeData <= readData | 16'h0001;
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
					writeData <= readData | 16'h0001;
				end
				else if(state == Read1 || state == Write1) begin
					NewCommand <= 0;// 1 for Verification Part
					step <= 24;
				end
			end
//************************* Verification Starts *****************************
//			else if(step == 20) begin
//				if(state == Read2 || state == Write2) begin
//					WR <= 0;
//					offset <= 8'h9C;
//					length <= 1;
//					writeData <= 16'bz;
//				end
//				else if(state == Read1 || state == Write1) begin
//					NewCommand <= 1;
//					step <= step + 1;
//				end
//			end
//			else if(step == 21) begin
//				if(state == Read2 || state == Write2) begin
//					WR <= 0;
//					offset <= 8'h10;
//					length <= 1;
//					writeData <= 16'bz;
//				end
//				else if(state == Read1 || state == Write1) begin
//					NewCommand <= 1;
//					step <= step + 1;
//				end
//			end
//			else if(step == 22) begin
//				if(state == Read2 || state == Write2) begin
//					WR <= 0;
//					offset <= 8'h12;
//					length <= 1;
//					writeData <= 16'bz;
//				end
//				else if(state == Read1 || state == Write1) begin
//					NewCommand <= 1;
//					step <= step + 1;
//				end
//			end
//			else if(step == 23) begin
//				if(state == Read2 || state == Write2) begin
//					WR <= 0;
//					offset <= 8'h14;
//					length <= 1;
//					writeData <= 16'bz;
//				end
//				else if(state == Read1 || state == Write1) begin
//					NewCommand <= 0;
//					step <= step + 1;
//				end
//			end
//************************* Verification Ends *****************************
//******************************************************
			else if(step == 24) begin
				if(state == Read2 || state == Write2) begin
					Init_Done <= 1;		// step up the trigger
				end
			end
		end		
	end

//Chipscope
//	wire[35:0] ctrl;
//	Hub_icon ICON(
//		.CONTROL0(ctrl)
//	);
//	HUB_ila ILA(
//		.CONTROL(ctrl),
//		.CLK(sysclk),
//		.TRIG0(warmDone),//1
//		.TRIG1(Init_Done),//1
//		.TRIG2(WR),//1
//		.TRIG3(NewCommand),//1
//		.TRIG4(state),//4
//		.TRIG5(0),//4
//		.TRIG6(0),//4
//		.TRIG7(0),//4
//		.TRIG8(step),//8
//		.TRIG9(offset),//8
//		.TRIG10(0),//8
//		.TRIG11(0),//8
//		.TRIG12(writeData),//16
//		.TRIG13(readData),//16
//		.TRIG14(0),//32
//		.TRIG15(0)//32
//	);



endmodule






