import fta_bus_pkg::*;

module fta_bridge256to64(req256_i, resp256_o, req64_o, resp64_i);
input fta_cmd_request256_t req256_i;
output fta_cmd_response256_t resp256_o;
output fta_cmd_request64_t req64_o;
input fta_cmd_response64_t resp64_i;

reg szerr;

always_comb
begin
	szerr = 1'b0;
	req64_o.om = req256_i.om;
	req64_o.cmd = req256_i.cmd;
	req64_o.tid = req256_i.tid;
	req64_o.bte = req256_i.bte;
	req64_o.blen = req256_i.blen;
	req64_o.cti = req256_i.cti;
	req64_o.seg = req256_i.seg;
	req64_o.sz = req256_i.sz;
	req64_o.cyc = req256_i.cyc;
	req64_o.we = req256_i.we;
	req64_o.sel = 
		req256_i.sel[31:24]|req256_i.sel[23:16]|
		req256_i.sel[15:8]|req256_i.sel[7:0];
	req64_o.pv = req256_i.pv;
	req64_o.adr = req256_i.adr;
	case(req256_i.sel)
	32'h00000001:	req64_o.dat = {8{req256_i.data1[7:0]}};
	32'h00000002:	req64_o.dat = {8{req256_i.data1[15:8]}};
	32'h00000004:	req64_o.dat = {8{req256_i.data1[23:16]}};
	32'h00000008:	req64_o.dat = {8{req256_i.data1[31:24]}};
	32'h00000010:	req64_o.dat = {8{req256_i.data1[39:32]}};
	32'h00000020:	req64_o.dat = {8{req256_i.data1[47:40]}};
	32'h00000040:	req64_o.dat = {8{req256_i.data1[55:48]}};
	32'h00000080:	req64_o.dat = {8{req256_i.data1[63:56]}};
	32'h00000100:	req64_o.dat = {8{req256_i.data1[71:64]}};
	32'h00000200:	req64_o.dat = {8{req256_i.data1[79:72]}};
	32'h00000400:	req64_o.dat = {8{req256_i.data1[87:80]}};
	32'h00000800:	req64_o.dat = {8{req256_i.data1[95:88]}};
	32'h00001000:	req64_o.dat = {8{req256_i.data1[103:96]}};
	32'h00002000:	req64_o.dat = {8{req256_i.data1[111:104]}};
	32'h00004000:	req64_o.dat = {8{req256_i.data1[119:112]}};
	32'h00008000:	req64_o.dat = {8{req256_i.data1[127:120]}};
	32'h00010000:	req64_o.dat = {8{req256_i.data1[135:128]}};
	32'h00020000:	req64_o.dat = {8{req256_i.data1[143:136]}};
	32'h00040000:	req64_o.dat = {8{req256_i.data1[151:144]}};
	32'h00080000:	req64_o.dat = {8{req256_i.data1[159:152]}};
	32'h00100000:	req64_o.dat = {8{req256_i.data1[167:160]}};
	32'h00200000:	req64_o.dat = {8{req256_i.data1[175:168]}};
	32'h00400000:	req64_o.dat = {8{req256_i.data1[183:176]}};
	32'h00800000:	req64_o.dat = {8{req256_i.data1[191:184]}};
	32'h01000000:	req64_o.dat = {8{req256_i.data1[199:192]}};
	32'h02000000:	req64_o.dat = {8{req256_i.data1[207:200]}};
	32'h04000000:	req64_o.dat = {8{req256_i.data1[215:208]}};
	32'h08000000:	req64_o.dat = {8{req256_i.data1[223:216]}};
	32'h10000000:	req64_o.dat = {8{req256_i.data1[231:224]}};
	32'h20000000:	req64_o.dat = {8{req256_i.data1[239:232]}};
	32'h40000000:	req64_o.dat = {8{req256_i.data1[247:240]}};
	32'h80000000:	req64_o.dat = {8{req256_i.data1[255:248]}};
	32'h00000003:	req64_o.dat = {4{req256_i.data1[15:0]}};
	32'h0000000C:	req64_o.dat = {4{req256_i.data1[31:16]}};
	32'h00000030:	req64_o.dat = {4{req256_i.data1[47:32]}};
	32'h000000C0:	req64_o.dat = {4{req256_i.data1[63:48]}};
	32'h00000300:	req64_o.dat = {4{req256_i.data1[79:64]}};
	32'h00000C00:	req64_o.dat = {4{req256_i.data1[95:80]}};
	32'h00003000:	req64_o.dat = {4{req256_i.data1[111:96]}};
	32'h0000C000:	req64_o.dat = {4{req256_i.data1[127:112]}};

	32'h00030000:	req64_o.dat = {2{req256_i.data1[143:128]}};
	32'h000C0000:	req64_o.dat = {2{req256_i.data1[159:144]}};
	32'h00300000:	req64_o.dat = {2{req256_i.data1[175:160]}};
	32'h00C00000:	req64_o.dat = {2{req256_i.data1[191:176]}};
	32'h03000000:	req64_o.dat = {2{req256_i.data1[207:192]}};
	32'h0C000000:	req64_o.dat = {2{req256_i.data1[223:208]}};
	32'h30000000:	req64_o.dat = {2{req256_i.data1[239:224]}};
	32'hC0000000:	req64_o.dat = {2{req256_i.data1[255:240]}};
	
	32'h0000000F:	req64_o.dat = req256_i.data1[31:0];
	32'h000000F0:	req64_o.dat = req256_i.data1[63:32];
	32'h00000F00:	req64_o.dat = req256_i.data1[95:64];
	32'h0000F000:	req64_o.dat = req256_i.data1[127:96];
	32'h000F0000:	req64_o.dat = req256_i.data1[159:128];
	32'h00F00000:	req64_o.dat = req256_i.data1[191:160];
	32'h0F000000:	req64_o.dat = req256_i.data1[223:192];
	32'hF0000000:	req64_o.dat = req256_i.data1[255:224];

	32'h000000FF:	req64_o.dat = req256_i.data1[63:0];
	32'h0000FF00:	req64_o.dat = req256_i.data1[127:64];
	32'h00FF0000:	req64_o.dat = req256_i.data1[191:128];
	32'hFF000000:	req64_o.dat = req256_i.data1[255:192];
	default:	req64_o.dat = 'd0;
	endcase
	req64_o.pl = req256_i.pl;
	req64_o.pri = req256_i.pri;
	req64_o.cache = req256_i.cache;
	req64_o.csr = req256_i.csr;
	case(req256_i.sz)
	fta_bus_pkg::octa,
	fta_bus_pkg::hexi:
		szerr = 1'b1;
	default:	szerr = 1'b0;
	endcase
end

always_comb
begin
	resp256_o.tid = resp64_i.tid;
	resp256_o.pri = resp64_i.pri;
	resp256_o.stall = resp64_i.stall;
	resp256_o.next = resp64_i.next;
	resp256_o.ack = resp64_i.ack;
	resp256_o.err = resp64_i.err;
	resp256_o.rty = resp64_i.rty;
	resp256_o.dat = {4{resp64_i.dat}};
	resp256_o.adr = resp64_i.adr;
end

endmodule