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
import wishbone_pkg::*;

module fta2wb_bridge32(rst, clk, req, resp, irq_i,
	wb_bte_o, wb_cti_o, wb_cyc_o, wb_stb_o, wb_we_o, wb_sel_o, wb_adr_o, wb_dat_o, wb_dat_i, wb_ack_i, wb_stall_i,
);
parameter IRQ_DAT = 32'hFFFFFFF0;		// data sent in IRQ message
input rst;
input clk;
input fta_cmd_request32_t req;
output fta_cmd_response32_t resp;
output reg [2:0] wb_bte_o;
output reg [2:0] wb_cti_o;
output reg wb_cyc_o;
output reg wb_stb_o;
output reg wb_we_o;
output reg [3:0] wb_sel_o;
output reg [31:0] wb_adr_o;
output reg [31:0] wb_dat_o;
input [31:0] wb_dat_i;
input wb_ack_i;
input wb_stall_i;
input irq_i;

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

always_ff @(posedge clk)
if (rst)
	wb_cyc <= LOW;
else begin
	if (req.cyc)
		wb_cyc <= HIGH;
	else if (wb_ack_i)
		wb_cyc <= LOW;
end

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
