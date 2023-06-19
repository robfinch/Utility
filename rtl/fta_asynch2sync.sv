`timescale 1ns/1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
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

import fta_bus_pkg::*;

module fta_asynch2sync128(rst, clk, req_i, resp_o, req_o, resp_i);
input rst;
input clk;
input fta_cmd_request128_t req_i;
output fta_cmd_response128_t resp_o;
output fta_cmd_request128_t req_o;
input fta_cmd_response128_t resp_i;

reg aer_i;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	req_o <= 'd0;
	resp_o <= 'd0;
end
else begin
	aer_i <= resp_i.ack|resp_i.err|resp_i.rty;
	// If a cycle is pulsed, latch the request.
	if (req_i.cyc)
		req_o <= req_i;
	// On an ack, clear the request
	else if (resp_i.ack|resp_i.err|resp_i.rty)
		req_o <= 'd0;
	// On an ack, pulse the ack response
	if ((resp_i.ack|resp_i.err|resp_i.rty) & ~aer_i)
		resp_o <= resp_i;
	else
		resp_o <= 'd0;
end

endmodule
