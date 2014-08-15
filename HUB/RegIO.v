/*******************************************************************************    
 *
 * Copyright(C) 2011-2014 ERC CISST, Johns Hopkins University.
 *
 * This is the registers driver module for ksz8851-16mll for the Ethernet-FPGA1394-QLA motor controller interface.
 *
 * Revision history
 *     08/14/14    Long Qian
 */

`timescale 1ns / 1ps

// --------------------------------------------------------------------------
// Register Address Translator: from 8-bit offset to 16-bit address required by ksz8851
// --------------------------------------------------------------------------
module getAddr(
	input wire[7:0] offset,		// offset provided by Init, Transmit or Receive
	input wire length,			// length: 0-byte(8-bit), 1-word(16-bit)
	output wire[15:0] Addr		// address recognized by ksz8851
	);
	
	// the rule of translation is available in the step-by-step guide of ksz8851-16mll
	wire[1:0] offsetTail;
	assign offsetTail = offset[1:0];
	
	assign Addr[12] = (offsetTail==0) ? 1:0;
	assign Addr[13] = ((~length && offsetTail==1) || (length && offsetTail==0)) ? 1:0;
	assign Addr[14] = (offsetTail==2) ? 1:0;
	assign Addr[15] = ((~length && offsetTail==3) || (length && offsetTail==2)) ? 1:0;	
	assign Addr[7:2] = offset[7:2];
	
	assign Addr[1:0] = offsetTail;	// not necessary, for better integrity
	assign Addr[11:8] = 4'h0;		// not necessary, for better integrity
	
endmodule


// --------------------------------------------------------------------------
// KSZ8851-16mll Register Read / Write Module
// --------------------------------------------------------------------------
module RegIO(
	// global clock and reset
	input sysclk,
	input reset,
	// parameters needed for Register IO
	output reg CMD,
	output reg RDN,
	output reg WRN,
	inout[15:0] SD,
	input WR,
	input[7:0] offset,
	input length,			// length: 0-byte(8-bit), 1-word(16-bit)
	input[15:0] writeData,
	output reg[15:0] readData,
	
	input NewCommand,		// if there is a new command following
	input Dummy_Write,		// used in ETH packet writing, writing without address
	input Dummy_Read,		// used in ETH packet reading, reading without address
	output reg[3:0] state	// tell the upper layer what state is this module in
    );
	
	
	// Address translator
	wire[15:0] Addr;
	getAddr newAddr(
		.offset(offset),
		.length(length),
		.Addr(Addr)
	);
	
	// state machine definition
	localparam [3:0] Addr0 = 4'b0000,		// write read/write address
					 Addr1 = 4'b0001,		// wait one cycle, keep the address stable
					 Addr2 = 4'b0010,		// pull up WRN and switch to Read0 or Write0
					 Read0 = 4'b0011,		// pull down RDN
					 Read1 = 4'b0100,		// wait for SD output to be ready
					 Read2 = 4'b0101,		// fetch data and pull up the RDN
					 Write0 = 4'b0110,		// pull down WRN write data into SD
					 Write1 = 4'b0111,		// wait for SD line to be stable
					 Write2 = 4'b1000,		// pull up the WRN signal
					 Wait = 4'b1001,		// idle state, waiting for new command
					 Readmore = 4'b1010,	// added for 1394 clock
					 Writemore = 4'b1011;	// added for 1394 clock
	
	// tri-state bus configuration
	reg [15:0] SDReg;
	assign SD = RDN ? SDReg:16'hz;
	

	// state machine switch
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			state <= Wait;
		end
		else begin
			case(state)
				// write read/write address
				Addr0:
					begin
						CMD <= 1;
						WRN <= 0;
						SDReg <= Addr;
						state <= Addr1;
					end
				// wait one cycle, keep the address stable
				Addr1:
					begin
						state <= Addr2;
					end
				// pull up WRN and switch to Read0 or Write0
				Addr2:
					begin
						WRN <= 1;
						state <= WR ? Write0:Read0;
					end
				// pull down RDN, wait for SD output
				Read0:
					begin
						SDReg <= 16'hz;
						CMD <= 0;
						RDN <= 0;
						state <= Read1;
					end
				// wait for SD output to be ready
				Read1:
					begin
						state <= Readmore;
					end
				// additional cycle for 1394 clock (49.152 MHz)
				// not needed in case of 40MHz clock
				Readmore:
					begin
						state <= Read2;
					end
				// fetch data and pull up the RDN
				Read2:
					begin
						readData <= SD;
						RDN <= 1;
						if(NewCommand) begin
							if(Dummy_Write)	// if Dummy_Read, ignore ADDRX states
								state <= Write0;
							else if(Dummy_Read)
								state <= Read0;
							else
								state <= Addr0;
						end
						else
							state <= Wait;
					end
				// pull down WRN write data into SD
				Write0:
					begin
						SDReg <= writeData;
						CMD <= 0;
						WRN <= 0;
						state <= Write1;
					end
				// wait for SD line to be stable
				Write1:
					begin
						state <= Writemore;
					end
				// additional cycle for 1394 clock (49.152 MHz)
				// not needed in case of 40MHz clock				
				Writemore:
					begin
						state <= Write2;
					end
				// pull up the WRN signal
				Write2:
					begin
						WRN <= 1;
						if(NewCommand) begin
							if(Dummy_Write)	// if Dummy_Write, ignore ADDRX states
								state <= Write0;
							else if(Dummy_Read)
								state <= Read0;
							else
								state <= Addr0;
						end
						else
							state <= Wait;
					end
				// idle state, waiting for new command
				Wait:
					begin
						if(NewCommand) begin
							if(Dummy_Write)
								state <= Write0;
							else if(Dummy_Read)
								state <= Read0;
							else
								state <= Addr0;
						end
						else
							state <= Wait;
						CMD <= 1;
						RDN <= 1;
						WRN <= 1;
						SDReg <= 16'bz;
					end
			endcase
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
//		.TRIG0(CMD),//1
//		.TRIG1(WRN),//1
//		.TRIG2(RDN),//1
//		.TRIG3(NewCommand),//1
//		.TRIG4(WR),//4
//		.TRIG5(Dummy_Read),//4
//		.TRIG6(Dummy_Write),//4
//		.TRIG7(state),//4
//		.TRIG8(offset),//8
//		.TRIG9(0),//8
//		.TRIG10(0),//8
//		.TRIG11(0),//8
//		.TRIG12(writeData),//16
//		.TRIG13(readData),//16
//		.TRIG14(SD),//32
//		.TRIG15(SDReg)//32
//	);


endmodule
