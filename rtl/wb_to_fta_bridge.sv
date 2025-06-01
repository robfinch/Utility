`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2008-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// wb_to_fta_bridge.sv
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
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import fta_bus_pkg::*;

module wb_to_fta_bridge(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, err_o, we_i, sel_i, adr_i, dat_i, dat_o, fta_o);
parameter WID=256;
parameter RETRIES=100;
parameter CORENO = 6'd1;
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output reg ack_o;
output reg [2:0] err_o;
input we_i;
input [WID/8-1:0] sel_i;
input [31:0] adr_i;
input [WID-1:0] dat_i;
output reg [WID-1:0] dat_o;
fta_bus_interface.master fta_o;

reg [7:0] blen;
reg [31:0] src_adr, dst_adr;
reg [WID-1:0] data_hold;
reg cycd;
reg [9:0] rty_cnt;
reg cyc;
wire pe_cyc;
wire pe_cycx;

always_comb
	cyc = cyc_i & cs_i & ~fta_o.resp.stall;
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cyc), .pe(pe_cyc), .ne(), .ee());
pulse_extender(.clk_i(clk_i), .ce_i(1'b1), .cnt_i(4'd1), .i(pe_cyc), .o(pe_cycx), .no());

always_ff @(posedge clk_i)
begin
	cycd <= cyc_i & ~fta_o.resp.stall;
	if (fta_o.resp.rty)
		cycd <= 1'b0;
end

always_ff @(posedge clk_i)
if (rst_i)
	rty_cnt <= 10'd0;
else begin
	if (fta_o.resp.ack || !cyc)
		rty_cnt <= 10'd0;
	else if (fta_o.resp.rty) begin
		rty_cnt <= rty_cnt + 2'd1;
	end
end

always_ff @(posedge clk_i)
if (rst_i)
	err_o <= fta_bus_pkg::OKAY;
else begin
	if (cyc_i & ~cycd)
		err_o <= fta_bus_pkg::OKAY;
	if (rty_cnt==RETRIES)
		err_o <= fta_bus_pkg::ERR;
	if (!cyc_i)
		err_o <= fta_bus_pkg::OKAY;
end

typedef enum logic [1:0] 
{
	wait_state = 2'd0,
	access_state,
	access_ack_state,
	delay_state
} bus_state_e;
reg [3:0] bridge_state;

always_ff @(posedge clk_i)
if (rst_i) begin
	fta_o.req <= 1000'd0;
	ack_o <= LOW;
end
else begin
	fta_o.req <= 1000'd0;
	case(1'b1)
	bridge_state[wait_state]:
		begin
			ack_o <= LOW;
			dat_o <= {WID{1'd0}};
			fta_o.req.tid <= {CORENO,3'd0,4'd1};
			fta_o.req.cmd <= we_i ? fta_bus_pkg::CMD_STORE : fta_bus_pkg::CMD_LOAD;
			fta_o.req.we <= we_i;
			if (pe_cycx) begin
				case(adr_i)
				32'h7FFFFFF0,
				32'hBFFFFFF0:	
					if (we_i) src_adr <= dat_i[31:0];
					else begin
						dat_o <= {8{src_adr}};
					end
				32'h7FFFFFF4,
				32'hBFFFFFF4:
					if (we_i) dst_adr <= dat_i[31:0];
					else begin
						dat_o <= {8{dst_adr}};
					end
				32'h7FFFFFF8,
				32'hBFFFFFF8:
					if (we_i) blen <= dat_i[7:0];
					else begin
						dat_o <= {8{24'd0,blen}};
					end
				32'h7FFFFFFC,
				32'hBFFFFFFC:
					begin
						fta_o.req.blen <= blen;
						fta_o.req.cyc <= HIGH;
						fta_o.req.sel <= {WID/8{1'b1}};
						fta_o.req.adr <= we_i ? dst_adr : src_adr;
						fta_o.req.data1 <= dat_i;//data_hold;
					end
				default:
					begin
						fta_o.req.blen <= 8'd0;
						fta_o.req.cyc <= HIGH;
						fta_o.req.sel <= sel_i;
						fta_o.req.pv <= 1'b0;
						fta_o.req.adr <= adr_i;
						fta_o.req.data1 <= dat_i;
					end
				endcase
		// These are zero
		//		fta_o.req.bte <= fta_bus_pkg::LINEAR;
		//		fta_o.req.cti <= fta_bus_pkg::CLASSIC;
		 	end
		end

	bridge_state[delay_state]:
		ack_o <= HIGH;
		
	bridge_state[access_state]:
		if (we_i)
			ack_o <= HIGH;
		else if ((fta_o.resp.ack && fta_o.resp.tid=={CORENO,3'd0,4'd1}) || rty_cnt==RETRIES) begin
			if (fta_o.resp.adr==32'hBFFFFFFC || fta_o.resp.adr==32'h7FFFFFFC)
				data_hold <= fta_o.resp.dat;
			ack_o <= HIGH;
			dat_o <= fta_o.resp.dat;
		end
	endcase
end

always_ff @(posedge clk_i)
if (rst_i) begin
	bridge_state <= 4'd0;
	bridge_state[wait_state] <= 1'b1;
end
else begin
	bridge_state <= 4'd0;
	case(1'b1)
	bridge_state[wait_state]:
		if (pe_cycx)
			case(adr_i)
			32'h7FFFFFF0,
			32'hBFFFFFF0,
			32'h7FFFFFF4,
			32'hBFFFFFF4,
			32'h7FFFFFF8,
			32'hBFFFFFF8:
				if (we_i)
					bridge_state[delay_state] <= 1'b1;
				else
					bridge_state[delay_state] <= 1'b1;
			32'h7FFFFFFC,
			32'hBFFFFFFC:
				bridge_state[access_state] <= 1'b1;
			default:	bridge_state[access_state] <= 1'b1;
			endcase
		else
			bridge_state[wait_state] <= 1'b1;

	bridge_state[delay_state]:
		bridge_state[wait_state] <= 1'b1;
	
	bridge_state[access_state]:
		if (!cyc)
			bridge_state[wait_state] <= 1'b1;
		else if (we_i)
			bridge_state[wait_state] <= 1'b1;
		else if ((fta_o.resp.ack && fta_o.resp.tid=={CORENO,3'd0,4'd1}) || rty_cnt==RETRIES)
			bridge_state[wait_state] <= 1'b1;
		else
			bridge_state[access_state] <= 1'b1;
	default:
		bridge_state[wait_state] <= 1'b1;
	endcase
end

endmodule
