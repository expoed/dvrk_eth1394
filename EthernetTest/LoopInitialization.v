`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:02:24 07/25/2014 
// Design Name: 
// Module Name:    LoopInitialization 
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
module InitializationLoop(
	input clk40m,
	input reset,
	output reg CMD,
	output reg RDN,
	output reg WRN,
	input [15:0] SD,
	output reg [15:0] SDReg,
	output reg initDone
    );
	
	reg warmDone;
	reg[20:0] warmCount;//0.0524s is needed to warm up

	reg[15:0] outData;
	reg[4:0] step;
	reg[2:0] stage;//Each step involves 6 stages
	wire negDone;
	assign negDone = ~initDone;//very important! to avoid error of top module MUX caused by intermediate ~initDone
	
	always @(posedge clk40m or negedge reset) begin
		if(!reset) begin
			warmCount <= 0;
			warmDone <= 0;
			step <= 0;
			stage <= 0;
			CMD <= 1;
			WRN <= 1;
			RDN <= 1;
			SDReg <= 16'hz;
			outData <= 16'hFFFF;
			initDone <= 0;
		end
		else if(!warmDone) begin
			warmCount <= warmCount + 1;
			if(warmCount == 21'h1FFFFF) begin
				warmDone <= 1;
			end
		end
		else if(warmDone && negDone) begin
//========================= step 0: read device chip ID 
			if(step == 0) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h30C0;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 1: verify device chip ID
			else if(step == 1) begin
				if(outData == 16'h887x) begin
					step <= step + 1;
				end
			end
//========================= step 2: Write QMU MAC address(low)
			else if(step == 2) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3010;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h89AB;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 3: Write QMU MAC address(medium)
			else if(step == 3) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC012;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h4567;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 4: Write QMU MAC address(high)
			else if(step == 4) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3014;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h0123;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 5: Enable QMU Transmit Flow Control
			else if(step == 5) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3070;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h01EE;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 6: Enable QMU Receive Frame Data Pointer Auto Increment
			else if(step == 6) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC086;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h4000;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 7: Configure Receive Frame Threshold for 1 Frame
			else if(step == 7) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h309C;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h0001;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 8: Enable QMU Receive Flow Control
			else if(step == 8) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3074;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h7CE0;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 9: Enable QMU Receive ICMP/UDP Lite Frame checksum verification
			else if(step == 9) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC076;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h0016;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end			
//========================= step 10: Enable QMU Receive IP Header 2-Byte Offset
			else if(step == 10) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC082;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'h0230;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 11: Force Link in Half Duplex if Auto-Negotiation is Failed, Restart Port 1 Auto-Negotiation
//========================= (1) Read the Reg First
			else if(step == 11) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC0F6;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 12: Force Link in Half Duplex if Auto-Negotiation is Failed, Restart Port 1 Auto-Negotiation
//========================= (2) Write Back the Reg
			else if(step == 12) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC0F6;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= (outData & ~(16'h0001 << 5)) | (16'h0001 << 13);
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 13: Clear the Interrupts Status
			else if(step == 13) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'hC092;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hFFFF;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 14: Enable ... interrupts if your host processor can handle the interrupt, otherwise no need.
			else if(step == 14) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3090;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hEB00;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 15: Enable QMU Transmit
//========================= (1) Read Reg
			else if(step == 15) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3070;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 16: Enable QMU Transmit
//========================= (2) Write Reg
			else if(step == 16) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3070;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= outData | 16'h0001;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 17: Enable QMU Receive
//========================= (1) Read Reg
			else if(step == 17) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3074;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//========================= step 18: Enable QMU Receive
//========================= (2) Write Reg
			else if(step == 18) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3074;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= outData | 16'h0001;
							CMD <= 0;
							WRN <= 0;
						end
					5:
						begin
							WRN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//********************************* For Verification **********************************//
			else if(step == 19) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3070;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
			else if(step == 20) begin
				case(stage)
					0:
						begin
							CMD <= 1;
							WRN <= 0;
							SDReg <= 16'h3074;
						end
					2:
						begin
							WRN <= 1;
						end
					3:
						begin
							SDReg <= 16'hz;
							CMD <= 0;
							RDN <= 0;
						end
					5:
						begin
							outData <= SD;
							RDN <= 1;
						end
				endcase
				if(stage == 5) begin
					stage <= 0;
					step <= step + 1;
				end
				else
					stage <= stage + 1;
			end
//********************************* Verification Ends **********************************//
			else if(step == 21) begin
				initDone <= 1;
			end
		end
	end
endmodule


