`timescale 1ns / 1ps
// ============================================================================
//
//        __
//   \\__/ o\    (C) 2007-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// counter.sv
// - generic up counter
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

module counter(rst, clk, ce, ld, d, q, tc);
parameter WID=8;
parameter pMaxCnt={WID{1'b1}};
input rst;
input clk;
input ce;
input ld;
input [WID:1] d;
output [WID:1] q;
reg [WID:1] q;
output tc;

assign tc = &q;

always_ff @(posedge clk)
if (rst)
	q <= 1'b0;
else if (ce) begin
	if (ld)
		q <= d;
	else if (tc)
		q <= {WID{1'b0}};
	else
		q <= q + 1'b1;
end

endmodule

module counter_ald(rst, clk, ce, ld, d, q, tc);
parameter WID=8;
parameter pMaxCnt={WID{1'b1}};
input rst;
input clk;
input ce;
input ld;
input [WID:1] d;
output [WID:1] q;
reg [WID:1] q;
output tc;

assign tc = &q;

always_ff @(posedge clk)
if (rst)
	q <= 1'b0;
else begin
	if (ld)
		q <= d;
	else if (ce) begin
		if (tc)
			q <= {WID{1'b0}};
		else
			q <= q + 1'b1;
	end
end

endmodule
