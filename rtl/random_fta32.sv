`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2011-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// random_fta32.sv
//     Multi-stream random number generator.
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
// 	Reg no.
//	00			read: random output bits [31:0], write: gen next number	
//  04           random stream number
//  08           m_z seed setting bits [31:0]
//  0C           m_w seed setting bits [31:0]
//
//
// 257 LUTs / 309 FFs / 2 BRAMs / 2 DSP
// ============================================================================
//
// Uses George Marsaglia's multiply method
//
// m_w = <choose-initializer>;    /* must not be zero */
// m_z = <choose-initializer>;    /* must not be zero */
//
// uint get_random()
// {
//     m_z = 36969 * (m_z & 65535) + (m_z >> 16);
//     m_w = 18000 * (m_w & 65535) + (m_w >> 16);
//     return (m_z << 16) + m_w;  /* 32-bit result */
// }
//
import fta_bus_pkg::*;

`define TRUE	1'b1
`define FALSE	1'b0

module random_fta32(cs_config_i, s_bus_i);
input cs_config_i;
fta_bus_interface.slave s_bus_i;
parameter pAckStyle = 1'b0;

parameter IO_ADDR = 32'hFEE10001;
parameter IO_ADDR_MASK = 32'hFFFF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd8;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = non VGA compatiable unclassfied device
parameter CFG_CLASS = 8'h00;						// 00 = unclassified
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;

fta_cmd_request32_t req;
fta_cmd_response32_t resp;

wire rst_i = s_bus_i.rst;
wire clk_i = s_bus_i.clk;
assign req = s_bus_i.req;
assign s_bus_i.resp = resp;

reg ack;
reg cs;
reg we;
reg [3:0] sel;
reg [31:0] adr;
reg [31:0] dat, dat_o;
reg cs_rand;
wire [31:0] cfg_out;
wire cs_io;

reg cs_config;
reg cs_io_id;
fta_cmd_request32_t reqd;
fta_cmd_response32_t cfg_resp,resp1;

always_comb
	cs_rand <= cs_io;
always_ff @(posedge clk_i)
	cs_config <= cs_config_i;
always_ff @(posedge clk_i)
	we <= req.we;
always_ff @(posedge clk_i)
	sel <= req.sel;
always_ff @(posedge clk_i)
	adr <= req.adr;
always_ff @(posedge clk_i)
	dat <= req.dat;
always_ff @(posedge clk_i)
	reqd <= req;

always_ff @(posedge clk_i)
	resp1.ack <= cs_rand & (~reqd.we || reqd.cti==fta_bus_pkg::ERC);
//vtdl #(.WID(6), .DEP(16)) urdyd3 (.clk(clk_i), .ce(1'b1), .a(4'd1), .d(req.cid), .q(resp.cid));
vtdl #(.WID($bits(fta_tranid_t)), .DEP(16)) urdyd4 (.clk(clk_i), .ce(1'b1), .a(4'd1), .d(req.tid), .q(resp1.tid));
vtdl #(.WID($bits(fta_address_t)), .DEP(16)) urdyd5 (.clk(clk_i), .ce(1'b1), .a(4'd1), .d(req.adr), .q(resp1.adr));
always_ff @(posedge clk_i)
if (rst_i)
	resp <= {$bits(fta_cmd_response32_t){1'b0}};
else begin
	resp.ack <= cfg_resp.ack ? 1'b1 : resp1.ack;
	resp.tid <= cfg_resp.ack ? cfg_resp.tid : resp1.tid;
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : resp1.adr;
	resp.next <= 1'b0;
	resp.stall <= 1'b0;
	resp.rty <= 1'b0;
	resp.err <= fta_bus_pkg::OKAY;
	resp.pri <= cfg_resp.ack ? cfg_resp.pri : 4'd7;
	resp.dat <= cfg_resp.ack ? cfg_resp.dat : dat_o;
end


//always @*
//	ack_o <= cs ? ack : pAckStyle;

ddbb32_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
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
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
ucfg1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.cs_i(cs_config),
	.irq_i(1'b0),
	.req_i(reqd),
	.resp_o(cfg_resp),
	.cs_bar0_o(cs_io),
	.cs_bar1_o(),
	.cs_bar2_o()
);


reg [9:0] stream;
reg [31:0] next_m_z;
reg [31:0] next_m_w;
reg [31:0] out;
reg wrw, wrz;
reg [31:0] w=32'd3,z=32'd17;
wire [31:0] m_zs;
wire [31:0] m_ws;
wire pe_we;

edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(we), .pe(pe_we), .ne(), .ee());
rand_ram u1 (clk_i, wrw, stream, w, m_ws);
rand_ram u2 (clk_i, wrz, stream, z, m_zs);

always_comb
begin
	next_m_z = (32'h36969 * m_zs[15:0]) + m_zs[31:16];
	next_m_w = (32'h18000 * m_ws[15:0]) + m_ws[31:16];
end

// Register read path
//
always_ff @(posedge clk_i)
if (cs_config)
	dat_o <= cfg_out;
else if (cs_rand)
	case(adr[3:2])
	2'd0:	dat_o <= {m_zs[15:0],16'd0} + m_ws;
	2'd1:	dat_o <= {22'h0,stream};
// Uncomment these for register read-back
//		3'd4:	dat_o <= m_z[31:16];
//		3'd5:	dat_o <= m_z[15: 0];
//		3'd6:	dat_o <= m_w[31:16];
//		3'd7:	dat_o <= m_w[15: 0];
	default:	dat_o <= 32'h0000;
	endcase
else
	dat_o <= 32'h0;

// Register write path
//
always_ff @(posedge clk_i)
begin
	wrw <= `FALSE;
	wrz <= `FALSE;
	if (cs_rand) begin
		if (we)
			case(adr[3:2])
			2'd0:
				begin
					z <= next_m_z;
					w <= next_m_w;
					wrw <= `TRUE;
					wrz <= `TRUE;
				end
			2'd1:	stream <= dat[9:0];
			2'd2:	begin z <= dat; wrz <= `TRUE; end
			2'd3:	begin w <= dat; wrw <= `TRUE; end
			endcase
	end
end

endmodule


// Tools were inferring a massive distributed ram so we help them out a bit by
// creating an explicit ram definition.

module rand_ram(clk, wr, ad, i, o);
input clk;
input wr;
input [9:0] ad;
input [31:0] i;
output [31:0] o;

reg [31:0] ri;
reg [9:0] regadr;
reg regwr;
(* RAM_STYLE="BLOCK" *)
reg [31:0] mem [0:1023];

always_ff @(posedge clk)
	regadr <= ad;
always_ff @(posedge clk)
	regwr <= wr;
always_ff @(posedge clk)
	ri <= i;
always_ff @(posedge clk)
	if (regwr)
		mem[regadr] <= ri;
assign o = mem[regadr];

endmodule
