/*******************************************************************************    
 *
 * Copyright(C) 2011-2014 ERC CISST, Johns Hopkins University.
 *
 * This is the top level module for the Ethernet-FPGA1394-QLA motor controller interface.
 *
 * Revision history
 *     08/14/14    Long Qian
 */
 
`timescale 1ns / 1ps

// clock information
// clk1394: 49.152 MHz 
// sysclk: same as clk1394 49.152 MHz

`include "Constants.v"


module Hub
(
    // ieee 1394 phy-link interface
    input            clk1394,   // 49.152 MHz
    inout [7:0]      data,
    inout [1:0]      ctl,
    output wire      lreq,
    output wire      reset_phy,
	
	// ksz8851-16mll ethernet interface
	output wire 	 CSN,		// chip select not
	input wire 		 RSTN,		// reset, physically wired to the button
	input wire 		 PME,		// power management event, unused
	output wire 	 CMD,		// command input for ksz8851 register IO
	input wire 		 INTRN,		// interrupt
	output wire 	 RDN,
	output wire 	 WRN,
	inout [15:0] 	 SD,
	output wire 	 LED,
	
	input[3:0] 	 	 wenid		// rotary switch on 1394 board
);


	// 1394 phy low reset, never reset
	assign reset_phy = 1'b1;
	assign CSN = 0;			// Always select
	BUFG clksysclk(.I(clk1394), .O(sysclk));


	// length of PC request and response stored in RAM
	wire[10:0] PC_REQ_LEN;
	wire[10:0] RESP_DATA_LEN;

	
	// number of nodes in the network, input from PC SPECIAL frame
	// ranging from 0~14, 1 node to 15 nodes
	wire[3:0] num_node;
	// record the number of Broadcast response received by the HUB
	reg[3:0] BC_Packet_Count;
	
	
	
// --------------------------------------------------------------------------
// procedual control module
// --------------------------------------------------------------------------

	
	// pulses ( 1 -> 0 -> 1 ) indicating the end of different processes
	// BC stands for broadcast
	wire ETH_Init_Done;			// init finished
	wire Node_Set;			// number of nodes set
	wire PC_REQ_NEW;		// New PC request received from ETH
	wire PC_REQ_TXed;		// PC request transmitted through FW
	wire BC_REQ_TXed;		// BC request transmitted through FW
	wire ACK_RXed;			// Acknowledgement received from FW ( BC & PC )
	wire RESP_RXed;			// PC request response received from FW
	wire BC_RESP_RXed;		// Broadcast response received from FW
	wire Trans_Done;		// Response transmitted through ETH ( BC & PC )
	
	wire[3:0] ACK_RESP;		// the type of ACK, see Constants.v

	
	
	// StatusManager: Controlling the state of function
	// bit 5: Init finished or not
	// bit 4:3: State of Ethernet Line
	//			2'b00: Idle
	//			2'b01: Hub -> PC(Transmission): Broadcast Response
	//			2'b10: PC -> Hub(Reception)   : PC Request
	//			2'b11: Hub -> PC(Transmission): PC Command Response
	// bit 2:0: State of FireWire Line
	//		    3'b000: Idle
	//		   	3'b001: Hub -> Nodes(Transmission): PC Request 
	//			3'b011: Hub -> Nodes(Transmission): Broadcast Request
	//			3'b100: Nodes -> Hub(Reception)   : PC Request ACK
	//			3'b101: Nodes -> Hub(Reception)   : Broadcast Request ACK
	//			3'b110: Nodes -> Hub(Reception)   : PC Request Response
	//			3'b111: Nodes -> Hub(Reception)   : Broadcast Response	
	reg[5:0] StatusManager;
	reg[11:0] timeout_count;	// set timeout to be 4096 cycle = 81.92 ms
	
	
	// The hub has two operating mode:
	//		0: PC commnad mode		LED light
	//		1: BC mode		  		LED dark
	reg HubMode = 0;		
	assign LED = HubMode;
	
	
	always @(posedge sysclk or negedge RSTN) begin
		if(!RSTN) begin
			StatusManager <= 6'b0;// start initializing
			BC_Packet_Count <= 0;
			HubMode <= ~HubMode;
			timeout_count <= 0;
		end
		else begin
		//-------------------------------------------------------------
		//---------------------- Initialization -----------------------
			if(StatusManager == 6'b0) begin //initializing
				if(ETH_Init_Done) begin
					StatusManager <= 6'b010000;
				end
			end
			else if(StatusManager == 6'b010000) begin //read PC REQ or get num_node
				if(PC_REQ_NEW) begin
					StatusManager <= 6'b000001;
				end
				if(Node_Set) begin
					StatusManager <= HubMode ? 6'b100011:6'b110000;
				end
			end
			else if(StatusManager == 6'b000001) begin//TX REQ through Firewire
				if(PC_REQ_TXed) begin
					StatusManager <= 6'b000100;
					timeout_count <= 0;
				end
			end
			else if(StatusManager == 6'b000100) begin//waiting for ACK
				if(ACK_RXed) begin
					if(ACK_RESP == `ACK_DONE) begin// it is a write cmd
						StatusManager <= 6'b010000;
						timeout_count <= 0;
					end
					else if(ACK_RESP == `ACK_PEND) begin// it is a read cmd and wait for respond
						StatusManager <= 6'b000110;
						timeout_count <= 0;
					end
					else begin							// some error occurred
						StatusManager <= 6'b010000;
						timeout_count <= 0;
					end
				end
				else if(timeout_count == 12'hFFF) begin
					StatusManager <= 6'b010000;
					timeout_count <= 0;
				end
				else
					timeout_count <= timeout_count + 1;					
			end
			else if(StatusManager == 6'b000110) begin//waiting for response
				if(RESP_RXed) begin
					StatusManager <= 6'b011000;
					timeout_count <= 0;
				end
				else if(timeout_count == 12'hFFF) begin
					StatusManager <= 6'b010000;
					timeout_count <= 0;
				end
				else
					timeout_count <= timeout_count + 1;
			end
			else if(StatusManager == 6'b011000) begin// TX response back to PC
				if(Trans_Done) begin
					StatusManager <= 6'b010000;
				end
			end
		//------------------- End of Initialization -------------------
		//-------------------------------------------------------------
		//---------------------- PC Command Mode ----------------------
		// 1. Init
		// 2. Synchronize num_node
		// 3. Read PC request from Ethernet
		// 4. Transmit PC request through firewire
		// 5. Read ACK
		// 6. (ACK == PEND) Wait for data / ACK == Done, goto step 2
		// 7. Transmit data back to PC, goto step 2
		//-------------------------------------------------------------
			else begin
				if(!HubMode) begin
					if(StatusManager == 6'b110000) begin //read PC REQ or get num_node
						if(PC_REQ_NEW) begin
							StatusManager <= 6'b100001;
						end
					end
					else if(StatusManager == 6'b100001) begin//TX REQ through Firewire
						if(PC_REQ_TXed) begin
							StatusManager <= 6'b100100;
							timeout_count <= 0;
						end
					end
					else if(StatusManager == 6'b100100) begin//waiting for ACK
						if(ACK_RXed) begin
							if(ACK_RESP == `ACK_DONE) begin// it is a write cmd
								StatusManager <= 6'b110000;
								timeout_count <= 0;
							end
							else if(ACK_RESP == `ACK_PEND) begin// it is a read cmd and wait for respond
								StatusManager <= 6'b100110;
								timeout_count <= 0;
							end
							else begin							// some error occurred
								StatusManager <= 6'b110000;
								timeout_count <= 0;
							end
						end
						else if(timeout_count == 12'hFFF) begin
							StatusManager <= 6'b110000;
							timeout_count <= 0;
						end
						else
							timeout_count <= timeout_count + 1;					
					end
					else if(StatusManager == 6'b100110) begin//waiting for response
						if(RESP_RXed) begin
							StatusManager <= 6'b111000;
							timeout_count <= 0;
						end
						else if(timeout_count == 12'hFFF) begin
							StatusManager <= 6'b110000;
							timeout_count <= 0;
						end
						else
							timeout_count <= timeout_count + 1;
					end
					else if(StatusManager == 6'b111000) begin// TX response back to PC
						if(Trans_Done) begin
							StatusManager <= 6'b110000;
						end
					end
				end
		//---------------------- End of PC Command Mode ----------------------
		//--------------------------------------------------------------------
		//-------------------------- Broadcast Mode --------------------------
		// 1. Init
		// 2. Synchronize num_node
		// 3. Transmit BC request
		// 4. Wait for ACK sent by node0
		// 5. Read data from each node (num_node)
		// 6. Send whole packet to PC, goto step 2
		//--------------------------------------------------------------------
				else begin
					if(StatusManager == 6'b100011) begin // send BC_REQ from HUB to nodes
						if(BC_REQ_TXed) begin
							StatusManager <= 6'b100101;
						end
					end
					else if(StatusManager == 6'b100101) begin
						if(ACK_RXed) begin
							if(ACK_RESP == `ACK_DONE) begin// BC respond will follow
								StatusManager <= 6'b100111; // 101111: fast mode, 100111: normal mode
								BC_Packet_Count <= 0;//reset the counter
							end
							else							// some error occurred
								StatusManager <= 6'b100000;					
						end
					end
					// --- normal mode ---
					else if(StatusManager == 6'b100111) begin
						if(BC_RESP_RXed) begin
							if(BC_Packet_Count == num_node-1'b1) begin
								BC_Packet_Count <= 0;
								StatusManager <= 6'b101000;
							end
							else
								BC_Packet_Count <= BC_Packet_Count + 1;
						end
					end
					else if(StatusManager == 6'b101000) begin
						if(Trans_Done) begin
							StatusManager <= 6'b100011;
						end
					end
					// --- fast mode ---
					else if(StatusManager == 6'b101111) begin
						if(Trans_Done) begin
							StatusManager <= 6'b100011;
						end
					end
				end
		//---------------------- End of Broadcast Mode ----------------------
			end
		end
	end




// --------------------------------------------------------------------------
// Hub RAM Memory: 32-bit memory, 11-bit address
// --------------------------------------------------------------------------
	
// RAM settings: Port A is for Ethernet module, Port B for Firewire
    wire wea, web;				//write enable
    wire[10:0] addra,addrb;
	wire[31:0] dina,douta,dinb,doutb;
	
	Hub_Mem BlockMem(
		.clka(sysclk),       
		.wea(wea),
		.addra(addra),
		.dina(dina),
		.douta(douta),
		.clkb(sysclk),
		.web(web),
		.addrb(addrb),
		.dinb(dinb),
		.doutb(doutb)
	);


// --------------------------------------------------------------------------
// Firewire driver
// --------------------------------------------------------------------------
	
	// link request prameters
	wire lreq_trig;
    wire[2:0] lreq_type;
	
	// phy-link interface
	PhyLinkInterface phy(
		.sysclk(sysclk),         		// in: global clk  
		.reset(RSTN),					// in: global reset
		.board_id(~wenid),       		// in: board id (rotary switch)
		.ctl_ext(ctl),           		// bi: phy ctl lines
		.data_ext(data),         		// bi: phy data lines
		.reg_wen(wea),       			// out: reg write signal
		
		.reg_addr(addra),     			// out: register address
		.reg_rdata(douta),   			// in:  read data to external register
		.reg_wdata(dina),   			// out: write data to external register

		.lreq_trig(lreq_trig),   		// out: phy request trigger
		.lreq_type(lreq_type),   		// out: phy request type

		.PC_REQ_LEN(PC_REQ_LEN),		// in:  length of PC request
		.RESP_DATA_LEN(RESP_DATA_LEN),	// out: length of response
		
		.PC_REQ_TXed(PC_REQ_TXed),		// out: trigger for PC request transmitted
		.BC_REQ_TXed(BC_REQ_TXed),		// out: trigger for BC request transmitted
		.ACK_RXed(ACK_RXed),			// out: trigger for ACK received
		.ACK_RESP(ACK_RESP),			// out: type of ACK
		.RESP_RXed(RESP_RXed),			// out: trigger for response received
		.BC_RESP_RXed(BC_RESP_RXed),	// out: trigger for each BC response received
		
		.StatusManager(StatusManager)	// in:  current procedual status
	);


	// phy request module
	PhyRequest phyreq(
		.sysclk(sysclk),          // in: global clock
		.reset(RSTN),             // in: reset
		.lreq(lreq),              // out: phy request line
		.trigger(lreq_trig),      // in: phy request trigger
		.rtype(lreq_type)         // in: phy request type
	);




// --------------------------------------------------------------------------
// Ethetnet Connection Part
// --------------------------------------------------------------------------
// --------------------------------------------------------------------------
// Ethetnet Register Module
// --------------------------------------------------------------------------

	wire[3:0] stateReg;		// the state of ksz8851 registers
	wire[15:0] readData, writeData; // data communication with Hub
	wire[7:0] offset;		// address offset
	RegIO IOWR(
		.sysclk(sysclk),
		.reset(RSTN),
		.CMD(CMD),
		.RDN(RDN),
		.WRN(WRN),
		.SD(SD),
		.WR(WR),					// in: 1-Write, 0-Read
		.offset(offset),
		.length(length),			// in: length=0:byte, length=1:word
		.writeData(writeData),	
		.readData(readData),
		.NewCommand(NewCommand),	// in: "trigger" for new register access command
		.Dummy_Write(Dummy_Write),	// in: for ETH packet TX
		.Dummy_Read(Dummy_Read),	// in: for ETH packet RX
		.state(stateReg)			// out: state of ksz8851 registers
    );

// --------------------------------------------------------------------------
// Ethetnet Initialization Module
// --------------------------------------------------------------------------
	wire initlength, initWR, initNewCommand;
	wire[7:0] initoffset;
	wire[15:0] initwriteData;
	wire[10:0] init_addrb;			// useless, for MUX
	Initialization Init(
		.sysclk(sysclk),
		.reset(RSTN),
		.offset(initoffset),
		.length(initlength),
		.WR(initWR),
		.writeData(initwriteData),
		.readData(readData),
		.NewCommand(initNewCommand),
		.state(stateReg),			// in: state of ksz8851 registers
		.ETH_Init_Done(ETH_Init_Done)		// out: trigger for initialization completion
	);

// --------------------------------------------------------------------------
// Ethetnet Transmission Module
// --------------------------------------------------------------------------
	
	wire translength, transWR, transNewCommand;
	wire[7:0] transoffset;
	wire[15:0] transwriteData;
	wire[10:0] trans_addrb;
	
	// state of transmission
	// 2'b00: waiting
	// 2'b01: operating
	// 2'b10: finished
	wire[1:0] transmitStatus;
	

	Transmission_Normal TransN(
		.sysclk(sysclk),
		.reset(RSTN),
		// register access parameters
		.offset(transoffset),
		.length(translength),
		.WR(transWR),
		.writeData(transwriteData),
		.readData(readData),
		.NewCommand(transNewCommand),
		.Dummy_Write(Dummy_Write),
		.state(stateReg),
		.transmitStatus(transmitStatus),
		// Hub RAM
		.mem_addr(trans_addrb),
		.mem_rdata(doutb),
		
		.Trans_Done(Trans_Done),		// out: trigger for completion
		.RESP_DATA_LEN(RESP_DATA_LEN),	// in: length of response (needed to be transmitted to PC)
		.StatusManager(StatusManager),	// in: current procedual status
		.num_node(num_node)				// in: number of nodes
	);
	
	// parallel acceleration
//	Transmission_Parallel TransP(
//		.sysclk(sysclk),
//		.reset(RSTN),
//		// register access parameters
//		.offset(transoffset_parallel),
//		.length(translength_parallel),
//		.WR(transWR_parallel),
//		.writeData(transwriteData_parallel),
//		.readData(readData),
//		.NewCommand(transNewCommand_parallel),
//		.Dummy_Write(Dummy_Write_parallel),
//		.state(stateReg),
//		.transmitStatus(transmitStatus_parallel),
//		// Hub RAM
//		.mem_addr(trans_addrb_parallel),
//		.mem_rdata(doutb),
//		
//		.Trans_Done(Trans_Done_parallel),// out: trigger for completion
//		.RESP_DATA_LEN(RESP_DATA_LEN),	// in: length of response (needed to be transmitted to PC)
//		.StatusManager(StatusManager),	// in: current procedual status
//		.num_node(num_node),			// in: number of nodes
//		
//		// for acceleration
//		.BC_RESP_RXed(BC_RESP_RXed)
//	);
	
	
// --------------------------------------------------------------------------
// Ethetnet Reception Module
// --------------------------------------------------------------------------
	
	wire recvlength, recvWR, recvNewCommand;
	wire[7:0] recvoffset;
	wire[15:0] recvwriteData;
	wire[10:0] recv_addrb;
	
	// state of reception
	// 2'b00: waiting
	// 2'b01: operating
	// 2'b10: finished	
	wire[1:0] receiveStatus;
	
	Reception Recv(
		.sysclk(sysclk),
		.reset(RSTN),
		// register access parameters
		.offset(recvoffset),
		.length(recvlength),
		.WR(recvWR),
		.writeData(recvwriteData),
		.readData(readData),
		.NewCommand(recvNewCommand),
		.Dummy_Read(Dummy_Read),
		.state(stateReg),
		.receiveStatus(receiveStatus),
		//Hub RAM
		.mem_addr(recv_addrb),
		.mem_wen(web),
		.mem_wdata(dinb),
		
		.PC_REQ_NEW(PC_REQ_NEW),		// out: trigger: new PC request
		.Node_Set(Node_Set),			// out: trigger: num_node set
		.PC_REQ_LEN(PC_REQ_LEN),		// out: length of the request
		.StatusManager(StatusManager),	// in: current procedual status
		.num_node(num_node)
	);

// --------------------------------------------------------------------------
// Ethetnet Idle Parameters. for MUX only
// --------------------------------------------------------------------------
	wire idlelength, idleWR, idleNewCommand;
	wire[7:0] idleoffset;
	wire[15:0] idlewriteData;
	wire[10:0] idle_addrb;

// --------------------------------------------------------------------------
// MUXes
// --------------------------------------------------------------------------	

	// EthernetRegMaster: deciding which module has the control of ksz8851 registers
	// 2'b00: Init module
	// 2'b01: Transmit module
	// 2'b10: Receive module
	// 2'b11: Idle
	wire[1:0] EthernetRegMaster;
	EthRegMaster getMaster(
		.StatusManager(StatusManager),			// in: Top procedual status
		.EthernetRegMaster(EthernetRegMaster)	// out: Master of ksz8851 register
	);

	// MUX for address offset
	MUX8 offsetMUX(
		.wire0(initoffset),
		.wire1(transoffset),
		.wire2(recvoffset),
		.wire3(idleoffset),
		.ctl(EthernetRegMaster),
		.out(offset)
	);
	MUX1 lengthMUX(
		.wire0(initlength),
		.wire1(translength),
		.wire2(recvlength),
		.wire3(1'b1),
		.ctl(EthernetRegMaster),
		.out(length)
	);
	MUX1 WRMUX(
		.wire0(initWR),
		.wire1(transWR),
		.wire2(recvWR),
		.wire3(idleWR),
		.ctl(EthernetRegMaster),
		.out(WR)
	);
	MUX16 writeDataMUX(
		.wire0(initwriteData),
		.wire1(transwriteData),
		.wire2(recvwriteData),
		.wire3(idlewriteData),
		.ctl(EthernetRegMaster),
		.out(writeData)
	);
	MUX1 NewCommandMUX(
		.wire0(initNewCommand),
		.wire1(transNewCommand),
		.wire2(recvNewCommand),
		.wire3(idleNewCommand),
		.ctl(EthernetRegMaster),
		.out(NewCommand)
	);
	
	// MUX for hub RAM address(11-bit): 16-bit MUX is used here
	MUX16 AddrbMUX(
		.wire0(init_addrb),
		.wire1(trans_addrb),
		.wire2(recv_addrb),
		.wire3(idle_addrb),
		.ctl(EthernetRegMaster),
		.out(addrb)
	);
	

	
// --------------------------------------------------------------------------
// Chipscope module, for debugging
// --------------------------------------------------------------------------
	wire[35:0] ctrl;
	Hub_icon ICON(
		.CONTROL0(ctrl)
	);
	HUB_ila ILA(
		.CONTROL(ctrl),
		.CLK(sysclk),
		.TRIG0(ETH_Init_Done),		//1
		.TRIG1(PC_REQ_NEW),		//1
		.TRIG2(Node_Set),	//1
		.TRIG3(ACK_RXed),		//1
		.TRIG4(EthernetRegMaster),//4
		.TRIG5(ACK_RESP),		//4
		.TRIG6({receiveStatus,transmitStatus}),//4
		.TRIG7(stateReg),		//4
		.TRIG8(StatusManager),	//8
		.TRIG9(num_node),		//8
		.TRIG10(PC_REQ_LEN),	//8
		.TRIG11(RESP_DATA_LEN),	//8
		.TRIG12(addra),			//16
		.TRIG13(addrb),			//16
		.TRIG14(dinb),			//32
		.TRIG15(doutb)			//32
	);
	
endmodule


// --------------------------------------------------------------------------
// Ethernet Register Master
// --------------------------------------------------------------------------
module EthRegMaster(
	input[5:0] StatusManager,
	output wire[1:0] EthernetRegMaster
	);
	localparam [1:0] Init = 2'b00,
					 Transmit = 2'b01,
					 Receive = 2'b10,
					 Idle = 2'b11;

	assign EthernetRegMaster = (StatusManager == 6'b0) ? Init : (StatusManager[3] ? Transmit : (StatusManager[4] ? Receive : Idle));
endmodule
