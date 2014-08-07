`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:20:18 07/25/2014 
// Design Name: 
// Module Name:    Transmission 
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
module Transmission(
	input clk40m,
	input reset,
	input[12:0] packetLen,//packet length in byte
	output reg[7:0] offset,
	output reg length,
	output reg WR,
	output reg[15:0] writeData,
	input[15:0] readData,
	output reg NewCommand,
	output reg Dummy_Write,
	input[3:0] state,
	input transEn,
	output reg[1:0] transmitStatus,//00: Wait, 01: Trans, 10: Done
    input [3:0] wenid
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
	reg[12:0] lengthInWord, countDown;
	reg[3:0] prevWenid;//record the previous wenid
	reg[19:0] wenidCount;//Like debounce
	
	always @(posedge clk40m or negedge reset) begin
		if(!reset) begin
			writeData <= 16'bz;
			NewCommand <= 0;
			transmitStatus <= 2'b10;
			step <= 0;
			Dummy_Write <= 0;
		end
		else if(transEn) begin
			if(transmitStatus == 2'b00) begin//still waiting
				NewCommand <= 1;
				transmitStatus <= 2'b01;
				step <= 0;
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
					else if(state == Read1) begin//Strange: if I write "state == Read1 || state == Write1", it's wrong
						NewCommand <= 0;
						step <= step + 1;
					end
				end
//========================= step 1: check if QMU TXQ memory >= packetLen + 4
				else if(step == 1) begin
					if(state == Wait) begin
						if(readData[12:0] >= packetLen + 4) begin
							NewCommand <= 1;
							step <= step + 1;
						end
						else begin//No enough memory, back to the reset state;
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
						writeData <= {3'b000, packetLen};
					else if(state == Write1) begin
						step <= step + 1;
						lengthInWord <= ((packetLen + 3)& ~16'h0003)>>1;
						countDown <= ((packetLen + 3)& ~16'h0003)>>1;//The same with lengthInWord
					end
				end
//========================= step 7: Transmitting: Writing Data
//Data Frame(from the PC side):
//	Destination MAC + Source MAC + length + Data
//			6		+	  6		 +	  2(bytes)
				else if(step == 7) begin
					if(state == Write2) begin
						//Destination MAC
						if(countDown == lengthInWord)
							writeData <= 16'h1234;
						else if(countDown == lengthInWord - 4'h1)
							writeData <= 16'h5678;
						else if(countDown == lengthInWord - 4'h2)
							writeData <= 16'h9ABC;
						//Source MAC
						else if(countDown == lengthInWord - 4'h3)
							writeData <= 16'h2301;
						else if(countDown == lengthInWord - 4'h4)
							writeData <= 16'h6745;
						else if(countDown == lengthInWord - 4'h5)
							writeData <= 16'hAB89;
						//Length
						else if(countDown == lengthInWord - 4'h6)
							writeData <= {packetLen[7:0],3'b000,packetLen[12:8]};
						//Data
						else if(countDown == lengthInWord - 4'h7)
							writeData <= 16'h4820;
						else if(countDown == lengthInWord - 4'h8)
							writeData <= 16'h6c65;
						else if(countDown == lengthInWord - 4'h9)
							writeData <= 16'h6f6c;
						else if(countDown == lengthInWord - 4'hA)
							writeData <= 16'h5720;
						else if(countDown == lengthInWord - 4'hB)
							writeData <= 16'h726f;
						else if(countDown == lengthInWord - 4'hC)
							writeData <= 16'h646c;
						else if(countDown == lengthInWord - 4'hD)
							writeData <= 16'h2021;
						//The last data transmitted
						else if(countDown == 1)
							writeData <= 16'h0256;
						else
							writeData <= {countDown[7:0],countDown[7:0]};
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
						transmitStatus <= 2'b10;//set transmitStatus 00 to loop, 10 to stop
					end
				end
			end
			else if(transmitStatus == 2'b10) begin
				wenidCount <= wenidCount + 1;
				if(wenidCount == 0) begin
					prevWenid <= wenid;
					if(prevWenid != wenid) begin
						transmitStatus <= 2'b00;
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
//		.TRIG0(0),
//		.TRIG1(transEn),
//		.TRIG2(0),
//		.TRIG3(reset),
//		.TRIG4(packetLen),
//		.TRIG5(writeData),
//		.TRIG6(readData),
//		.TRIG7(WR),
//		.TRIG8(NewCommand),
//		.TRIG9(offset),
//		.TRIG10(length),
//		.TRIG11(transmitStatus),
//		.TRIG12(state),
//		.TRIG13(step[3:0]),
//		.TRIG14(Dummy_Write)
//	);

endmodule
