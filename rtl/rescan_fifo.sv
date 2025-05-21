`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2008-2025  Robert Finch, Waterloo
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
// ============================================================================
//
module rescan_fifo(wrst, wclk, wr, din, rrst, rclk, rd, dout, cnt);
parameter WIDTH=128;
parameter DEPTH=256;
parameter pRamStyle = "auto";
input wrst;
input wclk;
input wr;
input [WIDTH-1:0] din;
input rrst;
input rclk;
input rd;
output [WIDTH-1:0] dout;
output [$clog2(DEPTH)-1:0] cnt;
reg [$clog2(DEPTH)-1:0] cnt;

/*
always_comb
if (DEPTH != ({15'd0,1'b1} << ($clog2(DEPTH)))) begin
	$display("rescan_fifo: DEPTH must be power of two");
	$finish;
end
*/
reg [$clog2(DEPTH)-1:0] wr_ptr;
reg [$clog2(DEPTH)-1:0] rd_ptr,rrd_ptr;
(* ram_style=pRamStyle *)
reg [WIDTH-1:0] mem [0:DEPTH-1];

wire [$clog2(DEPTH)-1:0] wr_ptr_p1 = wr_ptr + 2'd1;
wire [$clog2(DEPTH)-1:0] rd_ptr_p1 = rd_ptr + 2'd1;
reg [$clog2(DEPTH)-1:0] rd_ptrs;

always_ff @(posedge wclk)
	if (wrst)
		wr_ptr <= {$clog2(DEPTH){1'b0}};
	else if (wr) begin
		mem[wr_ptr] <= din;
		wr_ptr <= wr_ptr_p1;
	end
always_ff @(posedge wclk)		// synchronize read pointer to wclk domain
	rd_ptrs <= rd_ptr;

always_ff @(posedge rclk)
	if (rrst)
		rd_ptr <= {$clog2(DEPTH){1'b0}};
	else if (rd)
		rd_ptr <= rd_ptr_p1;
always_ff @(posedge rclk)
	rrd_ptr <= rd_ptr;

assign dout = mem[rrd_ptr[$clog2(DEPTH)-1:0]];

always_comb
	if (rd_ptrs > wr_ptr)
		cnt <= wr_ptr + (DEPTH - rd_ptrs);
	else
		cnt <= wr_ptr - rd_ptrs;

endmodule
