`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
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
// IOBridge256to32fta.v
//
// Adds FF's into the io path. This makes it easier for the place and
// route to take place. 
// Multiple devices are connected to the master port side of the bridge.
// The slave side of the bridge is connected to the cpu. The bridge looks
// like just a single device then to the cpu.
// The cost is an extra clock cycle to perform I/O accesses. For most
// devices which are low-speed it doesn't matter much.
//
// 401 LUTs / 276 FFs              
// ============================================================================
//
import fta_bus_pkg::*;

module IOBridge256to32fta(rst_i, clk_i, clk5x_i, s1_req, s1_resp, m_req, chresp );
parameter CHANNELS = 2;
parameter IDLE = 3'd0;
parameter WAIT_ACK = 3'd1;
parameter WAIT_NACK = 3'd2;
parameter WR_ACK = 3'd3;
parameter WR_ACK2 = 3'd4;
parameter ASYNCH = 1'b1;

input rst_i;
input clk_i;
input clk5x_i;
input fta_cmd_request256_t s1_req;
output fta_cmd_response256_t s1_resp;
output fta_cmd_request32_t m_req;
input fta_cmd_response32_t [CHANNELS-1:0] chresp;

fta_cmd_response32_t respo;

fta_respbuf32 #(CHANNELS) urespb1
(
	.rst(rst_i),
	.clk(clk_i),
	.clk5x(clk5x_i),
	.resp(chresp),
	.resp_o(respo)
);

reg [4:0] s1_a40;

always_comb
	case(s1_req.sel)
	32'h00000001:	s1_a40 = 5'h0;
	32'h00000002:	s1_a40 = 5'h1;
	32'h00000004:	s1_a40 = 5'h2;
	32'h00000008:	s1_a40 = 5'h3;
	32'h00000010:	s1_a40 = 5'h4;
	32'h00000020:	s1_a40 = 5'h5;
	32'h00000040:	s1_a40 = 5'h6;
	32'h00000080:	s1_a40 = 5'h7;
	32'h00000100:	s1_a40 = 5'h8;
	32'h00000200:	s1_a40 = 5'h9;
	32'h00000400:	s1_a40 = 5'hA;
	32'h00000800:	s1_a40 = 5'hB;
	32'h00001000:	s1_a40 = 5'hC;
	32'h00002000:	s1_a40 = 5'hD;
	32'h00004000:	s1_a40 = 5'hE;
	32'h00008000:	s1_a40 = 5'hF;
	32'h00010000:	s1_a40 = 5'h10;
	32'h00020000:	s1_a40 = 5'h11;
	32'h00040000:	s1_a40 = 5'h12;
	32'h00080000:	s1_a40 = 5'h13;
	32'h00100000:	s1_a40 = 5'h14;
	32'h00200000:	s1_a40 = 5'h15;
	32'h00400000:	s1_a40 = 5'h16;
	32'h00800000:	s1_a40 = 5'h17;
	32'h01000000:	s1_a40 = 5'h18;
	32'h02000000:	s1_a40 = 5'h19;
	32'h04000000:	s1_a40 = 5'h1A;
	32'h08000000:	s1_a40 = 5'h1B;
	32'h10000000:	s1_a40 = 5'h1C;
	32'h20000000:	s1_a40 = 5'h1D;
	32'h40000000:	s1_a40 = 5'h1E;
	32'h80000000:	s1_a40 = 5'h1F;
	
	32'h00000003:	s1_a40 = 5'h0;
	32'h0000000C:	s1_a40 = 5'h2;
	32'h00000030:	s1_a40 = 5'h4;
	32'h000000C0:	s1_a40 = 5'h6;
	32'h00000300:	s1_a40 = 5'h8;
	32'h00000C00:	s1_a40 = 5'hA;
	32'h00003000:	s1_a40 = 5'hC;
	32'h0000C000:	s1_a40 = 5'hE;
	32'h00030000:	s1_a40 = 5'h10;
	32'h000C0000:	s1_a40 = 5'h12;
	32'h00300000:	s1_a40 = 5'h14;
	32'h00C00000:	s1_a40 = 5'h16;
	32'h03000000:	s1_a40 = 5'h18;
	32'h0C000000:	s1_a40 = 5'h1A;
	32'h30000000:	s1_a40 = 5'h1C;
	32'hC0000000:	s1_a40 = 5'h1E;
	
	32'h0000000F:	s1_a40 = 5'h0;
	32'h000000F0: s1_a40 = 5'h4;
	32'h00000F00: s1_a40 = 5'h8;
	32'h0000F000:	s1_a40 = 5'hC;
	32'h000F0000:	s1_a40 = 5'h10;
	32'h00F00000: s1_a40 = 5'h14;
	32'h0F000000: s1_a40 = 5'h18;
	32'hF0000000:	s1_a40 = 5'h1C;

	32'h000000FF:	s1_a40 = 5'h0;
	32'h0000FF00:	s1_a40 = 5'h8;
	32'h00FF0000:	s1_a40 = 5'h10;
	32'hFF000000:	s1_a40 = 5'h18;

	32'h0000FFFF:	s1_a40 = 5'h0;
	32'hFFFF0000:	s1_a40 = 5'h10;
	32'hFFFFFFFF:	s1_a40 = 5'h0;
	default:	s1_a40 = 5'h0;
	endcase


always_ff @(posedge clk_i)
if (rst_i) begin
	m_req <= 'd0;
	m_req.adr <= 32'hFFFFFFFF;
	s1_resp <= {$bits(fta_cmd_response256_t){1'b0}};
end
else begin
  // Filter requests to the I/O address range
  if (s1_req.cyc) begin
    m_req.bte <= s1_req.bte;
    m_req.cti <= s1_req.cti;
    m_req.cmd <= s1_req.cmd;
    m_req.cyc <= 1'b1;
    m_req.tid <= s1_req.tid;
    m_req.adr <= s1_req.adr;
    m_req.adr[4:0] <= s1_a40;
//    m_req.sel <= s1_req.sel[15:8]|s1_req.sel[7:0];
    m_req.sel <= 
    	s1_req.sel[31:28]|s1_req.sel[27:24]|s1_req.sel[23:20]|s1_req.sel[19:16]|
    	s1_req.sel[15:12]|s1_req.sel[11:8]|s1_req.sel[7:4]|s1_req.sel[3:0];
    m_req.we <= s1_req.we;
  end
  else begin
  	m_req.cyc <= 1'd0;
  	m_req.we <= 1'd0;
  	m_req.sel <= 4'd0;
  	m_req.adr <= 32'hFFFFFFFF;
	end
  if (s1_req.cyc)
//		m_req.dat <= s1_req.data1 >> {|s1_req.sel[15:8],6'd0};
		m_req.dat <= s1_req.data1 >> {s1_a40[4:2],5'd0};
	else
		m_req.dat <= 32'd0;

	// Handle responses	
	s1_resp.ack <= respo.ack;
	s1_resp.err <= respo.err;
	s1_resp.rty <= respo.rty;
	s1_resp.next <= respo.next;
	s1_resp.stall <= respo.stall;
	s1_resp.dat <= {8{respo.dat}};
	s1_resp.tid <= respo.tid;
	s1_resp.adr <= respo.adr;
	s1_resp.pri <= respo.pri;
end

endmodule

