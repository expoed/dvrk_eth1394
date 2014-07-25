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
	input ctl,
	output out
	);
	assign out = ctl? wire1:wire0;
endmodule

module MUX8 (
	input[7:0] wire0,
	input[7:0] wire1,
	input ctl,
	output[7:0] out
	);
	assign out[0] = ctl? wire1[0]:wire0[0];
	assign out[1] = ctl? wire1[1]:wire0[1];
	assign out[2] = ctl? wire1[2]:wire0[2];
	assign out[3] = ctl? wire1[3]:wire0[3];
	assign out[4] = ctl? wire1[4]:wire0[4];
	assign out[5] = ctl? wire1[5]:wire0[5];
	assign out[6] = ctl? wire1[6]:wire0[6];
	assign out[7] = ctl? wire1[7]:wire0[7];
endmodule

module MUX16 (
	input[15:0] wire0,
	input[15:0] wire1,
	input ctl,
	output[15:0] out
	);
	assign out[0] = ctl? wire1[0]:wire0[0];
	assign out[1] = ctl? wire1[1]:wire0[1];
	assign out[2] = ctl? wire1[2]:wire0[2];
	assign out[3] = ctl? wire1[3]:wire0[3];
	assign out[4] = ctl? wire1[4]:wire0[4];
	assign out[5] = ctl? wire1[5]:wire0[5];
	assign out[6] = ctl? wire1[6]:wire0[6];
	assign out[7] = ctl? wire1[7]:wire0[7];
	assign out[8] = ctl? wire1[8]:wire0[8];
	assign out[9] = ctl? wire1[9]:wire0[9];
	assign out[10] = ctl? wire1[10]:wire0[10];
	assign out[11] = ctl? wire1[11]:wire0[11];
	assign out[12] = ctl? wire1[12]:wire0[12];
	assign out[13] = ctl? wire1[13]:wire0[13];
	assign out[14] = ctl? wire1[14]:wire0[14];
	assign out[15] = ctl? wire1[15]:wire0[15];
endmodule
