import fta_bus_pkg::*;

module fta_bridge256to32(req256_i, resp256_o, req32_o, resp32_i);
input fta_cmd_request256_t req256_i;
output fta_cmd_response256_t resp256_o;
output fta_cmd_request32_t req32_o;
input fta_cmd_response32_t resp32_i;

reg szerr;

always_comb
begin
	szerr = 1'b0;
	req32_o.om = req256_i.om;
	req32_o.cmd = req256_i.cmd;
	req32_o.tid = req256_i.tid;
	req32_o.bte = req256_i.bte;
	req32_o.blen = req256_i.blen;
	req32_o.cti = req256_i.cti;
	req32_o.seg = req256_i.seg;
	req32_o.sz = req256_i.sz;
	req32_o.cyc = req256_i.cyc;
	req32_o.stb = req256_i.stb;
	req32_o.we = req256_i.we;
	req32_o.sel = 
		req256_i.sel[31:28]|req256_i.sel[27:24]|req256_i.sel[23:20]|req256_i.sel[19:16]|
		req256_i.sel[15:12]|req256_i.sel[11:8]|req256_i.sel[7:4]|req256_i.sel[3:0];
	req32_o.asid = req256_i.asid;
	req32_o.vadr = req256_i.vadr;
	req32_o.padr = req256_i.padr;
	case(req256_i.sel)
	32'h00000001:	req32_o.dat = {8{req256_i.data1[7:0]}};
	32'h00000002:	req32_o.dat = {8{req256_i.data1[15:8]}};
	32'h00000004:	req32_o.dat = {8{req256_i.data1[23:16]}};
	32'h00000008:	req32_o.dat = {8{req256_i.data1[31:24]}};
	32'h00000010:	req32_o.dat = {8{req256_i.data1[39:32]}};
	32'h00000020:	req32_o.dat = {8{req256_i.data1[47:40]}};
	32'h00000040:	req32_o.dat = {8{req256_i.data1[55:48]}};
	32'h00000080:	req32_o.dat = {8{req256_i.data1[63:56]}};
	32'h00000100:	req32_o.dat = {8{req256_i.data1[71:64]}};
	32'h00000200:	req32_o.dat = {8{req256_i.data1[79:72]}};
	32'h00000400:	req32_o.dat = {8{req256_i.data1[87:80]}};
	32'h00000800:	req32_o.dat = {8{req256_i.data1[95:88]}};
	32'h00001000:	req32_o.dat = {8{req256_i.data1[103:96]}};
	32'h00002000:	req32_o.dat = {8{req256_i.data1[111:104]}};
	32'h00004000:	req32_o.dat = {8{req256_i.data1[119:112]}};
	32'h00008000:	req32_o.dat = {8{req256_i.data1[127:120]}};
	32'h00010000:	req32_o.dat = {8{req256_i.data1[135:128]}};
	32'h00020000:	req32_o.dat = {8{req256_i.data1[143:136]}};
	32'h00040000:	req32_o.dat = {8{req256_i.data1[151:144]}};
	32'h00080000:	req32_o.dat = {8{req256_i.data1[159:152]}};
	32'h00100000:	req32_o.dat = {8{req256_i.data1[167:160]}};
	32'h00200000:	req32_o.dat = {8{req256_i.data1[175:168]}};
	32'h00400000:	req32_o.dat = {8{req256_i.data1[183:176]}};
	32'h00800000:	req32_o.dat = {8{req256_i.data1[191:184]}};
	32'h01000000:	req32_o.dat = {8{req256_i.data1[199:192]}};
	32'h02000000:	req32_o.dat = {8{req256_i.data1[207:200]}};
	32'h04000000:	req32_o.dat = {8{req256_i.data1[215:208]}};
	32'h08000000:	req32_o.dat = {8{req256_i.data1[223:216]}};
	32'h10000000:	req32_o.dat = {8{req256_i.data1[231:224]}};
	32'h20000000:	req32_o.dat = {8{req256_i.data1[239:232]}};
	32'h40000000:	req32_o.dat = {8{req256_i.data1[247:240]}};
	32'h80000000:	req32_o.dat = {8{req256_i.data1[255:248]}};
	32'h00000003:	req32_o.dat = {4{req256_i.data1[15:0]}};
	32'h0000000C:	req32_o.dat = {4{req256_i.data1[31:16]}};
	32'h00000030:	req32_o.dat = {4{req256_i.data1[47:32]}};
	32'h000000C0:	req32_o.dat = {4{req256_i.data1[63:48]}};
	32'h00000300:	req32_o.dat = {4{req256_i.data1[79:64]}};
	32'h00000C00:	req32_o.dat = {4{req256_i.data1[95:80]}};
	32'h00003000:	req32_o.dat = {4{req256_i.data1[111:96]}};
	32'h0000C000:	req32_o.dat = {4{req256_i.data1[127:112]}};

	32'h00030000:	req32_o.dat = {2{req256_i.data1[143:128]}};
	32'h000C0000:	req32_o.dat = {2{req256_i.data1[159:144]}};
	32'h00300000:	req32_o.dat = {2{req256_i.data1[175:160]}};
	32'h00C00000:	req32_o.dat = {2{req256_i.data1[191:176]}};
	32'h03000000:	req32_o.dat = {2{req256_i.data1[207:192]}};
	32'h0C000000:	req32_o.dat = {2{req256_i.data1[223:208]}};
	32'h30000000:	req32_o.dat = {2{req256_i.data1[239:224]}};
	32'hC0000000:	req32_o.dat = {2{req256_i.data1[255:240]}};
	
	32'h0000000F:	req32_o.dat = req256_i.data1[31:0];
	32'h000000F0:	req32_o.dat = req256_i.data1[63:32];
	32'h00000F00:	req32_o.dat = req256_i.data1[95:64];
	32'h0000F000:	req32_o.dat = req256_i.data1[127:96];
	32'h000F0000:	req32_o.dat = req256_i.data1[159:128];
	32'h00F00000:	req32_o.dat = req256_i.data1[191:160];
	32'h0F000000:	req32_o.dat = req256_i.data1[223:192];
	32'hF0000000:	req32_o.dat = req256_i.data1[255:224];
	default:	req32_o.dat = 'd0;
	endcase
	req32_o.pl = req256_i.pl;
	req32_o.pri = req256_i.pri;
	req32_o.cache = req256_i.cache;
	req32_o.csr = req256_i.csr;
	case(req256_i.sz)
	fta_bus_pkg::octa,
	fta_bus_pkg::hexi:
		szerr = 1'b1;
	default:	szerr = 1'b0;
	endcase
end

always_comb
begin
	resp256_o.tid = resp32_i.tid;
	resp256_o.pri = resp32_i.pri;
	resp256_o.stall = resp32_i.stall;
	resp256_o.next = resp32_i.next;
	resp256_o.ack = resp32_i.ack;
	resp256_o.err = resp32_i.err;
	resp256_o.rty = resp32_i.rty;
	resp256_o.dat = {8{resp32_i.dat}};
	resp256_o.adr = resp32_i.adr;
end

endmodule