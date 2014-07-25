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
	
	assign LED = ~initDone;
	assign CSN = 0;
	wire[3:0] stateReg;
	wire[7:0] initoffset, offset;
	wire initlength, initWR, initNewCommand, initDone;
	wire[15:0] initwriteData, readData, writeData;
	
	ModuleInitialization Init(
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
		.state(stateReg)
    );
	
	wire [7:0] otheroffset;
	wire otherlength, otherWR, otherNewCommand;
	wire [15:0] otherwriteData;
	
	
	MUX8 offsetMUX(
		.wire0(initoffset),
		.wire1(otheroffset),
		.ctl(initDone),
		.out(offset)
	);
	MUX1 lengthMUX(
		.wire0(initlength),
		.wire1(otherlength),
		.ctl(initDone),
		.out(length)
	);
	MUX1 WRMUX(
		.wire0(initWR),
		.wire1(otherWR),
		.ctl(initDone),
		.out(WR)
	);
	MUX16 writeDataMUX(
		.wire0(initwriteData),
		.wire1(otherwriteData),
		.ctl(initDone),
		.out(writeData)
	);
	MUX1 NewCommandMUX(
		.wire0(initNewCommand),
		.wire1(otherNewCommand),
		.ctl(initDone),
		.out(NewCommand)
	);
	
endmodule


