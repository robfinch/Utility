import wishbone_pkg::*;
import fta_bus_pkg::*;

module wb_to_fta_bridge(rst_i, clk_i, cyc_i, stb_i, ack_o, we_i, sel_i, adr_i, dat_i, dat_o, fta_o);
parameter WID=256;
input rst_i;
input clk_i;
input cyc_i;
input stb_i;
output reg ack_o;
input we_i;
input [WID/8-1:0] sel_i;
input [31:0] adr_i;
input [WID-1:0] dat_i;
output reg [WID-1:0] dat_o;
fta_bus_interface.master fta_o;

reg cycd;
always_ff @(posedge clk_i)
	cycd <= cyc_i;

always_ff @(posedge clk_i)
begin
	fta_o.req <= 500'd0;
	if (cyc_i & ~cycd) begin
		fta_o.req.cyc <= HIGH;
		fta_o.req.we <= we_i;
		fta_o.req.cmd <= we_i ? fta_bus_pkg::CMD_STORE : fta_bus_pkg::CMD_LOAD;
		fta_o.req.sel <= sel_i;
		fta_o.req.adr <= adr_i;
		fta_o.req.data1 <= dat_i;
	end
	if (fta_o.resp.ack) begin
		ack_o <= HIGH;
		dat_o <= fta_o.resp.dat;
	end
	if (!cyc_i) begin
		ack_o <= LOW;
		dat_o <= {WID{1'd0}};
	end
end

endmodule
