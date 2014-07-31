`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:03:22 07/17/2014 
// Design Name: 
// Module Name:    EthernetTest 
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
module EthernetTest(
	input wire clk40m,
	output wire CSN,
	input wire RSTN,
	input wire PME,
	output wire CMD,
	input wire INTRN,
	output wire RDN,
	output wire WRN,
	inout [15:0] SD,
	output wire LED,
	input[3:0] wenid
    );
	
	reg sigLed,lled;
	always @(posedge clk40m) begin
		sigLed <= INTRN;
		if(sigLed && ~INTRN) begin
			lled <= ~lled;
		end
	end

	assign LED = lled;
	assign CSN = 0;//Always select
	reg[12:0] packetLen;

//============================= Register Module =============================	
	wire[3:0] stateReg;
	wire[15:0] readData, writeData;
	wire[7:0] offset;
	RegIO IOWR(
		.clk40m(clk40m),
		.reset(RSTN),
		.CMD(CMD),
		.RDN(RDN),
		.WRN(WRN),
		.SD(SD),
		.WR(WR),
		.offset(offset),
		.length(length),//length=0:byte, length=1:word
		.writeData(writeData),
		.readData(readData),
		.NewCommand(NewCommand),//to be continued to not
		.Dummy_Write(Dummy_Write),
		.Dummy_Read(Dummy_Read),
		.state(stateReg)
    );

//============================= Initialization Module =============================	
	wire initlength, initWR, initNewCommand, initDone;	
	wire[7:0] initoffset;
	wire[15:0] initwriteData; 
	Initialization Init(
		.clk40m(clk40m),
		.reset(RSTN),
		.offset(initoffset),
		.length(initlength),
		.WR(initWR),
		.writeData(initwriteData),
		.readData(readData),
		.NewCommand(initNewCommand),
		.state(stateReg),
		.initDone(initDone)
	);

//============================= Transmission Module =============================	
	reg transEn = 0;	
	wire translength, transWR, transNewCommand;
	wire[1:0] transmitStatus;
	wire[7:0] transoffset;
	wire[15:0] transwriteData;	
	Transmission Trans(
		.clk40m(clk40m),
		.reset(RSTN),
		.packetLen(packetLen),
		.offset(transoffset),
		.length(translength),
		.WR(transWR),
		.writeData(transwriteData),
		.readData(readData),
		.NewCommand(transNewCommand),
		.Dummy_Write(Dummy_Write),
		.state(stateReg),
		.transEn(transEn),
		.transmitStatus(transmitStatus),
		.wenid(wenid)
	);
	
//============================= Reception Module =============================
	reg recvEn = 0;
	wire recvlength, recvWR, recvNewCommand;
	wire[1:0] receiveStatus;
	wire[7:0] recvoffset;
	wire[15:0] recvwriteData;
	Reception Recv(
		.clk40m(clk40m),
		.reset(RSTN),
		.offset(recvoffset),
		.length(recvlength),
		.WR(recvWR),
		.writeData(recvwriteData),
		.readData(readData),
		.NewCommand(recvNewCommand),
		.Dummy_Read(Dummy_Read),
		.state(stateReg),
		.recvEn(recvEn),
		.receiveStatus(receiveStatus)
	);

//============================= Idle =============================
	wire idlelength, idleWR, idleNewCommand;
	wire[7:0] idleoffset;
	wire[15:0] idlewriteData;


//============================= Process Control =============================
	always @(posedge clk40m or negedge RSTN) begin
		if(!RSTN) begin
			transEn <= 0;
			recvEn <= 0;
		end
		else if(initDone == 1) begin
			transEn <= 1;
			packetLen <= 65;
//			recvEn <= 1;
		end
	end

//============================= MUX Module =============================	
	wire[1:0] RegMaster;

	MUX8 offsetMUX(
		.wire0(initoffset),
		.wire1(transoffset),
		.wire2(recvoffset),
		.wire3(idleoffset),
		.ctl(RegMaster),
		.out(offset)
	);
	MUX1 lengthMUX(
		.wire0(initlength),
		.wire1(translength),
		.wire2(recvlength),
		.wire3(1'b1),
		.ctl(RegMaster),
		.out(length)
	);
	MUX1 WRMUX(
		.wire0(initWR),
		.wire1(transWR),
		.wire2(recvWR),
		.wire3(idleWR),
		.ctl(RegMaster),
		.out(WR)
	);
	MUX16 writeDataMUX(
		.wire0(initwriteData),
		.wire1(transwriteData),
		.wire2(recvwriteData),
		.wire3(idlewriteData),
		.ctl(RegMaster),
		.out(writeData)
	);
	MUX1 NewCommandMUX(
		.wire0(initNewCommand),
		.wire1(transNewCommand),
		.wire2(recvNewCommand),
		.wire3(idleNewCommand),
		.ctl(RegMaster),
		.out(NewCommand)
	);
	
	RegMaster getMaster(
		.initDone(initDone),
		.transEn(transEn),
		.recvEn(recvEn),
		.RegMaster(RegMaster)
	);
	
	
//	wire[35:0] ILAControl;
//	Ethernet_icon icon(.CONTROL0(ILAControl));
//	Ethernet_ila ila(
//	    .CONTROL(ILAControl),
//		.CLK(clk40m),
//		.TRIG0(RSTN),
//		.TRIG1(transEn),
//		.TRIG2(initDone),
//		.TRIG3(0),
//		.TRIG4(transmitStatus),
//		.TRIG5(receiveStatus),
//		.TRIG6(RegMaster),
//		.TRIG7(transNewCommand),
//		.TRIG8(NewCommand),
//		.TRIG9(transWR),
//		.TRIG10(WR),
//		.TRIG11({offset,transoffset}),
//		.TRIG12(stateReg),
//		.TRIG13(RegMaster),
//		.TRIG14(0)
//	);
	
endmodule

module RegMaster(
	input initDone,
	input transEn,
	input recvEn,
	output wire[1:0] RegMaster
	);
	localparam [1:0] Init = 2'b00,
					 Transmit = 2'b01,
					 Receive = 2'b10,
					 Idle = 2'b11;

	assign RegMaster[0] = initDone ? (transEn ? 1'b1:(recvEn ? 1'b0:1'b1)):1'b0;
	assign RegMaster[1] = initDone ? (transEn ? 1'b0:(recvEn ? 1'b1:1'b1)):1'b0;
endmodule
