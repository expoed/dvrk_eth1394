///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2014 Xilinx, Inc.
// All Rights Reserved
///////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor     : Xilinx
// \   \   \/     Version    : 13.4
//  \   \         Application: Xilinx CORE Generator
//  /   /         Filename   : Ethernet_ila.v
// /___/   /\     Timestamp  : Wed Jul 23 15:00:44 Eastern Daylight Time 2014
// \   \  /  \
//  \___\/\___\
//
// Design Name: Verilog Synthesis Wrapper
///////////////////////////////////////////////////////////////////////////////
// This wrapper is used to integrate with Project Navigator and PlanAhead

`timescale 1ns/1ps

module Ethernet_ila(
    CONTROL,
    CLK,
    TRIG0,
    TRIG1,
    TRIG2,
    TRIG3,
    TRIG4,
    TRIG5,
    TRIG6,
    TRIG7,
    TRIG8,
    TRIG9,
    TRIG10,
    TRIG11,
    TRIG12,
    TRIG13,
    TRIG14);


inout [35 : 0] CONTROL;
input CLK;
input [0 : 0] TRIG0;
input [0 : 0] TRIG1;
input [0 : 0] TRIG2;
input [0 : 0] TRIG3;
input [15 : 0] TRIG4;
input [15 : 0] TRIG5;
input [15 : 0] TRIG6;
input [0 : 0] TRIG7;
input [0 : 0] TRIG8;
input [15 : 0] TRIG9;
input [0 : 0] TRIG10;
input [15 : 0] TRIG11;
input [3 : 0] TRIG12;
input [3 : 0] TRIG13;
input [0 : 0] TRIG14;

endmodule
