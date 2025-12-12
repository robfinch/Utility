// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
//
import wishbone_pkg::*;

module wb_ledport64(rst, clk, cs, req, resp, led);
input rst;
input clk;
input cs;
input wb_cmd_request64_t req;
output wb_cmd_response64_t resp;
output reg [7:0] led;

reg [28:0] count;
reg ff1;

always_ff @(posedge clk)
if (rst)
	count <= 29'd0;
else begin
	count <= count + 2'd1;
end

always_ff @(posedge clk)
if (rst)
	ff1 <= 1'b0;
else begin
	if (cs & req.we)
		ff1 <= 1'b1;	
end

always_ff @(posedge clk)
if (rst)
	led <= 'd0;
else begin
	if (ff1==1'b0)
		led <= {8{count[28]}};
	if (cs & req.we)
		led <= req.dat[7:0];
end

always_ff @(posedge clk)
if (rst)
	resp <= 'd0;
else begin
//	resp.cid <= req.cid;
	resp.tid <= req.tid;		
	resp.ack <= cs && (!req.we || req.cti==fta_bus_pkg::ERC);
	resp.err <= fta_bus_pkg::OKAY;
	resp.rty <= 1'd0;
	resp.pri <= 4'd7;
	resp.dat <= 64'd0;
end

endmodule
