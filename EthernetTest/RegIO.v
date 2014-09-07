`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:35:32 07/24/2014 
// Design Name: 
// Module Name:    RegIO 
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
module getAddr(
	input wire[7:0] offset,
	input wire length,//length=0:byte, length=1:word
	output wire[15:0] Addr
	);
	wire[1:0] offsetTail;
	assign offsetTail = offset[1:0];
	assign Addr[12] = (offsetTail==0) ? 1:0;
	assign Addr[13] = ((~length && offsetTail==1) || (length && offsetTail==0)) ? 1:0;
	assign Addr[14] = (offsetTail==2) ? 1:0;
	assign Addr[15] = ((~length && offsetTail==3) || (length && offsetTail==2)) ? 1:0;	
	assign Addr[7:2] = offset[7:2];
	assign Addr[1:0] = offsetTail;//Not necessary
	assign Addr[11:8] = 4'h0;//Not necessary
endmodule

module RegIO(
	input sysclk,
	input reset,
	output reg CMD,
	output reg RDN,
	output reg WRN,
	inout[15:0] SD,
	input WR,
	input[7:0] offset,
	input length,//length=0:byte, length=1:word
	input[15:0] writeData,
	output reg[15:0] readData,
	input NewCommand,//to be continued to not
	input Dummy_Write,
	input Dummy_Read,
	output reg[3:0] state
    );
	
	wire[15:0] Addr;
	
	getAddr newAddr(
		.offset(offset),
		.length(length),
		.Addr(Addr)
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
					 Wait = 4'b1001,
					 Readmore = 4'b1010,	// added for 1394 clock
					 Writemore = 4'b1011;	// added for 1394 clock
	
	reg [15:0] SDReg;
	
	assign SD = RDN ? SDReg:16'hz;
	

	always @(posedge sysclk or negedge reset) begin
		if(!reset) begin
			state <= Wait;
		end
		else begin
			case(state)
				Addr0:
					begin
						CMD <= 1;
						WRN <= 0;
						SDReg <= Addr;
						state <= Addr1;
					end
				Addr1:
					begin
						state <= Addr2;
					end
				Addr2:
					begin
						WRN <= 1;
						state <= WR ? Write0:Read0;
					end
				Read0:
					begin
						SDReg <= 16'hz;
						CMD <= 0;
						RDN <= 0;
						state <= Read1;
					end
				Read1:
					begin
						state <= Readmore;
//						state <= Read2;
					end
				Readmore:
					begin
						state <= Read2;
					end
				Read2:
					begin
						readData <= SD;
						RDN <= 1;
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
					end
				Write0:
					begin
						SDReg <= writeData;
						CMD <= 0;
						WRN <= 0;
						state <= Write1;
					end
				Write1:
					begin
						state <= Writemore;
//						state <= Write2;
					end
				Writemore:
					begin
						state <= Write2;
					end
				Write2:
					begin
						WRN <= 1;
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
					end
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

//	wire[35:0] ILAControl;
//	Ethernet_icon icon(.CONTROL0(ILAControl));
//	Ethernet_ila ila(
//	    .CONTROL(ILAControl),
//		.CLK(sysclk),
//		.TRIG0(CMD),
//		.TRIG1(RDN),
//		.TRIG2(WRN),
//		.TRIG3(reset),
//		.TRIG4(SD),
//		.TRIG5(SDReg),
//		.TRIG6(readData),
//		.TRIG7(WR),
//		.TRIG8(NewCommand),
//		.TRIG9(Addr),
//		.TRIG10(length),
//		.TRIG11(offset),
//		.TRIG12(state),
//		.TRIG13(Dummy_Read),
//		.TRIG14(Dummy_Write)
//	);

endmodule
