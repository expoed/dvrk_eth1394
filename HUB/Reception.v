/*******************************************************************************    
 *
 * Copyright(C) 2011-2014 ERC CISST, Johns Hopkins University.
 *
 * This is the reception module for ksz8851-16mll for the Ethernet-FPGA1394-QLA motor controller interface.
 * Multiple frame reception is not enabled.
 *
 *	Protocol of received Ethernet Packet from PC:
 *	- Destination Addr	:	6 bytes - "PC>HUB"
 *	- Source Addr		:	4 bytes	- "LCSR"
 *					 		2 bytes	- num_nodes + SPECIAL_SIGN + Firewire Frame Length
 *			num_nodes	:	4 bits, from 0~14 ( 1 node to 15 nodes )
 *		SPECIAL_SIGN	:	1 bit, indicating whether this frame is num_node synchronizing frame or normal frame
 *			  FW_LEN	:	11 bits, records the length of the firewire frame in the Ethernet packet
 *
 * Revision history
 *     08/14/14    Long Qian
 */

`timescale 1ns / 1ps
`include "Constants.v"
module Reception(
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
	output reg Dummy_Read,
	input[3:0] state,
	output reg[1:0] receiveStatus,	//00:Wait, 01:Recv, 10:Done
	// Hub RAM
	output reg[10:0] mem_addr,
	output reg mem_wen,
	output reg[31:0] mem_wdata,
	
	output reg PC_REQ_NEW,			// trigger: new PC_REQ
	output reg Node_Set,			// trigger: num_node set
	output reg[10:0] PC_REQ_LEN,	// length in byte
	input[5:0] StatusManager,
	output reg[3:0] num_node
    );

	// lower-level state machine, see regIO.v
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

	reg[4:0] step;				// step count of configuration
	reg[12:0] lengthInWord;		// packet length in 16-bit, align with double-word boundary
	reg[8:0] rxFrameCount;		// number of frame in RxQ (waiting to be read by top module)
	reg[11:0] rxPacketLength;	// packet length in 8-bit
	reg[15:0] controlWord, byteCount; // header before ETH frame not used actually
	wire[15:0] bSwapReadData;	// swap the readData for better readability
	assign bSwapReadData = {readData[7:0],readData[15:8]};
	reg[12:0] frameReadCount;	// count the number of word already read
	reg PC_REQ_Correct;			// temporal variable to indicate the PC_REQ is correct or not, by examing header
	reg[15:0] dataPart1;		// first 16-bit of 32-bit RAM data
	
	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			writeData <= 16'bz;
			NewCommand <= 0;
			receiveStatus <= 2'b10;	// default receive state: Done
			step <= 0;
			Dummy_Read <= 0;
			frameReadCount <= 0;
			PC_REQ_Correct <= 1;	// default: correct
			PC_REQ_NEW <= 0;
			Node_Set <= 0;
			PC_REQ_LEN <= 0;
			dataPart1 <= 0;
			num_node <= 0;
		end
		else begin
			if(receiveStatus == 2'b00) begin
				NewCommand <= 1;
				receiveStatus <= 2'b01;	// start receiving
				step <= 0;
			end
			else if(receiveStatus == 2'b01) begin
//========================= step 0: read ISR
				if(step == 0) begin
					if(state == Wait) begin
						WR <= 0;
						offset <= 8'h92;
						length <= 1;
						writeData <= 16'bz;							
					end
					else if(state == Read1) begin
						NewCommand <= 0;
						step <= 1;
					end
				end
//========================= step 1: check if RXIS "receive interrupt" is set		
				else if(step == 1) begin
					if(state == Wait) begin
						if(readData[13]) begin
							NewCommand <= 1;
							step <= step + 1;
						end
						else begin
							step <= 0;
							receiveStatus <= 2'b10;
							NewCommand <= 0;
							writeData <= 16'bz;
							PC_REQ_Correct <= 1;
							Dummy_Read <= 0;
						end
					end					
				end
//========================= step 2: disable all device interrupts generation
				else if(step == 2) begin
					if(state == Wait) begin
						WR <= 1;
						offset <= 8'h90;
						length <= 1;
						writeData <= 16'h0000;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;// Actually stay the same
						step <= step + 1;
					end
				end
//========================= step 3: ackowledge(clear) RXIS Receive Interrupt bit
				else if(step == 3) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h92;
						length <= 1;
						writeData <= readData | (16'h0001<<13);
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;// Actually stay the same
						step <= step + 1;
					end
				end
//========================= step 4: Read current total amount of received frame count from RXFCTR
				else if(step == 4) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
						offset <= 8'h9C;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 5: save value in rxFrameCount
				else if(step == 5) begin
					if(state == Wait) begin
						rxFrameCount <= readData[15:8];
						step <= step + 1;
					end
				end
//========================= step 6: check if there is a frame to read
				else if(step == 6) begin
					if(rxFrameCount > 0) begin
						step <= step + 1;
					end
					else begin
						step <= 24;
					end
				end
//========================= step 7: Read received frame status from RXFHSR
				else if(step == 7) begin
					if(state == Wait) begin
						NewCommand <= 1;
						WR <= 0;
						offset <= 8'h7C;
						length <= 1;
						writeData <= 16'hz;					
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 8: check if this is a good frame
				else if(step == 8) begin
					if(state == Wait) begin
						if(~readData[15]||(readData[0]&&readData[1]&&readData[2]&&readData[4]&&readData[10]&&readData[11]&&readData[12]&&readData[13]))
							step <= 11;	// With Error
						else
							step <= 9;	// Without Error
					end
				end
//========================= step 9: Read received frame byte size from RXFHBCR to get the frame length
				else if(step == 9) begin
					if(state == Wait) begin
						NewCommand <= 1;
						WR <= 0;
						offset <= 8'h7E;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 10: check if the length is more than 0
				else if(step == 10) begin
					if(state == Wait) begin
						rxPacketLength <= readData[11:0];
						if(readData[11:0] > 12'h000) begin
							step <= 13;
						end
						else
							step <= 11;
					end
				end
//========================= step 11: Issue the RELEASE error frame command for the QMU to release the current error frame from RXQ
//========================= (1) Read the register
				else if(step == 11) begin
					if(state == Wait) begin
						NewCommand <= 1;
						WR <= 0;
						offset <= 8'h82;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= 12;
					end
				end
//========================= step 12: Issue the RELEASE error frame command for the QMU to release the current error frame from RXQ
//========================= (2) Write the register
				else if(step == 12) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h82;
						length <= 1;
					end
					else if(state == Addr0) begin
						writeData <= readData | 16'h0001;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= 23;	// Back to the loop
					end
				end
//========================= step 13: Reset QMU RXQ frame pointer to zero
				else if(step == 13) begin
					if(state == Wait) begin
						NewCommand <= 1;
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
//========================= step 14: Start QMU DMA transfer operation to read frame data from the RXQ to the host CPU
//========================= (1) Read the register
				else if(step == 14) begin
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
//========================= step 15: Start QMU DMA transfer operation to read frame data from the RXQ to the host CPU
//========================= (2) Write the register
				else if(step == 15) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h82;
						length <= 1;
					end
					else if(state == Addr0) begin
						writeData <= readData | (16'h0001<<3);
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
						Dummy_Read <= 1;
					end
				end
//========================= step 16: Dummy read 2 byte for nothing
				else if(step == 16) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
						offset <= 8'h0;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 17: Read the status word
				else if(step == 17) begin
					if(state == Read2 || state == Write2) begin
						WR <= 0;
					end
					else if(state == Read1 || state == Write1) begin
						step <= step + 1;
					end
				end
//========================= step 18: Read the byte count
				else if(step == 18) begin
					if(state == Read2 || state == Write2) begin						
						WR <= 0;
					end
					else if(state == Read0) begin
						controlWord <= readData;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 19: Prepare lengthInWord
				else if(step == 19) begin
					if(state == Wait) begin
						byteCount <= readData;
						lengthInWord <= ((rxPacketLength + 3)& ~16'h0003)>>1;
						step <= step + 1;
						NewCommand <= 1;
						frameReadCount <= 0;
					end
				end
//========================= step 20: Read the frame
				else if(step == 20) begin
					if(Node_Set)
						Node_Set <= 0;
					if(state == Read0) begin
						if(lengthInWord > 0) begin
							lengthInWord <= lengthInWord - 1;
							frameReadCount <= frameReadCount + 1;
							if(frameReadCount == 0) begin // exclude the first input, it should be equal to byteCount
								PC_REQ_Correct <= 1;
							end
							else if(frameReadCount == 1) begin
								PC_REQ_Correct <= PC_REQ_Correct & (bSwapReadData == 16'h5043); // verify the Ethernet header
							end
							else if(frameReadCount == 2) begin
								PC_REQ_Correct <= PC_REQ_Correct & (bSwapReadData == 16'h3e48);
							end
							else if(frameReadCount == 3) begin
								PC_REQ_Correct <= PC_REQ_Correct & (bSwapReadData == 16'h5542);
							end
							else if(frameReadCount == 4) begin
								PC_REQ_Correct <= PC_REQ_Correct & (bSwapReadData == 16'h4C43);
							end
							else if(frameReadCount == 5) begin
								PC_REQ_Correct <= PC_REQ_Correct & (bSwapReadData == 16'h5352);
							end
							else if(frameReadCount == 6) begin // read the legnth of the FW frame
								PC_REQ_LEN <= bSwapReadData[10:0];
								if(bSwapReadData[11] == 1'b1) begin // It is a SPECIAL_SIGN
									num_node <= bSwapReadData[15:12]+1'b1;
									PC_REQ_Correct <= 1'b0;
									Node_Set <= 1;
								end
							end
							else if(frameReadCount == 7) begin // ethernet type: no use, prepare for RAM write
								mem_wen <= PC_REQ_Correct;
								mem_addr <= `ADDR_PC_REQ;
								mem_wdata <= 32'hz;
							end
							else if(frameReadCount == 8) begin
								dataPart1 <= bSwapReadData;
							end
							else if(frameReadCount == 9) begin
								mem_wdata <= {dataPart1, bSwapReadData};
							end
							else begin
								if(!frameReadCount[0]) begin
									dataPart1 <= bSwapReadData;
								end
								else begin
									mem_addr <= mem_addr + 1;
									mem_wdata <= {dataPart1, bSwapReadData};
								end
							end
						end
					end
					else if(state == Read1) begin
						if(lengthInWord == 0) begin
							NewCommand <= 1;
							Dummy_Read <= 0;
							step <= step + 1;
							mem_addr <= `ADDR_PC_REQ;
							mem_wen <= 0;
							mem_wdata <= 32'hz;
						end
					end
				end
//========================= step 21: Stop QMU DMA transfer operation
//========================= (1) Read the register
				else if(step == 21) begin
					if(state == Read2) begin
						PC_REQ_NEW <= 0;//to send a trigger to StatusManager
						WR <= 0;
						offset <= 8'h82;
						length <= 1;
						writeData <= 16'hz;
					end
//					else if(state == Addr0)
//						tempReadData <= {readData[7:0],readData[15:8]};//Read the last tempReadData
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 1;
						step <= step + 1;
					end
				end
//========================= step 22: Stop QMU DMA transfer operation
//========================= (2) Write the register
				else if(step == 22) begin
					if(state == Read2 || state == Write2) begin
						WR <= 1;
						offset <= 8'h82;
						length <= 11;
					end
					else if(state == Addr0) begin
						writeData <= readData & ~(16'h001<<3);
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 23: Finishing reading one frame, substract rxFrameCount by 1
				else if(step == 23) begin
					if(state == Wait) begin
						rxFrameCount <= rxFrameCount - 1;
						step <= 6;
					end
				end
//========================= step 24: Enable the device interrupts again
				else if(step == 24) begin
					if(state == Wait) begin
						NewCommand <= 1;
						WR <= 1;
						offset <= 8'h90;
						length <= 1;
						writeData <= 16'h6000; // only enable Rx + Tx interrupt
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 25: Exit
				else if(step == 25) begin
					if(state == Wait) begin
						if(PC_REQ_Correct & ~PC_REQ_NEW) begin // exclude num_node setting process
							PC_REQ_NEW <= 1; // send a trigger to StatusManager
						end
						else begin
							PC_REQ_NEW <= 0; // reset the trigger
							receiveStatus <= 2'b10;
						end
					end
				end
			end
			else if(receiveStatus == 2'b10) begin
				if(StatusManager[4:3] == 2'b10) begin // include PC_REQ_RECV process and num_node setting process
					receiveStatus <= 2'b00;
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
//		.TRIG0(PC_REQ_Correct),//1
//		.TRIG1(Dummy_Read),//1
//		.TRIG2(WR),//1
//		.TRIG3(NewCommand),//1
//		.TRIG4(receiveStatus),//4
//		.TRIG5(state),//4
//		.TRIG6(mem_wen),//4
//		.TRIG7(PC_REQ_NEW),//4
//		.TRIG8(step),//8
//		.TRIG9(PC_REQ_LEN[7:0]),//8
//		.TRIG10(frameReadCount[7:0]),//8
//		.TRIG11(lengthInWord[7:0]),//8
//		.TRIG12(writeData),//16
//		.TRIG13(readData),//16
//		.TRIG14(mem_addr),//32
//		.TRIG15(mem_wdata)//32
//	);

endmodule
