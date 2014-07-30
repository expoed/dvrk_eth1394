`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:24:54 07/28/2014 
// Design Name: 
// Module Name:    Reception 
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
module Reception(
	input clk40m,
	input reset,
	output reg[7:0] offset,
	output reg length,
	output reg WR,
	output reg[15:0] writeData,
	input[15:0] readData,
	output reg NewCommand,
	output reg Dummy_Read,
	input[3:0] state,
	input recvEn,
	output reg[1:0] receiveStatus//00:Wait, 01:Recv, 10:Done
    );

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

	reg[4:0] step;
	reg[12:0] lengthInWord;
	reg[8:0] rxFrameCount;
	reg[11:0] rxPacketLength;
	reg[15:0] controlWord, byteCount, tempReadData;
	
	
	always @(posedge clk40m or negedge reset) begin
		if(!reset) begin
			writeData <= 16'bz;
			NewCommand <= 0;
			receiveStatus <= 2'b00;//Waiting
			step <= 0;
			Dummy_Read <= 0;
		end
		else if(recvEn) begin
			if(receiveStatus == 2'b00) begin//still waiting
				NewCommand <= 1;
				receiveStatus <= 2'b01;
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
//************************* Testing Starts *****************************
//				else if(step == 26) begin
//					if(state == Read2) begin
//						WR <= 0;
//						offset <= 8'h74;
//						length <= 1;
//						writeData <= 16'bz;							
//					end
//					else if(state == Read1) begin
//						NewCommand <= 1;
//						step <= 27;
//					end
//				end				
//				else if(step == 27) begin
//					if(state == Read2) begin
//						WR <= 0;
//						offset <= 8'h76;
//						length <= 1;
//						writeData <= 16'bz;
//					end
//					else if(state == Read1) begin
//						NewCommand <= 0;
//						step <= 1;
//					end
//				end
//************************* Testing Ends *****************************
//========================= step 1: check if RXIS "receive interrupt" is set		
				else if(step == 1) begin
					if(state == Wait) begin
						if(readData[13]) begin
							NewCommand <= 1;
							step <= step + 1;
						end
						else begin//No enough memory, back to the reset state;
							step <= 0;
							receiveStatus <= 2'b00;
							NewCommand <= 0;
							writeData <= 16'bz;
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
						NewCommand <= 1;//Actually stay the same
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
						NewCommand <= 1;//Actually stay the same
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
							step <= 11;//With Error
						else
							step <= 9;//Without Error
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
						step <= 23;//Back to the loop
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
					end
				end
//========================= step 20: Read the frame
				else if(step == 20) begin
					if(state == Read0) begin
						if(lengthInWord > 0) begin
							tempReadData <= readData;//Ignore the first tempReadData, it should be equal to byteCount
							lengthInWord <= lengthInWord - 1;
						end
					end
					else if(state == Read1) begin
						if(lengthInWord == 0) begin
							NewCommand <= 1;
							Dummy_Read <= 0;
							step <= step + 1;						
						end
					end
				end
//========================= step 21: Stop QMU DMA transfer operation
//========================= (1) Read the register
				else if(step == 21) begin
					if(state == Read2) begin
						WR <= 0;
						offset <= 8'h82;
						length <= 1;
						writeData <= 16'hz;
					end
					else if(state == Addr0)
						tempReadData <= readData;//Read the last tempReadData
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
						writeData <= 16'hEB00;
					end
					else if(state == Read1 || state == Write1) begin
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 25: Exit
				else if(step == 25) begin
					if(state == Wait) begin
						receiveStatus <= 2'b00;
					end
				end
			end
		end
	end
	
	
//	wire[35:0] ILAControl;
//	Ethernet_icon icon(.CONTROL0(ILAControl));
//	Ethernet_ila ila(
//	    .CONTROL(ILAControl),
//		.CLK(clk40m),
//		.TRIG0(recvEn),//1
//		.TRIG1(reset),//1
//		.TRIG2(WR),//1
//		.TRIG3(NewCommand),//1
//		.TRIG4(offset),//16
//		.TRIG5(writeData),//16
//		.TRIG6(readData),//16
//		.TRIG7(Dummy_Read),//1
//		.TRIG8(0),//1
//		.TRIG9(rxFrameCount),//16
//		.TRIG10(0),//1
//		.TRIG11(receiveStatus),//16
//		.TRIG12(state),//4
//		.TRIG13(step[4:1]),//4
//		.TRIG14(step[0])//1
//	);
endmodule
