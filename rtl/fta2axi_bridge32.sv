`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Supports only CLASSIC WISHBONE cycles.
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import axi4_pkg::*;

module fta2axi_bridge32(rst, clk, s_fta, m_axi);
parameter IRQ_DAT = 32'hFFFFFFF0;		// data sent in IRQ message
input rst;
input clk;
fta_bus_interface.slave s_fta;
axi4_interface.master m_axi;

fta_cmd_request32_t reqh;
reg irq;
wire pe_irq;
reg wb_cyc;
reg wb_stb;
wire pe_wbk_ack;

edge_det uack1 (.rst(rst), .clk(clk), .ce(1'b1), .i(wb_ack_i & ~wb_stall_i), .pe(pe_wb_ack), .ne(), .ee());
edge_det uirq1 (.rst(rst), .clk(clk), .ce(1'b1), .i(irq_i), .pe(pe_irq), .ne(), .ee());

// Capture the FTA bus request and hold onto it.
// WISHBONE needs the signals present until an ack.
always_ff @(posedge clk)
if (rst)
	reqh <= {$bits(fta_cmd_request32_t){1'b0}};
else begin
	if (req.cyc)
		reqh <= req;
	else if (wb_ack_i)
		reqh <= {$bits(fta_cmd_request32_t){1'b0}};
end

// AXI write address channel
// Write address controls are held until awready is seen.
always_ff @(posedge clk)
if (s_fta.req.cyc)
	m_axi.wac.awlen <= {2'b00,s_fta.req.blen};
else if (m_axi.wrc.awready)
	m_axi.wac.awlen <= 8'd0;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	m_axi.wac.awaddr <= s_fta.req.adr;
else if (m_axi.wrc.awready)
	m_axi.wac.awaddr <= {$bits(m_axi.wac.awaddr){1'b0}};
always_ff @(posedge clk)
if (s_fta.req.cyc)
	case(s_fta.req.sz)
	fta_bus_pkg::byt:		m_axi.wac.awsize <= _1B;
	fta_bus_pkg::wyde:	m_axi.wac.awsize <= _2B;
	fta_bus_pkg::tetra:	m_axi.wac.awsize <= _4B;
	fta_bus_pkg::octa:	m_axi.wac.awsize <= _8B;
	fta_bus_pkg::hexi:	m_axi.wac.awsize <= _16B;
	fta_bus_pkg::dhexi:	m_axi.wac.awsize <= _32B;
	default:	m_axi.wac.awsize <= _32B;
	endcase
else if (m_axi.wrc.awready)
	m_axi.wac.awsize <= _1B;
always_ff @(posedge clk)
if (s_fta.req.cyc) begin
	m_axi.wac.awburst <= axi4_pkg::INCR;
	if (s_fta.req.cti==fta_bus_pkg::FIXED)
		m_axi.wac.awburst <= axi4_pkg::FIXED;
	else if (s_fta.req.cti==fta_bus_pkg::INCR)
		m_axi.wac.awburst <= axi4_pkg::INCR;
	else if (s_fta.req.bte != fta_bus_pkg::LINEAR)
		m_axi.wac.awburst <= axi4_pkg::WRAP;
end
else if (m_axi.wrc.awready)
	m_axi.wac.awburst <= axi4_pkg::INCR;
always_ff @(posedge clk)
	m_axi.wac.awcache <= 4'd0;
always_ff @(posedge clk)
if (s_fta.req.cyc) begin
	m_axi.wac.awprot.i <= s_fta.req.seg==fta_bus_pkg::CODE;
	m_axi.wac.awprot.ns <= 1'b1;
	m_axi.wac.awprot.p <= 1'b0;
end
else if (m_axi.wrc.awready)
	m_axi.wac.awprot <= 3'b010;
always_ff @(posedge clk)
if (s_fta.req.cyc) begin
	m_axi.wac.awid.core <= s_fta.req.tid.core;
	m_axi.wac.awid.channel <= s_fta.req.tid.channel;
	m_axi.wac.awid.tranid <= s_fta_req.tid.tranid;
end
else if (m_axi.wrc.awready)
	m_axi.wac.awid <= {$bits(m_axi.wac.awid){1'b0}};
always_comb
	m_axi.wac.awlock = 1'b0;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	m_axi.wac.awqos <= s_fta.req.pri;
else if (m_axi.wrc.awready)
	m_axi.wac.awqos <= 4'd15;
always_comb
	m_axi.wac.awregion = 4'd0;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	m_axi.wac.awvalid <= s_fta.req.cyc;
else if (m_axi.wrc.awready)
	m_axi.wac.awvalid <= LOW;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	m_axi.wac.bready <= s_fta.req.cyc;
else if (m_axi.wrc.bvalid)
	m_axi.wac.bready <= LOW;

// AXI write data channel
reg [$bits(s_fta.req.data1)-1:0] wdata;
reg [$bits(s_fta.req.sel)-1] wstb;
reg wvalid;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	wdata <= s_fta.req.data1;
always_ff @(posedge clk)
if (m_axi.wrc.wready)
	m_axi.wdc.wdata <= wdata;
else
	m_axi.wdc.wdata <= {$bits(m_axi.wdc.wdata){1'b0}};
always_ff @(posedge clk)
if (s_fta.req.cyc)
	wstb <= s_fta.req.sel;
always_ff @(posedge clk)
if (m_axi.wrc.wready)
	m_axi.wdc.wstrb <= wstb;
else
	m_axi.wdc.wstrb <= {$bits(s_fta.req.sel){1'b0}};
always_ff @(posedge clk)
if (m_axi.wrc.wready)
	m_axi.wdc.wlast <= 1'b1;
else
	m_axi.wdc.wlast <= 1'b0;
always_ff @(posedge clk)
if (s_fta.req.cyc)
	wvalid <= HIGH;
else if (m_axi.wrc.wready)
	wvalid <= LOW;
always_ff @(posedge clk)
if (m_axi.wrc.wready)
	m_axi.wdc.wvalid <= wvalid;
else
	m_axi.wdc.wvalid <= LOW;

// AXI write response channel
always_ff @(posedge clk)
if (m_axi.wac.bready)
	s_fta.resp.tid <= m_axi.wrc.bid;
else
	s_fta.resp.tid <= {$bits(s_fta.resp.tid){1'b0}};
always_ff @(posedge clk)
if (m_axi.wac.bready)
	s_fta.resp.ack =
		m_axi.wrc.awready &
		m_axi.wrc.wready &
		m_axi.wrc.bvalid
		;
always_comb
	case(m_axi.wrc.bresp)
	axi4_pkg::OKAY:		s_fta.resp.err = fta_bus_pkg::OKAY;
	axi4_pkg::SLVERR:	s_fta.resp.err = fta_bus_pkg::ERR;
	axi4_pkg::DECERR:	s_fta.resp.err = fta_bus_pkg::DECERR;
	default:	s_fta.resp.err = fta_bus_pkg::OKAY;
	endcase

always_comb
	m_axi.rac.awaddr = s_fta.req.adr;

always_comb
	wb_bte_o = wishbone_pkg::LINEAR;
always_comb
	wb_cti_o = wishbone_pkg::CLASSIC;
always_comb
	wb_cyc_o = wb_cyc & ~wb_ack_i;
always_comb
	wb_stb_o = wb_cyc & ~wb_ack_i;
always_comb
	wb_we_o = reqh.we;
always_comb
	wb_sel_o = reqh.sel;
always_comb
	wb_adr_o = reqh.padr;
always_comb
	wb_dat_o = reqh.dat;

// Send an FTA response once WISHBONE has ack'd the request.
// FTA does not need a response for writes unless it is an ERC cycle.

always_ff @(posedge clk)
begin
	if (irq_i)
		irq <= HIGH;
	// Fill in null response
	resp = {$bits(fta_cmd_response32_t){1'b0}};
	if ((!reqh.we || reqh.cti==fta_bus_pkg::ERC) && pe_wb_ack) begin
		resp.ack <= HIGH;
		resp.err <= fta_bus_pkg::OKAY;
		resp.adr <= reqh.padr;
		resp.tid <= reqh.tid;
		resp.pri <= reqh.pri;
		resp.dat <= wb_dat_i;
	end
	else if (pe_irq) begin
		resp.ack <= HIGH;
		resp.err <= fta_bus_pkg::IRQ;
		resp.tid <= 13'd0;
		resp.pri <= 4'd7;
		resp.dat <= IRQ_DAT;
		irq <= LOW;
	end
	else if (irq) begin
		irq <= LOW;
		resp.ack <= HIGH;
		resp.err <= fta_bus_pkg::IRQ;
		resp.tid <= 13'd0;
		resp.pri <= 4'd7;
		resp.dat <= IRQ_DAT;
	end
end

endmodule
