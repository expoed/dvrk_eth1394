`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:39:30 07/18/2014 
// Design Name: 
// Module Name:    writeReg 
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
	wire[1:0] offsetLast;
	assign offsetLast = offset[1:0];
	assign Addr[12] = (offsetLast==0) ? 1:0;
	assign Addr[13] = ((~length && offsetLast==1) || (length && offsetLast==0)) ? 1:0;
	assign Addr[14] = (offsetLast==2) ? 1:0;
	assign Addr[15] = ((~length && offsetLast==3) || (length && offsetLast==2)) ? 1:0;	
	assign Addr[7:2] = offset[7:2];
endmodule

module AccessReg(
	input wire clk40m,
	input wire reset,
	output reg CMD,//Port 1
	output reg RDN,//2
	output reg WRN,	//3
	input wire WR,//4
	input wire[7:0] offset,
	input wire length,
	inout[15:0] SD,//5
	input wire[15:0] dataWrite,//Data to be written to Reg//6
	output reg[15:0] dataRead,//Data read out from Reg//7
	input wire Trig,//8
	output reg preDone//In stage 5 of any cycle, ask whether there is no input 9
	);

	reg[15:0] SDReg;//10
	wire[15:0] Addr;//12
	getAddr(
		.offset(offset),
		.length(length),
		.Addr(Addr)
	);
	
	localparam [3:0] Addr0 = 4'b0000,//0
					 Addr1 = 4'b0001,//1
					 Addr2 = 4'b0010,//2
					 Read0 = 4'b0011,//3
					 Read1 = 4'b0100,//4
					 Read2 = 4'b0101,//5
					 Write0 = 4'b0110,//6
					 Write1 = 4'b0111,//7
					 Write2 = 4'b1000,//8
					 Wait = 4'b1001;//9
	reg[3:0] state, next_state;//13,14
	reg prevTrig;
	
//	always @(posedge clk40m) begin
//		state = next_state;
//	end
	
	wire newCommand;//15
	assign newCommand = (prevTrig&&~Trig) || (~prevTrig&&Trig);

	assign SD = WRN ? 16'bz:SDReg;
	
	always @(posedge clk40m or negedge reset) begin//FSM
		if(!reset) begin
			CMD = 1;
			RDN = 1;
			WRN = 1;
			SDReg = 16'hz;
			preDone = 0;
			state = Addr0;
		end
		else begin
			case(state)
				Addr0://0
					begin
						CMD = 1;
						WRN = 0;
						SDReg = Addr;
						state = Addr1;
					end
				Addr1://1
					begin
						state = Addr2;
					end
				Addr2://2
					begin
						WRN = 1;
						state = WR ? Read0:Write0;
					end
				Read0://3
					begin
						SDReg = 16'hz;
						CMD = 0;
						RDN = 0;
						state = Read1;
					end
				Read1://4
					begin
						state = Read2;
						preDone = 1;
					end
				Read2://5
					begin
						RDN = 1;
						dataRead = SD;
						preDone = 0;
						if(newCommand)
							state = Addr0;
						else
							state = Wait;
					end
				Write0://6
					begin
						SDReg = dataWrite;
						CMD = 0;
						WRN = 0;
						state = Write1;
					end
				Write1://7
					begin
						state = Write2;
						preDone = 1;
					end
				Write2://8
					begin
						WRN = 1;
						state = Wait;
						preDone = 0;
						if(newCommand)
							state = Addr0;
						else
							state = Wait;
					end
				Wait://9
					begin
						if(newCommand) begin
							state = Addr0;
						end
					end
			endcase
			prevTrig = Trig;
		end

	end
		
endmodule

