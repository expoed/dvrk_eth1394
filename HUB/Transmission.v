/*******************************************************************************    
 *
 * Copyright(C) 2011-2014 ERC CISST, Johns Hopkins University.
 *
 * This is the initialization module for ksz8851-16mll for the Ethernet-FPGA1394-QLA motor controller interface.
 * There are two types of data needed to be transmitted back to PC: 1, response to PC request; 2, Broadcast Data
 *
 * Revision history
 *     08/14/14    Long Qian
 */
 

`timescale 1ns / 1ps
`include "Constants.v"

module Transmission_Normal(
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
	output reg Dummy_Write,
	
	input[3:0] state,				// lower-level state machine
	output reg[1:0] transmitStatus,	// 00: Wait, 01: Trans, 10: Done
	// Hub RAM
	output reg[10:0] mem_addr,		// RAM address
	input[31:0] mem_rdata,			// RAM read data
	
	input wire[5:0] StatusManager,	// Upper-level procedure status
	input wire[10:0] RESP_DATA_LEN,	// length of response data in RAM (TX BC data to PC)
	output reg Trans_Done,			// trigger: transmission done
	input[3:0] num_node				// number of nodes in this network: 1-16
	);
	
	// lower-level state machine
	localparam [3:0] Addr0 = 4'b0000,
					 Addr1 = 4'b0001,
					 Addr2 = 4'b0010,
					 Read0 = 4'b0011,
					 Read1 = 4'b0100,
					 Read2 = 4'b0101,
					 Write0 = 4'b0110,
					 Write1 = 4'b0111,
					 Write2 = 4'b1000,
					 Wait = 4'b1001;

	reg[4:0] step;						// step count for configuration
	reg[12:0] lengthInWord, countDown;	// counting word for transmitting
	wire transType;						// 0: Broadcast data, 1: RESP to PC_REQ
	assign transType = StatusManager[4];
	wire[15:0] dataPart1, dataPart2;	// pick 16-bit data from 32-bit RAM
	
	// swap the data so that the datastream(in byte) received by PC is correct
	assign dataPart1 = {mem_rdata[23:16],mem_rdata[31:24]};
	assign dataPart2 = {mem_rdata[7:0],mem_rdata[15:8]};
	reg[12:0] packetLen;//FW frame length in byte
	
	// transmission process and configurations
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			writeData <= 16'bz;
			NewCommand <= 0;
			transmitStatus <= 2'b10;	// default state of TX is Done
			step <= 0;
			Dummy_Write <= 0;
			mem_addr <= `ADDR_DEFAULT;	// default RAM address
			Trans_Done <= 0;			// reset the trigger
		end
		else begin
			if(transmitStatus == 2'b00) begin
				NewCommand <= 1;
				transmitStatus <= 2'b01;
				step <= 0;
				// length of packet is dependent on the type of packet: PC_RESP or BC_RESP
				// Note that the packetLen is the length of data only (header and tail not included)
				// for PC_RESP, the length is recorded as RESP_DATA_LEN
				// for BC_RESP, the length is the size of BC packet times the number of nodes
				packetLen <= transType ? {2'b00, RESP_DATA_LEN} : (`SZ_BC_RECEIVE << 2)*num_node;
			end
			else if(transmitStatus == 2'b01) begin
//========================= step 0: read QMU TXQ available memory
				if(step == 0) begin
					if(state == Wait) begin
						WR <= 0;
						offset <= 8'h78;
						length <= 1;
						writeData <= 16'bz;
					end
					else if(state == Read1) begin 
					// Strange: if replaced by "state == Read1 || state == Write1", it's wrong
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 1: check if QMU TXQ memory >= packetLen + 4
				else if(step == 1) begin
					if(state == Wait) begin
						if(readData[12:0] >= packetLen + 14 + 4) begin
							NewCommand <= 1;
							step <= step + 1;
						end
						else begin// No enough memory, back to the reset state;
							step <= 0;
							transmitStatus <= 2'b00;
							NewCommand <= 0;
							writeData <= 16'bz;
							Dummy_Write <= 0;
						end
					end
				end
//========================= step 2: disable all the device interrupts generation
				else if(step == 2) begin
					if(state == Wait) begin
						WR <= 1;
						offset <= 8'h90;
						length <= 1;
						writeData <= 16'h0000;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 3: Start QMU DMA tranfer operation to write frame data from host CPU to TxQ
//========================= (1) Read the Reg First
				else if(step == 3) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
						offset <= 8'h82;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 4: Start QMU DMA tranfer operation to write frame data from host CPU to TxQ
//========================= (2) Write Back the Reg
				else if(step == 4) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h82;
						length <= 1;
					end
					else if(state == Addr0) begin				
						writeData <= readData | (16'h0001 << 3);
					end
					else if(state == Read1 || state == Write1) begin						
						NewCommand <= 1;
						step <= step + 1;
						Dummy_Write <= 1;
					end
				end
//========================= step 5: Write TXIC to the "control word" of the frame header through dummy address
				else if(step == 5) begin
					if(state == Write2)//actaully belong to the previous step(to load the word ahead)
						writeData <= 16'h8000;
					else if(state == Write1)
						step <= step + 1;
				end
//========================= step 6; Write packetLen to the "byte count" of the frame header through dummy address				
				else if(step == 6) begin
					if(state == Write2)
						writeData <= {3'b000, packetLen + 14};
					else if(state == Write1) begin
						step <= step + 1;
						lengthInWord <= ((packetLen + 14 + 3)& ~16'h0003)>>1;
						countDown <= ((packetLen + 14 + 3)& ~16'h0003)>>1;//The same with lengthInWord
					end
				end
//========================= step 7: Transmitting: Writing Data
//Data Frame(from the PC side):
//	Destination MAC + Source MAC + length + Data
//			6		+	  6		 +	  2(bytes)
				else if(step == 7) begin
					if(state == Write2) begin
						// Destination MAC: "HUB>PC"
						if(countDown == lengthInWord)
							writeData <= 16'h5548;
						else if(countDown == lengthInWord - 4'h1)
							writeData <= 16'h3e42;
						else if(countDown == lengthInWord - 4'h2)
							writeData <= 16'h4350;
						// Source MAC: "LCSR" + FW packet length
						else if(countDown == lengthInWord - 4'h3)
							writeData <= 16'h434c;
						else if(countDown == lengthInWord - 4'h4)
							writeData <= 16'h5253;
						else if(countDown == lengthInWord - 4'h5)
							writeData <= {packetLen[7:0],transType,2'b00,packetLen[12:8]};
						// Ethertype: 0x0801
						else if(countDown == lengthInWord - 4'h6) begin
							writeData <= 16'h0108;
							mem_addr <= transType ? `ADDR_RESP_DATA:`ADDR_BC_RECEIVE;
						end
						// Data
						else begin//start from countDown == lengthInWord -7, it is odd
							writeData <= countDown[0] ? dataPart1:dataPart2;
							mem_addr <= countDown[0] ? mem_addr:mem_addr + 1;
						end
						countDown <= countDown - 1;
					end
					else if(state == Write1) begin
						if(countDown == 0) begin
							step <= step + 1;
							Dummy_Write <= 0;
							NewCommand <= 1;
						end
					end
				end
//========================= step 8: Stop QMU DMA transfer operation
//========================= (1) Read the Reg First
				else if(step == 8) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
						offset <= 8'h82;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 9: Stop QMU DMA transfer operation
//========================= (2) Write Back the Reg
				else if(step == 9) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h82;
						length <= 1;
					end
					else if(state == Addr0) begin				
						writeData <= readData & ~(16'h0001 << 3);
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 10: TxQ Manual-Enqueue
//========================= (1) Read the Reg First
				else if(step == 10) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
						offset <= 8'h80;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 11: TxQ Manual-Enqueue
//========================= (2) Write Back the Reg
				else if(step == 11) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h80;
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
//========================= step 12: Enable device interrupts again
				else if(step == 12) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h90;
						length <= 1;
						writeData <= 16'h6000;//Rx + Tx interrupt
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 13: Exit
				else if(step == 13) begin
					if(state == Wait) begin
						if(!Trans_Done) begin
							Trans_Done <= 1;// send a trigger to StatusManager
						end
						else begin
							transmitStatus <= 2'b10;// set transmitStatus 00 to loop, 10 to stop
							Trans_Done <= 0;
						end
					end
				end
			end
			else if(transmitStatus == 2'b10) begin
				if(StatusManager[3] == 1'b1) begin
					transmitStatus <= 2'b00;	// to start a transmission task again
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
//		.TRIG0(Trans_Done),//1
//		.TRIG1(WR),//1
//		.TRIG2(NewCommand),//1
//		.TRIG3(transType),//1
//		.TRIG4(transmitStatus),//4
//		.TRIG5(0),//4
//		.TRIG6(0),//4
//		.TRIG7(stateReg),//4
//		.TRIG8(StatusManager),//8
//		.TRIG9(step),//8
//		.TRIG10(countDown),//8
//		.TRIG11(RESP_DATA_LEN),//8
//		.TRIG12(writeData),//16
//		.TRIG13(readData),//16
//		.TRIG14(mem_addr),//32
//		.TRIG15(mem_rdata)//32
//	);

endmodule
