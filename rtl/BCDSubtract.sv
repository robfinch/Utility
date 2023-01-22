`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	BCDSubtract.sv
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

module BCDSubtract(clk, a, b, o, sgn);
parameter N=25;
input clk;
input [N*4-1:0] a;
input [N*4-1:0] b;
output reg [N*4-1:0] o;
output reg sgn;

wire [(N)*4-1:0] bc;
wire [(N)*4-1:0] o1, o2, o3;
wire c;

BCDNinesComplementN #(N) u1 (.i({4'h0,b}), .o(bc));
BCDAddNClk #(.N(N)) u2 (.clk(clk), .a({8'h00,a}), .b(bc), .o(o1), .ci(1'b0), .co(c));
BCDNinesComplementN #(N) u3 (.i(o1), .o(o2));
BCDAddNClk #(.N(N)) u4 (.clk(clk), .a(o1), .b('d0), .o(o3), .ci(c), .co());

always_ff @(posedge clk)
	if (c)
		o <= o3;
	else
		o <= o2;
always_ff @(posedge clk)
	sgn <= |o ? ~c : 1'b0;

endmodule

module BCDNinesComplement(i, o);
input [3:0] i;
output reg [3:0] o;

always_comb
	case(i)
	4'd0:	o = 4'd9;
	4'd1:	o = 4'd8;
	4'd2:	o = 4'd7;
	4'd3:	o = 4'd6;
	4'd4: o = 4'd5;
	4'd5:	o = 4'd4;
	4'd6:	o = 4'd3;
	4'd7:	o = 4'd2;
	4'd8:	o = 4'd1;
	4'd9:	o = 4'd0;
	4'd10:	o = 4'd9;
	4'd11:	o = 4'd8;
	4'd12:	o = 4'd7;
	4'd13:	o = 4'd6;
	4'd14:	o = 4'd5;
	4'd15:	o = 4'd4;
	endcase

endmodule

module BCDNinesComplementN(i, o);
parameter N=25;
input [N*4-1:0] i;
output [N*4-1:0] o;

genvar g;
generate begin : gNC
	for (g = 0; g < N; g = g + 1)
		BCDNinesComplement utc1 (i[g*4+3:g*4],o[g*4+3:g*4]);
end
endgenerate

endmodule

module BCDTensComplement(i, o);
input [3:0] i;
output reg [3:0] o;

always_comb
	case(i)
	4'd0:	o = 4'd0;
	4'd1:	o = 4'd9;
	4'd2:	o = 4'd8;
	4'd3:	o = 4'd7;
	4'd4: o = 4'd6;
	4'd5:	o = 4'd5;
	4'd6:	o = 4'd4;
	4'd7:	o = 4'd3;
	4'd8:	o = 4'd2;
	4'd9:	o = 4'd1;
	4'd10:	o = 4'd0;
	4'd11:	o = 4'd9;
	4'd12:	o = 4'd8;
	4'd13:	o = 4'd7;
	4'd14:	o = 4'd6;
	4'd15:	o = 4'd5;
	endcase

endmodule

module BCDTensComplementN(i, o);
parameter N=25;
input [N*4-1:0] i;
output [N*4-1:0] o;

genvar g;
generate begin : gTC
	for (g = 0; g < N; g = g + 1)
		BCDTensComplement utc1 (i[g*4+3:g*4],o[g*4+3:g*4]);
end
endgenerate

endmodule
