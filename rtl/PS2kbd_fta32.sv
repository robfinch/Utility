`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2005-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	PS2kbd_fta32.v - PS2 compatible keyboard interface
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
//
//	PS2 compatible keyboard / mouse interface
//
//		This core provides a raw interface to the a PS2
//	keyboard or mouse. The interface is raw in the sense
//	that it doesn't do any scan code processing, it
//	just supplies it to the system. The core uses a
//	WISHBONE compatible bus interface.
//		Both transmit and recieve are
//	supported. It is possible to build the core without
//	the transmitter to reduce the size of the core; however
//	then it would not be possible to control the leds on
//	the keyboard. (The transmitter is required for a mouse
//	interface).
//		There is a 5us debounce circuit on the incoming
//	clock.
//		The transmitter does not have a watchdog timer, so
//	it may cause the keyboard to stop responding if there
//	was a problem with the transmit. It relys on the system
//	to reset the transmitter after 30ms or so of no
//	reponse. Resetting the transmitter should allow the
//	keyboard to respond again.
//	Note: keyboard clock must be at least three times slower
//	than the clk_i input to work reliably.
//	A typical keyboard clock is <30kHz so this should be ok
//	for most systems.
//	* There must be pullup resistors on the keyboard clock
//	and data lines, and the keyboard clock and data lines
//	are assumed to be open collector.
//		To read the keyboard, wait for bit 7 of the status
//	register to be set, then read the transmit / recieve
//	register. The receive register is cleared by writing a
//  zero to the status register.
//
//	Reg
//	0	keyboard transmit/receive register
//	1	status reg.		itk xxxx p
//		i = interrupt status
//		t = transmit complete
//		k = transmit acknowledge receipt (from keyboard)
//		p = parity error
//		A write to the status register clears the transmitter
//		state
//
//
//
//	Vivado Webpack 2022.2	XC7A200T
//	148 LUTs / 174 FFs
//
// ============================================================================
//	A good source of info:
//	http://panda.stb_i.ndsu.nodak.edu/~achapwes/PICmicro/PS2/ps2.htm
//	http://www.beyondlogic.org/keyboard/keybrd.htm
//
//	From the keyboard
//	1 start bit
//	8 data bits
//	1 parity bit
//	1 stop bit
//
// 	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|WISHBONE Datasheet
//	|WISHBONE SoC Architecture Specification, Revision B.3
//	|
//	|Description:						Specifications:
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|General Description:				PS2 keyboard / mouse interface
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Supported Cycles:					SLAVE,READ/WRITE
//	|									SLAVE,BLOCK READ/WRITE
//	|									SLAVE,RMW
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Data port, size:					8 bit
//	|Data port, granularity:			8 bit
//	|Data port, maximum operand size:	8 bit
//	|Data transfer ordering:			Undefined
//	|Data transfer sequencing:			Undefined
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Clock frequency constraints:		none
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Supported signal list and			Signal Name		WISHBONE equiv.
//	|cross reference to equivalent		ack_o			ACK_O
//	|WISHBONE signals					adr_i			ADR_I()
//	|									clk_i			CLK_I
//	|                                   cyc_i           CYC_I
//	|									dat_i(7:0)		DAT_I()
//	|									dat_o(7:0)		DAT_O()
//	|									stb_i			STB_I
//	|									we_i			WE_I
//	|
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Special requirements:
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//
//==================================================================

`define KBD_TX	1	// include transmitter

import fta_bus_pkg::*;

module PS2kbd_fta32(
	input cs_config_i,
	// SoC bus interface 
	fta_bus_interface.slave s_bus_i,
	//-------------
	input kclk_i,	// keyboard clock from keyboard
	output kclk_en,	// 1 = drive clock low
	input kdat_i,	// keyboard data
	output kdat_en	// 1 = drive data low
);
parameter pClkFreq = 40000000;
parameter pAckStyle = 1'b0;
parameter p5us = pClkFreq / 200000;		// number of clocks for 5us
parameter p100us = pClkFreq / 10000;	// number of clocks for 100us

parameter KBD_ADDR = 32'hFEDC0001;
parameter KBD_ADDR_MASK = 32'hFFFFE000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd30;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = Keyboard
parameter CFG_CLASS = 8'h09;						// 09 = input controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd00;

parameter CFG_IRQ_CORE = 6'd1;
parameter CFG_IRQ_CHANNEL = 3'd0;
parameter CFG_IRQ_PRIORITY = 4'd10;
parameter CFG_IRQ_CAUSE = 8'd0;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;

typedef enum logic [1:0] {
	S_KBDRX_WAIT_CLK = 2'd0,
	S_KBDRX_CHK_CLK_LOW	= 2'd1,
	S_KBDRX_CAPTURE_BIT = 2'd2
} kbd_state_t;

fta_cmd_request32_t req;
fta_cmd_response32_t resp;

wire rst_i = s_bus_i.rst;
wire clk_i = s_bus_i.clk;
assign req = s_bus_i.req;
assign s_bus_i.resp = resp;

reg cs_config;
reg [31:0] dat_o;
wire [31:0] kbd_addr;
reg [13:0] os;	// one shot
wire os_5us_done = os==p5us;
wire os_100us_done = os==p100us;
reg [10:0] q;	// receive register
reg tc;			// transmit complete indicator
kbd_state_t s_rx;	// keyboard receive state
reg [7:0] kq;
reg [15:0] kqc;
// Use majority logic for bit capture
// 4 or more bits high = 1, otherwise 0
wire [2:0] kqs = {2'b0,kq[0]}+
				{2'b0,kq[1]}+
				{2'b0,kq[2]}+
				{2'b0,kq[3]}+
				{2'b0,kq[4]}+
				{2'b0,kq[5]}+
				{2'b0,kq[6]};
wire kqcne;			// negative edge on kqc
wire kqcpe;			// positive edge on kqc
wire irq = ~q[0];
reg kack;			// keyboard acknowledge bit
`ifdef KBD_TX
reg [16:0] tx_state;	// transmitter states
reg klow;		// force clock line low
reg [10:0] t;	// transmit register
wire rx_inh = ~tc;	// inhibit receive while transmit occuring
reg [3:0] bitcnt;
wire shift_done = bitcnt==0;
reg tx_oe;			// transmitter output enable / shift enable
`else
wire rx_inh = 0;
`endif
wire [31:0] cfg_out;
wire irq_en;
reg irqa;
reg [5:0] irq_core;
reg [2:0] irq_channel;
reg [3:0] irq_priority;
reg [7:0] cause_code;
wire irq_cd;
reg irq_cdr;

// Register inputs
fta_cmd_request32_t reqd;
fta_cmd_response32_t cfg_resp;
reg we;
reg [3:0] sel;
reg [31:0] adr;
reg [31:0] dati;
always_ff @(posedge clk_i)
	we <= req.we;
always_ff @(posedge clk_i)
	sel <= req.sel;
always_ff @(posedge clk_i)
	adr <= req.adr;
always_ff @(posedge clk_i)
	dati <= req.dat;
always_ff @(posedge clk_i)
	reqd <= req;

reg cs_io;

always_ff @(posedge clk_i)
	cs_config <= cs_config_i;

wire cs_kbd;
always_comb
	cs_io = cs_kbd;

always_ff @(posedge clk_i)
	resp.ack <= cfg_resp.ack ? 1'b1 : cs_io ? reqd.cyc : irqa;
always_ff @(posedge clk_i)
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : cs_io ? reqd.adr : irqa ? {CFG_BUS,CFG_DEVICE,CFG_FUNC} : 32'd0;
always_ff @(posedge clk_i)
	resp.tid <= cfg_resp.ack ? cfg_resp.tid : cs_io ? reqd.tid : 13'd0;//irqa ? {irq_o[21:16],irq_o[14:12],4'd0} : 13'd0;	// core,channel
always_ff @(posedge clk_i)
	resp.err <= cfg_resp.ack ? cfg_resp.err : cs_io ? fta_bus_pkg::OKAY : irqa ? fta_bus_pkg::IRQ : fta_bus_pkg::OKAY;
always_ff @(posedge clk_i)
	resp.pri <= cfg_resp.ack ? cfg_resp.pri : cs_io ? 4'd5 : 4'd5;//irqa ? irq_o[11:8] : 4'd5;		// priority
always_ff @(posedge clk_i)
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : cs_io ? reqd.adr : irqa ? {CFG_BUS,CFG_DEVICE,CFG_FUNC} : 32'd0;
always_ff @(posedge clk_i)
	resp.dat <= cfg_resp.ack ? cfg_resp.dat : cs_io ? dat_o : 32'd0;//irqa ? {24'h00,irq_o[7:0]} : 32'd0;
assign resp.next = 1'b0;
assign resp.stall = 1'b0;
assign resp.rty = 1'b0;


ddbb32_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(KBD_ADDR),
	.CFG_BAR0_MASK(KBD_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_CORE(CFG_IRQ_CORE),
	.CFG_IRQ_CHANNEL(CFG_IRQ_CHANNEL),
	.CFG_IRQ_PRIORITY(CFG_IRQ_PRIORITY),
	.CFG_IRQ_CAUSE(CFG_IRQ_CAUSE)
)
ucfg1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.irq_i(irq),
	.cs_i(cs_config),
	.req_i(reqd), 
	.resp_o(cfg_resp),
	.cs_bar0_o(cs_kbd),
	.cs_bar1_o(),
	.cs_bar2_o()
);


// register read path
always_ff @(posedge clk_i)
if (cs_io)
	case(adr[4:2])
	3'd0:	dat_o <= {24'h0,q[8:1]};
	3'd1:	dat_o <= {24'h0,~q[0],tc,~kack,4'b0,~^q[9:1]};
	3'd2:	dat_o <= {24'h0,q[8:1]};
	3'd3:	dat_o <= {24'h0,~q[0],tc,~kack,4'b0,~^q[9:1]};
	default:	dat_o <= 32'd0;
	endcase
else
	dat_o <= 32'd0;

change_det #(1) ucd1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(irq), .cd(irq_cd));

always_comb
	if ((irq_cd|irq_cdr) & !(cs_io|cs_config))
		irqa = irq_en;
	else
		irqa = 1'b0;

always_ff @(posedge clk_i)
if (rst_i)
	irq_cdr <= 1'b0;
else begin
	if (irq_cd)
		irq_cdr <= 1'b1;
	if (irqa)
		irq_cdr <= 1'b0;
end

// Prohibit keyboard device from further transmits until
// this character has been processed.
// Holding the clock line low does this.
//assign kclk = irq ? 1'b0 : 1'bz;
`ifdef KBD_TX
// Force clock and data low during transmits
assign kclk_en = klow | irq;
assign kdat_en = tx_oe & ~t[0];// ? 1'b0 : 1'bz;
`else
assign kclk_en = irq;
`endif

// stabilize clock and data
always_ff @(posedge clk_i) begin
	kq <= {kq[6:0],kdat_i};
	kqc <= {kqc[14:0],kclk_i};
end

edge_det ed0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(kqc[10]), .pe(kqcpe), .ne(kqcne), .ee() );


// The debounce one-shot and 100us timer	
always @(posedge clk_i)
	if (rst_i)
		os <= 0;
	else begin
		if ((s_rx==S_KBDRX_WAIT_CLK && kqcne && ~rx_inh)||
			(s_rx==S_KBDRX_CHK_CLK_LOW && rx_inh)
`ifdef KBD_TX
			||tx_state[0]||tx_state[2]||tx_state[5]||tx_state[7]||tx_state[9]||tx_state[11]||tx_state[14]
`endif
			)
			os <= 0;
		else
			os <= os + 1;
	end


// Receive state machine
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		q <= 11'h7FF;
		s_rx <= S_KBDRX_WAIT_CLK;
	end
	else begin

		// clear rx on write to status reg
		if (cs_io && we && adr[4:2]==2'd1 && dati[7:0]==8'h00)
			q <= 11'h7FF;

		// Receive state machine
		case (s_rx)	// synopsys full_case parallel_case
		// negedge on kclk ?
		// then set debounce one-shot
		S_KBDRX_WAIT_CLK:
			if (kqcne && ~rx_inh)
				s_rx <= S_KBDRX_CHK_CLK_LOW;

		// wait 5us
		// check if clock low
		S_KBDRX_CHK_CLK_LOW:
			if (rx_inh)
				s_rx <= S_KBDRX_WAIT_CLK;
			else if (os_5us_done) begin
				// clock low ?
				if (~kqc[10])
					s_rx <= S_KBDRX_CAPTURE_BIT;
				else
					s_rx <= S_KBDRX_WAIT_CLK;	// no - spurious
			end

		// capture keyboard bit
		// keyboard transmits LSB first
		S_KBDRX_CAPTURE_BIT:
			begin
			q <= {kq[2],q[10:1]};
			s_rx <= S_KBDRX_WAIT_CLK;
			end

		default:
			s_rx <= S_KBDRX_WAIT_CLK;
		endcase
	end
end


`ifdef KBD_TX

// Transmit state machine
// a shift register / ring counter is used
reg adv_tx_state;			// advance transmitter state
reg start_tx;				// start the transmitter
reg clear_tx;				// clear the transmit state
always_ff @(posedge clk_i)
	if (rst_i)
		tx_state <= 0;
	else begin
		if (clear_tx)
			tx_state <= 0;
		else if (start_tx)
			tx_state[0] <= 1;
		else if (adv_tx_state) begin
			tx_state[6:0] <= {tx_state[5:0],1'b0};
			tx_state[7] <= (tx_state[8] && !shift_done) || tx_state[6];
			tx_state[8] <= tx_state[7];
			tx_state[9] <= tx_state[8] && shift_done;
			tx_state[16:10] <= tx_state[15:9];
		end
	end


// detect when to advance the transmit state
always_comb
	case (1'b1)		// synopsys parallel_case
	tx_state[0]:	adv_tx_state <= 1;
	tx_state[1]:	adv_tx_state <= os_100us_done;
	tx_state[2]:	adv_tx_state <= 1;
	tx_state[3]:	adv_tx_state <= os_5us_done;
	tx_state[4]:	adv_tx_state <= 1;
	tx_state[5]:	adv_tx_state <= kqcne;
	tx_state[6]:	adv_tx_state <= os_5us_done;
	tx_state[7]:	adv_tx_state <= kqcpe;
	tx_state[8]:	adv_tx_state <= os_5us_done;
	tx_state[9]:	adv_tx_state <= kqcpe;
	tx_state[10]:	adv_tx_state <= os_5us_done;
	tx_state[11]:	adv_tx_state <= kqcne;
	tx_state[12]:	adv_tx_state <= os_5us_done;
	tx_state[13]:	adv_tx_state <= 1;
	tx_state[14]:	adv_tx_state <= kqcpe;
	tx_state[15]:	adv_tx_state <= os_5us_done;
	default:		adv_tx_state <= 0;
	endcase

wire load_tx = cs_io && we && adr[3:2]==2'b0;
wire shift_tx = (tx_state[7] & kqcpe)|tx_state[4];

// It can take up to 20ms for the keyboard to accept data
// from the host.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		klow <= 0;
		tc <= 1;
		start_tx <= 0;
		tx_oe <= 0;
	end
	else begin

		clear_tx <= 0;
		start_tx <= 0;

		// write to keyboard register triggers whole thing
		if (load_tx) begin
			start_tx <= 1;
			tc <= 0;
		end
		// write to status register clears transmit state
		else if (cs_io && we && adr[4:2]==2'd1 && dati[7:0]==8'hFF) begin
			tc <= 1;
			tx_oe <= 0;
			klow <= 1'b0;
			clear_tx <= 1;
		end
		else begin

			case (1'b1)	// synopsys parallel_case

			tx_state[0]:	klow <= 1'b1;	// First step: pull the clock low
			tx_state[1]:	;				// wait 100 us (hold clock low)
			tx_state[2]:	tx_oe <= 1;		// bring data low / enable shift
			tx_state[3]:	;	// wait 5us
			// at this point the clock should go high
			// and shift out the start bit
			tx_state[4]:	klow <= 0;		// release clock line
			tx_state[5]:	;				// wait for clock to go low
			tx_state[6]:	;				// wait 5us
			// state7, 8 shift the data out
			tx_state[7]:	;				// wait for clock to go high
			tx_state[8]:	;				// wait 5us, go back to state 7
			tx_state[9]:	tx_oe <= 0;		// wait for clock to go high // disable transmit output / shift
			tx_state[10]:	;				// wait 5us
			tx_state[11]:	;				// wait for clock to go low
			tx_state[12]:	;				// wait 5us
			tx_state[13]:	kack <= kq[1];	// capture the ack_o bit from the keyboard
			tx_state[14]:	;				// wait for clock to go high
			tx_state[15]:	;				// wait 5us
			tx_state[16]:
				begin
					tc <= 1;		// transmit is now complete
					clear_tx <= 1;
				end

			default:	;

			endcase
		end
	end
end


// transmitter shift register
always_ff @(posedge clk_i)
	if (rst_i)
		t <= 11'd0;
	else begin
		if (load_tx)
			t <= {~(^dati[7:0]),dati[7:0],2'b0};
		else if (shift_tx)
			t <= {1'b1,t[10:1]};
	end


// transmitter bit counter
always_ff @(posedge clk_i)
	if (rst_i)
		bitcnt <= 4'd0;
	else begin
		if (load_tx)
			bitcnt <= 4'd11;
		else if (shift_tx)
			bitcnt <= bitcnt - 4'd1;
	end

`endif

endmodule
