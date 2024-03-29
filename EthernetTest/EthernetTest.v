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
//	input wire clk40m,
	input wire clk1394,
	output wire reset_phy,
	output wire CSN,
	input wire RSTN,
	input wire PME,
	output wire CMD,
	input wire INTRN,
	output wire RDN,
	output wire WRN,
	inout [15:0] SD,
	output wire LED,
	input[3:0] wenid,
	input DEBUG
    );
	
	assign reset_phy = 1'b1;
	BUFG clksysclk(.I(clk1394), .O(sysclk));
//	wire sysclk;
//	assign sysclk = clk40m;
	
	reg sigLed,lled;
	always @(posedge sysclk) begin
		sigLed <= INTRN;
		if(sigLed && ~INTRN) begin
			lled <= ~lled;
		end
	end

	assign LED = lled;
	assign CSN = 0;//Always select
	wire TX, RX;
	reg[5:0] statusManager;
	
//	assign DEBUG = RX;

//============================= Register Module =============================	
	wire[3:0] stateReg;
	wire[15:0] readData, writeData;
	wire[7:0] offset;
	RegIO IOWR(
		.sysclk(sysclk),
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
		.sysclk(sysclk),
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
		.sysclk(sysclk),
		.reset(RSTN),
		.offset(transoffset),
		.length(translength),
		.WR(transWR),
		.writeData(transwriteData),
		.readData(readData),
		.NewCommand(transNewCommand),
		.Dummy_Write(Dummy_Write),
		.state(stateReg),
		.transmitStatus(transmitStatus),
		.wenid(wenid),
		.statusManager(statusManager),
		.TX(TX)
	);
	
//============================= Reception Module =============================
	wire recvlength, recvWR, recvNewCommand;
	wire[1:0] receiveStatus;
	wire[7:0] recvoffset;
	wire[15:0] recvwriteData;
	Reception Recv(
		.sysclk(sysclk),
		.reset(RSTN),
		.offset(recvoffset),
		.length(recvlength),
		.WR(recvWR),
		.writeData(recvwriteData),
		.readData(readData),
		.NewCommand(recvNewCommand),
		.Dummy_Read(Dummy_Read),
		.state(stateReg),
		.receiveStatus(receiveStatus),
		.statusManager(statusManager),
		.RX(RX)
	);

//============================= Idle =============================
	wire idlelength, idleWR, idleNewCommand;
	wire[7:0] idleoffset;
	wire[15:0] idlewriteData;


//============================= Process Control =============================
	reg[15:0] rtt;
	reg[31:0] TXcount;
	reg[15:0] waitcount;
	reg waiting;
	wire flag;
	assign flag = (TXcount == 32'h000FFFFF);
	always @(posedge sysclk or negedge RSTN) begin
		if(!RSTN) begin
			statusManager <= 6'b0;
			rtt <= 16'h0;
			TXcount <= 0;
			waiting <= 0;
		end
		else if(statusManager[1:0] == 2'b00) begin
			if(initDone) begin
				statusManager[1:0] <= 2'b01;
				rtt <= 0;
				TXcount <= 0;
			end
		end
		else if(statusManager[1:0] == 2'b01) begin // transmission
			if(TX) begin
				statusManager[1:0] <= flag ? 2'b11:2'b01;
				if(!flag) begin
					TXcount <= TXcount + 1;
				end
				//statusManager[5:2] <= statusManager[5:2] + 1;
			end
			rtt <= rtt + 1;
			waiting <= 0;
		end
		else if(statusManager[1:0] == 2'b10) begin // reception
			if(RX) begin
				statusManager[1:0] <= 2'b10;
			end
		end
		else begin
			if(DEBUG) begin
				waiting <= 1;
				waitcount <= 0;
			end
			else if(waiting) begin
				waitcount <= waitcount + 1;
				if(waitcount == 16'hFFFF) begin
					rtt <= 0;
					statusManager[1:0] <= 2'b01;
				end
			end
			else
				rtt <= rtt + 1;
		end
	end

//============================= MUX Module =============================	
	wire[1:0] RegMaster;
	assign RegMaster = statusManager[1:0];

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
	
	
	
	wire[35:0] ILAControl;
	Ethernet_icon icon(.CONTROL0(ILAControl));
	Ethernet_ila ila(
	    .CONTROL(ILAControl),
		.CLK(sysclk),
		.TRIG0(RSTN),
		.TRIG1(transEn),
		.TRIG2(initDone),
		.TRIG3(DEBUG),
		.TRIG4(transmitStatus),
		.TRIG5(receiveStatus),
		.TRIG6(rtt),
		.TRIG7(transNewCommand),
		.TRIG8(NewCommand),
		.TRIG9(flag),
		.TRIG10(TX),
		.TRIG11(TXcount[15:0]),
		.TRIG12(stateReg),
		.TRIG13(RegMaster),
		.TRIG14(RX)
	);
	
endmodule


