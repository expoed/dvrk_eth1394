`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:54:28 07/25/2014 
// Design Name: 
// Module Name:    MUX 
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
module MUX1 (
	input wire0,
	input wire1,
	input wire2,
	input wire3,
	input[2:0] ctl,
	output out
	);
	localparam [2:0] Init = 3'b000,
					 Transmit_Init = 3'b001,
					 Transmit = 3'b010,
					 Receive_Init = 3'b011,
					 Receive = 3'b100,
					 Idle = 3'b111;
	assign out = (ctl == Init)? wire0
				:(ctl == Transmit_Init || ctl == Transmit)? wire1
				:(ctl == Receive_Init || ctl == Receive)? wire2
				:wire3;
endmodule

module MUX8 (
	input[7:0] wire0,
	input[7:0] wire1,
	input[7:0] wire2,
	input[7:0] wire3,
	input[2:0] ctl,
	output[7:0] out
	);
	localparam [2:0] Init = 3'b000,
					 Transmit_Init = 3'b001,
					 Transmit = 3'b010,
					 Receive_Init = 3'b011,
					 Receive = 3'b100,
					 Idle = 3'b111;
	assign out[0] = (ctl == Init)? wire0[0]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[0]
				:(ctl == Receive_Init || ctl == Receive)? wire2[0]
				:wire3[0];
	assign out[1] = (ctl == Init)? wire0[1]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[1]
				:(ctl == Receive_Init || ctl == Receive)? wire2[1]
				:wire3[1];
	assign out[2] = (ctl == Init)? wire0[2]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[2]
				:(ctl == Receive_Init || ctl == Receive)? wire2[2]
				:wire3[2];
	assign out[3] = (ctl == Init)? wire0[3]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[3]
				:(ctl == Receive_Init || ctl == Receive)? wire2[3]
				:wire3[3];
	assign out[4] = (ctl == Init)? wire0[4]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[4]
				:(ctl == Receive_Init || ctl == Receive)? wire2[4]
				:wire3[4];
	assign out[5] = (ctl == Init)? wire0[5]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[5]
				:(ctl == Receive_Init || ctl == Receive)? wire2[5]
				:wire3[5];
	assign out[6] = (ctl == Init)? wire0[6]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[6]
				:(ctl == Receive_Init || ctl == Receive)? wire2[6]
				:wire3[6];
	assign out[7] = (ctl == Init)? wire0[7]
				:(ctl == Transmit_Init || ctl == Transmit)? wire1[7]
				:(ctl == Receive_Init || ctl == Receive)? wire2[7]
				:wire3[7];
endmodule

module MUX16 (
	input[15:0] wire0,
	input[15:0] wire1,
	input[15:0] wire2,
	input[15:0] wire3,
	input[2:0] ctl,
	output[15:0] out
	);
	MUX8 M1(.wire0(wire0[7:0]),
			.wire1(wire1[7:0]),
			.wire2(wire2[7:0]),
			.wire3(wire3[7:0]),
			.ctl(ctl),
			.out(out[7:0]));
	MUX8 M2(.wire0(wire0[15:8]),
			.wire1(wire1[15:8]),
			.wire2(wire2[15:8]),
			.wire3(wire3[15:8]),
			.ctl(ctl),
			.out(out[15:8]));
endmodule
