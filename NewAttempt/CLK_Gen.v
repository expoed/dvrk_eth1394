`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:51:48 07/22/2014 
// Design Name: 
// Module Name:    CLK_Gen 
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
module CLK_Gen(
	input clk40m,
	output clk200m,
	output clk400m
    );
	
	wire clkfb;//Click feedback
	wire _out200;
	wire _out400;
	wire _ref40;
	
	
PLL_BASE # (.BANDWIDTH         ("OPTIMIZED"),
	.CLK_FEEDBACK      ("CLKFBOUT"),
	.COMPENSATION      ("INTERNAL"),
	.DIVCLK_DIVIDE     (1),
            .CLKFBOUT_MULT     (10),        // CLKO = 40.000* 10/2 = 200.0000MHz
            .CLKFBOUT_PHASE    (0.000),
            .CLKOUT0_DIVIDE    (  2  ),
            .CLKOUT0_PHASE     (  0.00),
            .CLKOUT0_DUTY_CYCLE(  0.50),
            .CLKOUT1_DIVIDE    (  1  ),    // CLK1 = 400MHz
            .CLKOUT1_PHASE     (  0.00),
            .CLKOUT1_DUTY_CYCLE(  0.50),
            .CLKOUT2_DIVIDE    (  32  ),    // Unused Output. The divider still needs a
            .CLKOUT3_DIVIDE    (  32  ),    //    reasonable value because the clock is
            .CLKOUT4_DIVIDE    (  32  ),    //    still being generated even if unconnected.
            .CLKOUT5_DIVIDE    (  32  ))    //
_PLL1 (     .CLKFBOUT          (clkfb),     // The FB-Out is connected to FB-In inside
            .CLKFBIN           (clkfb),     //    the module.
            .CLKIN             (_ref40),    // 40.00 MHz reference clock
            .CLKOUT0           (_out200),    // 200 MHz Output signal
            .CLKOUT1           (_out400),    // 400 MHz Output signal
            .CLKOUT2           (),          // Unused outputs
            .CLKOUT3           (),          //
            .CLKOUT4           (),          //
            .CLKOUT5           (),          //
            .LOCKED            (),          //
            .RST               (1'b0));     // Reset Disable	

BUFG  clk_buf1 (.I(clk40m),    .O(_ref40));
BUFG  clk_buf2 (.I(_out200),  .O(clk200m ));
BUFG  clk_buf3 (.I(_out400),  .O(clk400m ));

endmodule
