`timescale 1ns / 10ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

import fta_bus_pkg::*;

module fta_respbuf128(rst, clk, resp, resp_o);
parameter CHANNELS = 8;
parameter WIDTH = 128;
localparam HBIT = $clog2(CHANNELS);
input rst;
input clk;
input fta_cmd_response128_t [CHANNELS-1:0] resp;
output fta_cmd_response128_t resp_o;

fta_cmd_response128_t [CHANNELS-1:0] respbuf [0:3];

reg [4:0] pri;
reg [HBIT:0] tmp, tndx;
reg [1:0] tmp2, t2ndx;
reg [1:0] chcnt [0:CHANNELS-1];

integer nn1, nn2, nn3, nn4;
integer crr;	// channel response ready.

always_comb
begin
	if (CHANNELS != 8 && CHANNELS != 4 && CHANNELS != 2) begin
		$display("fta_respbuf: CHANNELS should be one of 2, 4 or 8");
		$finish;
	end
end

// Search for channel with response ready. The search starts with a different
// channel each clock cycle. The start channel for the search increments so that
// channels placed on the output bus come from input in a circular fashion. This
// is to prevent one channel from hogging the bus. In a similar fashion which
// buffer is checked first rotates.
always_comb
begin
	crr = 1'd0;
	tmp2 = 'd0;
	pri = 5'h1F;
	tmp = {HBIT{1'b1}};
	for (nn1 = 0; nn1 < CHANNELS; nn1 = nn1 + 1) begin
		for (nn3 = 0; nn3 < 4; nn3 = nn3 + 1) begin
			if (respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].ack) begin
				if ($signed({1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri}) > $signed(pri)) begin
					tmp = nn1;
					tmp2 = nn3;
					pri = {1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri};
					crr = 1'b1;
				end
			end
		end
	end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	resp_o <= 'd0;
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		chcnt[nn2] <= 'd0;
		for (nn4 = 0; nn4 < 4; nn4 = nn4 + 1)
			respbuf[nn4][nn2] <= 'd0;
	end
	{tndx,t2ndx} <= 'd0;
end
else begin
	tndx <= tndx + 2'd1;
	if (tndx[HBIT-1:0]=='d0)
		t2ndx <= t2ndx + 2'd1;
	resp_o.ack <= 1'b0;
	resp_o.err <= fta_bus_pkg::OKAY;
	resp_o.rty <= 'd0;
	resp_o.dat <= 'd0;
	resp_o.tid <= 'd0;
	resp_o.adr <= 'd0;
	resp_o.stall <= 'd0;
	resp_o.next <= 'd0;
	resp_o.pri <= 4'hF;
	if (crr) begin
		respbuf[tmp2][tmp[HBIT-1:0]].ack <= 1'b0;
		resp_o.ack <= 1'b1;
		resp_o.err <= respbuf[tmp2][tmp[HBIT-1:0]].err;
		resp_o.rty <= respbuf[tmp2][tmp[HBIT-1:0]].rty;
		resp_o.dat <= respbuf[tmp2][tmp[HBIT-1:0]].dat;
		resp_o.tid <= respbuf[tmp2][tmp[HBIT-1:0]].tid;
		resp_o.adr <= respbuf[tmp2][tmp[HBIT-1:0]].adr;
		resp_o.pri <= respbuf[tmp2][tmp[HBIT-1:0]].pri;
	end
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		if (resp[nn2].ack) begin
			respbuf[chcnt[nn2]][nn2] <= resp[nn2];
			respbuf[chcnt[nn2]][nn2].ack <= 1'b1;
			chcnt[nn2] <= chcnt[nn2] + 1;
		end
	end
end

endmodule

module fta_respbuf64(rst, clk, resp, resp_o);
parameter CHANNELS = 8;
localparam HBIT = $clog2(CHANNELS);
input rst;
input clk;
input fta_cmd_response64_t [CHANNELS-1:0] resp;
output fta_cmd_response64_t resp_o;

fta_cmd_response64_t [CHANNELS-1:0] respbuf [0:3];

reg [4:0] pri;
reg [HBIT:0] tmp, tndx;
reg [1:0] tmp2, t2ndx;
reg [1:0] chcnt [0:CHANNELS-1];
integer nn1, nn2, nn3;
integer crr;

always_comb
	if (CHANNELS != 8 && CHANNELS != 4 && CHANNELS != 2) begin
		$display("fta_respbuf128: CHANNELS should be one of 2,4, or 8");
		$finish;
	end

// Search for channel with response ready.
always_comb
begin
	crr = 1'b0;
	tmp2 = 'd0;
	tmp = {HBIT+1{1'b1}};
	pri = 5'h1F;
	for (nn1 = 0; nn1 < CHANNELS; nn1 = nn1 + 1) begin
		for (nn3 = 0; nn3 < 4; nn3 = nn3 + 1) begin
			if (respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].ack) begin
				if ($signed({1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri}) > $signed(pri)) begin
					tmp = nn1;
					tmp2 = nn3;
					pri = {1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri};
					crr = 1'b1;
				end
			end
		end
	end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	resp_o <= 'd0;
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		chcnt[nn2] <= 'd0;
		respbuf[nn2] <= 'd0;		
	end
	{tndx,t2ndx} <= 'd0;
end
else begin
	tndx <= tndx + 2'd1;
	if (tndx[HBIT-1:0]=='d0)
		t2ndx <= t2ndx + 2'd1;
	resp_o.ack <= 1'b0;
	resp_o.err <= fta_bus_pkg::OKAY;
	resp_o.rty <= 'd0;
	resp_o.dat <= 'd0;
	resp_o.tid <= 'd0;
	resp_o.adr <= 'd0;
	resp_o.stall <= 'd0;
	resp_o.next <= 'd0;
	if (crr) begin
		respbuf[tmp2][tmp[HBIT-1:0]].ack <= 1'b0;
		resp_o.ack <= 1'b1;
		resp_o.err <= respbuf[tmp2][tmp[HBIT-1:0]].err;
		resp_o.rty <= respbuf[tmp2][tmp[HBIT-1:0]].rty;
		resp_o.dat <= respbuf[tmp2][tmp[HBIT-1:0]].dat;
		resp_o.tid <= respbuf[tmp2][tmp[HBIT-1:0]].tid;
		resp_o.adr <= respbuf[tmp2][tmp[HBIT-1:0]].adr;
		resp_o.pri <= respbuf[tmp2][tmp[HBIT-1:0]].pri;
	end
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		if (resp[nn2].ack) begin
			respbuf[chcnt[nn2]][nn2] <= resp[nn2];
			respbuf[chcnt[nn2]][nn2].ack <= 1'b1;
			chcnt[nn2] <= chcnt[nn2] + 1;
		end
	end
end

endmodule

module fta_respbuf32(rst, clk, resp, resp_o);
parameter CHANNELS = 8;
localparam HBIT = $clog2(CHANNELS);
input rst;
input clk;
input fta_cmd_response32_t [CHANNELS-1:0] resp;
output fta_cmd_response32_t resp_o;

fta_cmd_response32_t [CHANNELS-1:0] respbuf [0:3];

reg [4:0] pri;
reg [HBIT:0] tmp, tndx;
reg [1:0] tmp2, t2ndx;
reg [1:0] chcnt [0:CHANNELS-1];

integer nn1, nn2, nn3;
integer crr;

always_comb
	if (CHANNELS != 8 && CHANNELS != 4 && CHANNELS != 2) begin
		$display("fta_respbuf32: CHANNELS should be one of 2,4, or 8");
		$finish;
	end

// Search for channel with response ready.
always_comb
begin
	crr = 1'b0;
	tmp2 = 'd0;
	tmp = {HBIT+1{1'b1}};
	pri = 5'h1F;
	for (nn1 = 0; nn1 < CHANNELS; nn1 = nn1 + 1) begin
		for (nn3 = 0; nn3 < 4; nn3 = nn3 + 1) begin
			if (respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].ack) begin
				if ($signed({1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri}) > $signed(pri)) begin
					tmp = nn1;
					tmp2 = nn3;
					pri = {1'b0,respbuf[(nn1+tndx)%CHANNELS][(nn3+t2ndx)%4].pri};
					crr = 1'b1;
				end
			end
		end
	end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	resp_o <= 'd0;
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		chcnt[nn2] <= 'd0;
		respbuf[nn2] <= 'd0;		
	end
	{tndx,t2ndx} <= 'd0;
end
else begin
	tndx <= tndx + 2'd1;
	if (tndx[HBIT-1:0]=='d0)
		t2ndx <= t2ndx + 2'd1;
	resp_o.ack <= 1'b0;
	resp_o.err <= fta_bus_pkg::OKAY;
	resp_o.rty <= 'd0;
	resp_o.dat <= 'd0;
	resp_o.tid <= 'd0;
	resp_o.adr <= 'd0;
	resp_o.stall <= 'd0;
	resp_o.next <= 'd0;
	resp_o.pri <= 4'hF;
	if (crr) begin
		respbuf[tmp2][tmp[HBIT-1:0]].ack <= 1'b0;
		resp_o.ack <= 1'b1;
		resp_o.err <= respbuf[tmp2][tmp[HBIT-1:0]].err;
		resp_o.rty <= respbuf[tmp2][tmp[HBIT-1:0]].rty;
		resp_o.dat <= respbuf[tmp2][tmp[HBIT-1:0]].dat;
		resp_o.tid <= respbuf[tmp2][tmp[HBIT-1:0]].tid;
		resp_o.adr <= respbuf[tmp2][tmp[HBIT-1:0]].adr;
		resp_o.pri <= respbuf[tmp2][tmp[HBIT-1:0]].pri;
	end
	for (nn2 = 0; nn2 < CHANNELS; nn2 = nn2 + 1) begin
		if (resp[nn2].ack) begin
			respbuf[chcnt[nn2]][nn2] <= resp[nn2];
			respbuf[chcnt[nn2]][nn2].ack <= 1'b1;
			chcnt[nn2] <= chcnt[nn2] + 1;
		end
	end
end

endmodule

