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
// 310 LUTs / 220 FFs              
// ============================================================================
//
import wishbone_pkg::*;

module wb_IOBridge256to32(rst_i, clk_i, s1_req, s1_resp, m_req, chresp);
parameter CHANNELS = 2;
parameter IDLE = 3'd0;
parameter WAIT_ACK = 3'd1;
parameter WAIT_NACK = 3'd2;
parameter WR_ACK = 3'd3;
parameter WR_ACK2 = 3'd4;
parameter ASYNCH = 1'b1;
parameter BUS_PROTOCOL = 0;
input rst_i;
input clk_i;
input wb_cmd_request256_t s1_req;
output wb_cmd_response256_t s1_resp;
output wb_cmd_request32_t m_req;
input wb_cmd_response32_t [CHANNELS-1:0] chresp;

wb_cmd_response256_t resp;

integer n1,n2;
reg [4:0] s1_a40;
reg [1:0] state;

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
	resp <= {$bits(fta_cmd_response256_t){1'b0}};
	state <= 2'd0;
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
		m_req.dat <= s1_req.dat >> {s1_a40[4:2],5'd0};
	else
		m_req.dat <= 32'd0;

	// Handle responses
	// There should only be one slave responding.
	if (BUS_PROTOCOL==1)
		resp <= {$bits(wb_cmd_response256_t){1'b0}};
	case(state)
	2'd0:
		begin
			if (BUS_PROTOCOL==0)
				state <= {1'b0,s1_req.cyc};
			for (n1 = 0; n1 < CHANNELS; n1 = n1 + 1) begin
				if (chresp[n1].ack & s1_req.cyc) begin	
					resp.ack <= chresp[n1].ack;
					resp.err <= chresp[n1].err;
					resp.rty <= chresp[n1].rty;
					resp.next <= chresp[n1].next;
					resp.stall <= chresp[n1].stall;
					resp.dat <= {8{chresp[n1].dat}};
					resp.tid <= chresp[n1].tid;
					resp.pri <= chresp[n1].pri;
				end
			end
		end
	2'd1:
		begin
			for (n1 = 0; n1 < CHANNELS; n1 = n1 + 1) begin
				resp.ack <= chresp[n1].ack;
				resp.err <= chresp[n1].err;
				resp.rty <= chresp[n1].rty;
				resp.next <= chresp[n1].next;
				resp.stall <= chresp[n1].stall;
				resp.dat <= {8{chresp[n1].dat}};
				resp.tid <= chresp[n1].tid;
				resp.pri <= chresp[n1].pri;
			end
			if (!s1_req.cyc) begin
				resp <= {$bits(wb_cmd_response256_t){1'b0}};
				state <= 2'd0;
			end
		end
	default:	state <= 2'd0;
	endcase
	
end

wire [CHANNELS-1:0] wr_en,rd_en;
reg [CHANNELS-1:0] rd;
wb_cmd_response32_t [CHANNELS-1:0] fifo_din;
wb_cmd_response32_t [CHANNELS-1:0] fifo_dout;
wire [CHANNELS-1:0] full, overflow, empty, valid,underflow;
wire [4:0] data_count [0:CHANNELS-1];
integer wh;

always_comb
begin
	wh = -1;
	rd = {CHANNELS{1'b0}};
	for (n2 = 0; n2 < CHANNELS; n2 = n2 + 1)
		if (valid[n2]) begin
			rd[n2] = !resp.ack & ~rst_i;
			wh = n2;
		end
end

always_comb
begin
	if (wh >= 0 && rd[wh] & ~empty[wh]) begin
		s1_resp.tid = fifo_dout[wh].tid;
		s1_resp.ack = fifo_dout[wh].ack;
		s1_resp.err = fifo_dout[wh].err;
		s1_resp.rty = 1'b0;
		s1_resp.next = 1'b0;
		s1_resp.stall = 1'b0;
		s1_resp.dat = {8{fifo_dout[wh].dat}};
		s1_resp.pri = 4'd8;
	end
	else
		s1_resp = resp;
end

genvar g;
generate begin : gMSIIrqFifo
	for (g = 0; g < CHANNELS; g = g + 1) begin
		assign rd_en[g] = rd[g];
		assign wr_en[g] = ~rst_i & chresp[g].ack && chresp[g].err==wishbone_pkg::IRQ;

		buf_msi_fifo32 inst_fifo (
		  .clk(clk_i),                // input wire clk
		  .srst(rst_i),              // input wire srst
		  .din(chresp[g]),             // input wire din
		  .wr_en(wr_en[g]),            // input wire wr_en
		  .rd_en(rd_en[g]),            // input wire rd_en
		  .dout(fifo_dout[g]),              // output wire [55 : 0] dout
		  .full(full[g]),              // output wire full
		  .overflow(overflow[g]),      // output wire overflow
		  .empty(empty[g]),            // output wire empty
		  .valid(valid[g]),            // output wire valid
		  .underflow(underflow[g]),    // output wire underflow
		  .data_count(data_count[g])  // output wire [4 : 0] data_count
		);
	end
end
endgenerate

endmodule

