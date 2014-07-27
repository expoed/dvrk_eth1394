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
	output wire LED	
    );
	
	assign LED = RSTN;//Idle
	assign CSN = 0;//Always select
	wire[2:0] RegMaster;
	reg transEn = 0;
	reg recevEn = 0;
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
		.transmitStatus(transmitStatus)
	);
	
//============================= Reception Module =============================
	wire recevlength, recevWR, recevNewCommand;
	wire[1:0] receiveStatus;
	wire[7:0] recevoffset;
	wire[15:0] recevwriteData;

//============================= Idle =============================
	wire idlelength, idleWR, idleNewCommand;
	wire[7:0] idleoffset;
	wire[15:0] idlewriteData;


//============================= Process Control =============================
	always @(posedge clk40m or negedge RSTN) begin
		if(!RSTN)
			transEn <= 0;
		else if(initDone == 1) begin
			transEn <= 1;
			packetLen <= 10;
		end
	end

//============================= MUX Module =============================	
	MUX8 offsetMUX(
		.wire0(initoffset),
		.wire1(transoffset),
		.wire2(recevoffset),
		.wire3(idleoffset),
		.ctl(RegMaster),
		.out(offset)
	);
	MUX1 lengthMUX(
		.wire0(initlength),
		.wire1(translength),
		.wire2(recevlength),
		.wire3(idlelength),
		.ctl(RegMaster),
		.out(length)
	);
	MUX1 WRMUX(
		.wire0(initWR),
		.wire1(transWR),
		.wire2(recevWR),
		.wire3(idleWR),
		.ctl(RegMaster),
		.out(WR)
	);
	MUX16 writeDataMUX(
		.wire0(initwriteData),
		.wire1(transwriteData),
		.wire2(recevwriteData),
		.wire3(idlewriteData),
		.ctl(RegMaster),
		.out(writeData)
	);
	MUX1 NewCommandMUX(
		.wire0(initNewCommand),
		.wire1(transNewCommand),
		.wire2(recevNewCommand),
		.wire3(idleNewCommand),
		.ctl(RegMaster),
		.out(NewCommand)
	);
	
	RegMaster getMaster(
		.initDone(initDone),
		.transmitStatus(transmitStatus),
		.receiveStatus(receiveStatus),
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
//		.TRIG5(0),
//		.TRIG6(0),
//		.TRIG7(WR),
//		.TRIG8(NewCommand),
//		.TRIG9(0),
//		.TRIG10(0),
//		.TRIG11({offset,transoffset}),
//		.TRIG12(stateReg),
//		.TRIG13(RegMaster),
//		.TRIG14(0)
//	);
	
endmodule

module RegMaster(
	input initDone,
	input[1:0] transmitStatus,
	input[1:0] receiveStatus,
	output wire[2:0] RegMaster
	);
	localparam [2:0] Init = 3'b000,
					 Transmit_Init = 3'b001,
					 Transmit = 3'b010,
					 Receive_Init = 3'b011,
					 Receive = 3'b100,
					 Idle = 3'b111;

	assign RegMaster = initDone ? (transmitStatus == 2'b00 ? Transmit_Init
						:(transmitStatus == 2'b01 ? Transmit
						:(receiveStatus == 2'b00 ? Receive_Init
						:(receiveStatus == 2'b01 ? Receive
						:Idle))))
						:Init;

endmodule
