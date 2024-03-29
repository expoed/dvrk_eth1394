/*******************************************************************************
 *
 * Copyright(C) 2008-2011 ERC CISST, Johns Hopkins University.
 *
 * This module implements the FireWire link layer state machine, which defines
 * the operation of the phy-link interface.  The state machine is triggered on
 * the positive edge of sysclk and makes its transitions based on the input ctl
 * lines and the current state.
 *
 * Inputs to this state machine are sysclk (1 bit) and ctl (2 bits).  data (8
 * bits) is normally data input/output, but does govern the state machine in
 * receive mode, where it indicates received data prefix.
 *
 * Outputs include ctl and data in transmit mode.  This module also outputs
 * state-related data and signals that are used by the main controller.
 *
 * Revision history
 *     04/24/08    Paul Thienphrapa    Initial revision
 *     10/13/10    Paul Thienphrapa    Copied from SnakeFPGA-rev2 and tweaked
 *                                       for Xilinx
 *     10/31/11    Paul Thienphrapa    React to rx packets only when addressed
 *     11/11/11    Paul Thienphrapa    Happy 111111!!11!
 *                                     Fixed mixed blocking/non-blocking issues`
 *     10/16/13    Zihan Chen          Modified to support hub capability
 *     10/28/13    Zihan Chen          Added seperate write address line
 */

// LLC: link layer controller (implemented in this file)

/**  
 *   NOTE: 
 *      - only part of the FireWire link layer controller is implemented 
 *      - transaction layer and link layer are mixed (not good, works for now)
 *      - ONLY control PC and FPGA_QLA boards can be attached to the same bus
 *
 *   Broadcast Packets (write ONLY)
 *      - bc_qwrite:  broadcast quadlet write
 *      - bc_bwrite:  broadcast block write
 *         - from PC 
 *         - from FPGA (priority = 4'hA)
 *   
 *   TX Mode
 *      FPGA mainly operates in passive mode, which means it does not initiate
 *      1394 transactions. The only exception is to broadcast self states as a 
 *      "response" to broadcast write from PC. The type of TX packets includes 
 *      the following list:
 *     
 *      List of TX types
 *        - ACK packet (e.g. ACK_DONE // ACK_PEND)
 *        - Quadlet Response
 *        - Block Response
 *           - Local info 
 *           - Hub info (with all FPGA nodes state)
 *        - Block Broadcast Write
 * 
 *    RX Mode
 *       List of RX types
 *         - QREAD: from PC 
 *         - BREAD: 
 *            - from PC for 1 board state
 *            - from PC for hub/prom/prom_qla data 
 *         - QWRITE: 
 *            - from PC: non-broadcast mode
 *            - from PC: broadcast mode
 *               - dest offset = 0xffff ffff xxxx indicates bc read request
 *               - otherwise, normal broadcast 
 *         - BWRITE:
 *            - from PC non-broadcast mode
 *            - from PC broadcast mode
 *            - from other FPGA broadcast mode (priority = 4'hA)
 *
 *  --------------------------------------------------------------------------------
 *  2014-01-24 NOTE for fake broadcast packet  Zihan Chen
 *   We noticed that some FireWire cards have issue with broadcast packets (can not 
 *   async read after sending broadcast packets). This leads us to use an asynchrnous 
 *   write packet as fake broadcast packet on the PC software for better robustness. 
 *    
 *   Lists:
 *     - Query Packet:  dest_node_id = 0, dest_addr = 0xffffffff000f
 *     - Command Packet: dest_node_id = 0, dest_addr = 0xffffffff0000
 *
 */
 

// -------------------------------------------------------
// IEEE-1394 64-bit Address Mapped 
// We only use last 16-bit, the rest bit number is 0 indexed
// 
//  addr[15:12] map 
//     4'h0: board register + device memory
//     4'h1: hub caching space
//     4'h2: M15P16 prom space
//     4'h3: QLA 25AA128 prom space
//         
// -------------------------------------------------------------


// global constant e.g. register & device address
`include "Constants.v"

// constants for receive speed codes
// See Book P237 Receving Packets, D[0] is omitted here
`define RX_S100 3'b000            // 100 Mbps
`define RX_S200 3'b001            // 200 Mbps
`define RX_S400 3'b101            // 400 Mbps

// phy request types (Ref: Book P230)
`define LREQ_TX_IMM 3'd0          // immediate transmit header
`define LREQ_TX_ISO 3'd1          // isochronous transmit header
`define LREQ_TX_PRI 3'd2          // priority transmit header
`define LREQ_TX_FAIR 3'd3         // fair transmit header
`define LREQ_REG_RD 3'd4          // register read header
`define LREQ_REG_WR 3'd5          // register write header
`define LREQ_ACCEL 3'd6           // async arbitration acceleration
`define LREQ_RES 3'd7             // reserved, presumably do nothing

// transmit mode ctl constants (llc driving)
`define CTL_IDLE 2'b00             // link asserts idle (done)
`define CTL_DATA 2'b01             // link is transmitting data
`define CTL_HOLD 2'b10             // link wants to hold the bus
`define CTL_UNUSED 2'b11           // link UNUSED

// transmit mode ctl constant (phy driving)
`define CTL_PHY_IDLE 2'b00         // phy driven ctrl status idle
`define CTL_PHY_RECV 2'b01         // phy driven ctrl status receive
`define CTL_PHY_STAT 2'b10         // phy driven ctrl status status
`define CTL_PHY_GRNT 2'b11         // phy driven ctrl status grand

// packet sizes
`define SZ_ACK 8                  // ack packet size
`define SZ_QREAD 16'd128          // quadlet read packet size
`define SZ_QWRITE 16'd160         // quadlet write packet size
`define SZ_QRESP 16'd160          // quadlet read response size
`define SZ_BWRITE 16'd192         // block write packet base size
`define SZ_BRESP 16'd192          // block read response base size
`define SZ_STAT 16'd16            // phy register transfer size
`define SZ_BC_REQ 16'd160         // QL: broadcast request packet size

//`define SZ_BBC  16'd576           // block write broadcast packet size
//                                  // (4 + 1 + 12 + 1) * 32 = 576
`define SZ_BBC  16'd736           // block write broadcast packet size
                                  // (4 + 1 + 1 + 16 + 1) * 32 = 736

// transaction and response codes
`define TC_QWRITE 4'd0            // quadlet write
`define TC_BWRITE 4'd1            // block write
`define TC_QREAD 4'd4             // quadlet read
`define TC_BREAD 4'd5             // block read
`define TC_QRESP 4'd6             // quadlet read response
`define TC_BRESP 4'd7             // block read response
`define TC_CSTART 4'd8            // cycle start packet
`define RC_DONE 4'd0              // complete response code

// ack values
`define ACK_DONE 4'h1             // transaction complete, applies to writes
`define ACK_PEND 4'h2             // transaction pending, applies to reads
`define ACK_DATA 4'hD             // ack crc error, used as a general error

// other
`define CRC_INIT -32'd1           // initial value to start new crc calculation



module PhyLinkInterface(
    // globals
    input wire sysclk,           // system clock
    input wire reset,            // global reset
    input wire[3:0] board_id,
    // phy-link interface bus
    inout[1:0] ctl_ext,          // control line
    inout[7:0] data_ext,         // data bus
    
    // act on received packets
    output reg reg_wen,          // register write signal
    
    // register access
    output reg[15:0] reg_addr,   // read address to external register file
    input wire[31:0] reg_rdata,  // read data from external register file
    output reg[31:0] reg_wdata,  // write data to external register file
    
    // transmit parameters
    output reg lreq_trig,        // trigger signal for a phy request
    output reg[2:0] lreq_type,   // type of request to give to the phy

	input wire[10:0] PC_Req_len,
	output reg[10:0] Resp_Data_len,
	input PC_REQ_NEW,
	output reg PC_REQ_Done//1: req executed, 0: not executed
);


    // -------------------------------------------------------------------------
    // registered outputs
    //
    
    // phy-link interface bus
    reg[7:0] data;                // data bus register
    reg[1:0] ctl;                 // control register

    // -------------------------------------------------------------------------
    // local wires and registers
    //

    reg[3:0] state, next;         // state register
    reg[2:0] rx_speed;            // received speed code
    reg[9:0] bus_id;              // phy bus id (10 bits)
    reg[5:0] node_id;             // phy node id register (6 bits)
    wire[15:0] local_id;          // full addr = bus_id + node_id

    // status-related buffers
    reg[15:0] st_buff;            // temp buffer for status
    reg[15:0] stcount;            // status bits counter

    // data buses
    wire[1:0] data2b;             // first two data bits
    wire[3:0] data4b;             // first four data bits
    wire[7:0] data8b;             // all eight data bits
    wire[7:0] txmsb8b;            // eight msb's of transmit buffer

    // packet data buffers and bit counters
    reg[31:0] buffer;             // buffer for receive/transmit bits
    reg[19:0] count;              // count received/transmitted bits

    // crc registers
    wire[7:0] crc_data;           // data into crc module to compute crc on
    reg[31:0] crc_comp;           // crc computed at each rx or tx data cycle
    reg[31:0] crc_in;             // input to crc module (starts at all ones)
    wire[31:0] crc_2b;            // current crc module output for data width 2
    wire[31:0] crc_4b;            // current crc module output for data width 4
    wire[31:0] crc_8b;            // current crc module output for data width 8
    wire[7:0] crc_8msb;           // shortcut to 8 msb's of crc_in register
    reg crc_tx;                   // flag to inidicate if in a transmit state

    // link request trigger and type
    reg crc_ini;                  // flag to reset the crc module

    // broadcast related fields
    reg[15:0] bc_sequence;     // broadcast sequence num
    reg[15:0] bc_fpga;         // indicates whether a boards exists    
    
    // ----- hub -------
    
    parameter num_channels = 4;

    // state machine states
    parameter[3:0]
        ST_IDLE = 0,              // wait for phy event
        ST_STATUS = 1,            // receive status from phy
        ST_RX_D_ON = 2,           // rx state, data-on indication
        ST_RX_DATA = 3,           // rx state, receiving bits
        ST_TX = 4,                // tx state, phy gives phy-link bus to link
        ST_TX_DRIVE = 5,          // tx state, link drives phy-link bus
        ST_TX_BC = 6,	          //QL: tx state, broadcast request
        ST_TX_PC = 7,   	      //QL: tx state, request from PC
        ST_TX_DONE1 = 13,         // tx state, link finalizes transmission
        ST_TX_DONE2 = 14;         // tx state, phy regains phy-link bus



// -----------------------------------------------------------------------------
// hardware description
//

//
// continuous assignments and aliases for better readability (and writability!)
//

// full local_id
assign local_id = { bus_id[9:0], node_id[5:0] };   // full addr = bus_id + node_id     

// hack for xilinx, compiler doesn't like inout ports as registers
assign data_ext = data;
assign ctl_ext = ctl;

// phy data lines, which are in reversed bit order
assign data2b = { data[0], data[1] };
assign data4b = { data[0], data[1], data[2], data[3] };
assign data8b = { data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7] };
assign txmsb8b = { buffer[24], buffer[25], buffer[26], buffer[27], buffer[28], buffer[29], buffer[30], buffer[31] };

// select data to compute crc on depending on if rx or tx
assign crc_data = crc_tx ? buffer[31:24] : data8b;

// hack to get high byte of transmit crc out to the data line because the crc
//   gets computed one cycle later than we'd like, based on our implementation
assign crc_8msb = { crc_in[24], crc_in[25], crc_in[26], crc_in[27], crc_in[28], crc_in[29], crc_in[30], crc_in[31] };

// this module computes crc continuously, so it's up to the state machine to
//   initialize, feed back, and latch crc values as necessary
crc32 mycrc(crc_data, crc_in, crc_2b, crc_4b, crc_8b);

// -------------------------------------------------------
// Timestamp 
// -------------------------------------------------------
// timestamp counts number of clocks between block reads
reg[31:0] timestamp;          // timestamp counter register
always @(posedge(sysclk) or negedge(reset))
begin
    if (reset == 0)
        timestamp <= 0;
    else
        timestamp <= timestamp + 1'b1;
end

//+++++++++++++++Qian Long++++++++++++++++++
wire BC_REQ_trig;
reg BC_REQ;
//assign BC_REQ_trig = (timestamp[19:0] == 20'hFFFFF) ? 1'b1: 1'b0;
assign BC_REQ_trig = 0;
reg[15:0] self_status; // just record the firewire status
reg[3:0] ACK_RESP;
reg BC_Receive; // Indicating receiving bc packets from nodes
reg PC_REQ_NEW_Prev, PC_REQ_trig;

always @(posedge sysclk) begin
	PC_REQ_NEW_Prev <= PC_REQ_NEW;
	if(PC_REQ_NEW && ~PC_REQ_NEW_Prev) begin
		PC_REQ_trig <= 1;
	end
	else
		PC_REQ_trig <= 0;
end

//
// state machine clocked by sysclk; transitions depend on ctl and data
//
always @(posedge(sysclk) or negedge(reset))
begin

    // reset sends everything to default states and values
    if (reset == 0)
    begin
        // bidir phy-link lines normally driven by phy (we're the link)
        ctl <= 2'bz;              // phy-link control lines
        data <= 8'bz;             // phy-link data lines

        // initialize internal buffers, registers, and counters
        state <= ST_IDLE;         // initialize state machine to idle state
        st_buff <= 0;             // status value receive buffer
        stcount <= 0;             // received status bits counter
        rx_speed <= 0;            // clear the received speed code
        lreq_trig <= 0;           // clear the phy request trigger
        lreq_type <= 0;           // set phy request type to known value
		node_id <= {2'b0,4'hF};
        bus_id <= 10'h3ff;        // set default bus_id to 10'h3ff
        reg_addr <= `ADDR_DEFAULT;// set reg address to known value
        reg_wdata <= 32'hz;           // set reg write data to known value
		reg_wen <= 0;
		self_status <= 0;
		ACK_RESP <= 0;
		BC_REQ <= 0;
		Resp_Data_len <= 0;
		bc_sequence <= 16'hFFFF;//So it will start from 0
		bc_fpga <= 16'h0001;//Indicate FPGA0 exists
		PC_REQ_Done <= 1;
    end

    // phy-link state machine
    else begin
        case (state)

        /***********************************************************************
         * idle state, waiting for phy to do something
         */

        ST_IDLE:
        begin
            // monitor ctl to select next state
            case (ctl)
                2'b00: begin 
                    state <= ST_IDLE;           // stay in monitor state
                    if (BC_REQ_trig) begin
                        lreq_trig <= 1;
                        lreq_type <= `LREQ_TX_ISO;
						BC_REQ <= 1;
						bc_sequence <= bc_sequence + 1;
                    end
					else if(PC_REQ_trig) begin
						PC_REQ_Done <= 0;
						lreq_trig <= 1;
						BC_REQ <= 0;
                        lreq_type <= `LREQ_TX_ISO;
					end
					else begin
						lreq_trig <= 0;	//must be pulled down to start TX/RX					
					end
                end                
                2'b01: state <= ST_RX_D_ON;        // phy data from the bus
                2'b11: begin
					state <= ST_TX;             // phy grants tx request
				end
				2'b10: begin                       // phy status transfer
                    st_buff <= {16'b0, data2b};    // clock in status bits
                    state <= ST_STATUS;            // continue status loop
                    stcount <= 2;                  // start status bit count
                end
            endcase
			
//			if(ACK_RESP != 0) begin
//				ACK_RESP <= 0;
//				reg_wen <= 0;
//			end
			
			if(reg_wen)
				reg_wen <= 0;
			reg_addr <= `ADDR_DEFAULT;
        end


        /***********************************************************************
         * receiving status (i.e. register read or spontaneously) from phy
         */

        ST_STATUS:
        begin
            // do status transfer until complete or interrupted by data RX
            case (ctl)

                2'b01: state <= ST_RX_D_ON;        // interrupt by RX bus data
                2'b11: state <= ST_IDLE;           // undefined, back to idle
                // -------------------------------------------------------------
                // normal status transfer
                //
                2'b10: begin
                    st_buff <= st_buff << 2;       // shift over previous bits
                    st_buff[1:0] <= data2b;        // clock in 2 new bits
                    stcount <= stcount + 2'd2;     // count transferred bits
                    state <= ST_STATUS;            // loop in this state
                end
                // -------------------------------------------------------------
                // status transfer complete
                //
                2'b00: begin

                    state <= ST_IDLE;              // go back to idle state
                    // save phy register into register file
                    if (stcount == `SZ_STAT) begin
                        self_status <= st_buff;
                        node_id <= {2'b0,4'hF};//node_id <= st_buff[7:2];
                    end
                end

            endcase
        end


        /***********************************************************************
         * receiving data packet from phy, from the bus
         */

        // ---------------------------------------------------------------------
        // wait until data-on goes away, i.e. when phy provides speed code
        // Data: 00h FFh FFh FFh FFh Speed Data0 Data1 Data2 .... Datan 00h 00h
        // Ctrl: 00b 01b 01b 01b 01b   01b   01b   01b   01b ....   01b 00b 00b
        ST_RX_D_ON:
        begin
            // wait out data-on until data RX starts (or null packet indicated)
            case ({data[0], ctl})
                3'b101: state <= ST_RX_D_ON;        // loop in data-on state
                3'b001: begin                       // receiving data packet
                    rx_speed <= data[3:1];          // latch 4-bit speed code
                    state <= ST_RX_DATA;            // go to receive data loop
                    count <= 0;                     // reset receive bit count
                end
                default: state <= ST_IDLE;          // null packet or error
            endcase
        end

        // ---------------------------------------------------------------------
        // receive packet data from serial bus via phy
        //
        ST_RX_DATA:
        begin
            // receive data from phy until phy indicates completion
            case (ctl)
                // -------------------------------------------------------------
                // normal receive loop
                //
                2'b01:
                begin
                    // loop in this state while ctl value tells us to
                    state <= ST_RX_DATA;
                    // ---------------------------------------------------------
                    // on-the-fly packet processing at 32-bit boundaries
                    //
					if(count == 0) begin// Avoid entering the "else" loop
						reg_wen <= 0;
						BC_Receive <= 0;
					end
                    // first quadlet received ------------------------------
                    else if(count == 32) begin
						if(buffer[31:0] == 32'hFFFFXX1A) begin
							BC_Receive <= 1;
							reg_addr <= `ADDR_BC_RECEIVE;
							reg_wen <= 0;
						end
						else begin
							BC_Receive <= 0;
							reg_addr <= `ADDR_RESP_DATA;
							reg_wdata <= buffer;
							reg_wen <= 1;
						end
					end
					// second quadlet --------------------------------------
                    else if(count == 64) begin
						if(BC_Receive) begin
							reg_addr <= reg_addr + buffer[19:16]*`SZ_BC_RECEIVE - 1;//Correspond to the target area for BC receive data
						end
						else begin//Command from PC
							reg_addr <= reg_addr + 1;
							reg_wdata <= buffer;
						end
					end
					else if(count == 96 || count == 128 || count == 160) begin
						if(!BC_Receive) begin//Command from PC
							reg_addr <= reg_addr + 1;
							reg_wdata <= buffer;
						end
					end
					else begin
						if(count[4:0] == 5'b0)begin
							if(BC_Receive) begin
								reg_wen <= 1;
								reg_addr <= reg_addr + 1;
								reg_wdata <= buffer;
							end
							else begin
								reg_addr <= reg_addr + 1;
								reg_wdata <= buffer;
							end
						end
					end

                    // ---------------------------------------------------------
                    // buffer and count data bits from the phy
                    //
                    case (rx_speed)
                        `RX_S100: begin
                            buffer <= buffer << 2;
                            buffer[1:0] <= data2b;
                            count <= count + 16'd2;
                        end
                        `RX_S200: begin
                            buffer <= buffer << 4;
                            buffer[3:0] <= data4b;
                            count <= count + 16'd4;
                        end
                        `RX_S400: begin
                            buffer <= buffer << 8;
                            buffer[7:0] <= data8b;
                            count <= count + 16'd8;
                        end
                        default: begin
                            /* undefined speed code, do nothing */
                            // steps for each of the above cases:
                            // - shift over (2,4,8) previously read bits
                            // - clock in (2,4,8) new data bits
                            // - increment bit counter by (2,4,8)
                            // - feed back new crc for next iteration
                        end
                    endcase  // rx_speed
                end

                // -------------------------------------------------------------
                // receive complete, prepare for response actions (e.g. ack)
                //
                2'b00:
                begin
                    // next state, go back to idle
                    state <= ST_IDLE;
					if(count == 8) begin
						if(buffer[7:0] == {`ACK_DONE, ~`ACK_DONE}) begin
							ACK_RESP <= `ACK_DONE;
//							reg_addr <= `ADDR_RESP_DATA;
//							reg_wen <= 1;
//							reg_wdata <= {`ACK_DONE, 24'h0};
//							Resp_Data_len <= 8;
						end
						else if(buffer[7:0] == {`ACK_PEND, ~`ACK_PEND}) begin
							ACK_RESP <= `ACK_PEND;
//							reg_addr <= `ADDR_RESP_DATA;
//							reg_wen <= 1;
//							reg_wdata <= {`ACK_PEND, 24'h0};
//							Resp_Data_len <= 8;
						end
						else if(buffer[7:0] == {`ACK_DATA, ~`ACK_DATA}) begin
							ACK_RESP <= `ACK_DATA;
//							reg_addr <= `ADDR_RESP_DATA;
//							reg_wen <= 1;
//							reg_wdata <= {`ACK_DATA, 24'h0};
//							Resp_Data_len <= 8;
						end
					end
					else if(count[4:0] == 5'b0)begin
						reg_wen <= 1;
						reg_addr <= reg_addr + 1;
						reg_wdata <= buffer;
					end
					if(!BC_Receive) begin
						Resp_Data_len <= count;
					end
                end

                // -------------------------------------------------------------
                // undefined condition, go back to idle
                //
                default: state <= ST_IDLE;

            endcase
        end


        /***********************************************************************
         * transmitting data packet to phy, to the bus
         * assumes data is already ready in TX buffer
         */

        // ---------------------------------------------------------------------
        // an 'idle' state before phy lets link drive the interface
        //
        ST_TX:
        begin
            state <= ST_TX_DRIVE;        // the next state
            count <= 0;                  // prepare the bit counter

			if(BC_REQ) begin
				buffer <= 32'hFFC00000;
				next <= ST_TX_BC;
				crc_in <= `CRC_INIT;         // start new crc calculation
				crc_ini <= 0;                // normal crc operation
				crc_tx <= 1;                 // selects tx data for crc
			end
			else begin
				buffer <= reg_rdata;//reg_raddr is set in IDLE state
				reg_addr <= reg_addr + 1;
				next <= ST_TX_PC;
			end
        end

        // ---------------------------------------------------------------------
        // another 'idle' state where link starts to drive the interface
        //
        ST_TX_DRIVE:
        begin
            ctl <= `CTL_HOLD;
            state <= next;
        end


        ST_TX_BC:
        begin
            if (count == `SZ_BC_REQ) begin
                ctl <= `CTL_IDLE;
                state <= ST_TX_DONE1;
            end

            else begin
                ctl <= `CTL_DATA;

                // shift out transmit bit from buffer and update counter
                data <= txmsb8b;
                buffer <= buffer << 8;
                count <= count + 16'd8;
                crc_in <= crc_8b;

                // update transmit buffer at 32-bit boundaries
                case (count)
                     24: buffer <= {local_id, 16'hffff};
                     56: buffer <= 32'hffff_000f;
                     88: buffer <= {bc_sequence, bc_fpga};
                    128: begin
                        data <= ~crc_8msb;
                        buffer <= { ~crc_in[23:0], 8'd0 };
                    end
                endcase
            end
        end
		
		ST_TX_PC:
		begin
			if(count == PC_Req_len) begin
                ctl <= `CTL_IDLE;
                state <= ST_TX_DONE1;
				PC_REQ_Done <= 1;
			end
            else begin
                ctl <= `CTL_DATA;

                // shift out transmit bit from buffer and update counter
                data <= txmsb8b;
                buffer <= buffer << 8;
                count <= count + 16'd8;

                // update transmit buffer at 32-bit boundaries
                if(count[4:0] == 5'd24) begin
					if(count != PC_Req_len - 8) begin//An exception
						buffer <= reg_rdata;
						reg_addr <= reg_addr + 1;
					end
				end
            end		
		end


        // ---------------------------------------------------------------------
        // drive one more cycle of idle
        //
        ST_TX_DONE1:
        begin
            ctl <= `CTL_IDLE;            // one cycle of idle
            state <= ST_TX_DONE2;        // phy regains bus in next state
			
        end

        // ---------------------------------------------------------------------
        // reliquish control of the bus to the phy and return to idle state
        //
        ST_TX_DONE2:
        begin
            ctl <= 2'bz;             // allow phy to drive ctl
            data <= 8'bz;            // allow phy to drive data
            state <= ST_IDLE;        // TX done, go to idle state
        end


        // ---------------------------------------------------------------------
        // just in case state machine reaches an illegal state
        //
        default: begin
            state <= ST_IDLE;
        end

        endcase
    end
end

//Chipscope

	wire[35:0] ctrl;
	Firewire_icon ICON(
		.CONTROL0(ctrl)
	);
	Firewire_ila ILA(
		.CONTROL(ctrl),
		.CLK(sysclk),
		.TRIG0(ctl_ext),
		.TRIG1(data_ext),
		.TRIG2(reg_wen),
		.TRIG3(PC_REQ_NEW),
		.TRIG4(PC_REQ_Done),
		.TRIG5(reg_addr),
		.TRIG6(Resp_Data_len),
		.TRIG7(reg_rdata),
		.TRIG8(reg_wdata),
		.TRIG9(lreq_trig),
		.TRIG10(lreq_type),
		.TRIG11(buffer),
		.TRIG12(count),
		.TRIG13(ACK_RESP),
		.TRIG14(state),
		.TRIG15(PC_Req_len)
	);
endmodule  // PhyLinkInterface


/*******************************************************************************
 * This module sends a request to the phy, via the lreq line, initiated by a
 * high level trigger signal.  The type of request, be it bus transfers or
 * register accesses, is encoded in type.
 */

// length of various request bitstreams
`define LEN_LREQ 24

module PhyRequest(
    input  wire     sysclk,     // global system clock
    input  wire     reset,      // global reset signal
    output wire     lreq,       // lreq line to the phy
    
    input wire      trigger,    // initiates a link request
    input wire[2:0] rtype       // encoded requested type
);

// local registers
reg[16:0] request;       // formatted request bit sequence


// -----------------------------------------------------------------------------
// hardware description
//

assign lreq = request[16];           // shift out msb of request string

// requests initiated by active low trigger and shifted out on sysclk
always @(posedge(sysclk) or negedge(reset))
begin
    // reset signal actions
    if (reset == 0)
        request <= 0;

    // on trigger, construct request string
    else if (trigger == 1) begin
        request[16:12] <= { 2'b01, rtype };
        case (rtype)
            `LREQ_TX_IMM: request[11:9] <= 3'b100;   // S400
            `LREQ_TX_ISO: request[11:9] <= 3'b100;   // S400
            `LREQ_TX_PRI: request[11:9] <= 3'b100;   // S400
        endcase
    end

    // shift out one bit per sysclk
    else
        request <= request << 1;
end

endmodule  // PhyRequest