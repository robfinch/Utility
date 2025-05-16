import const_pkg::*;
import wishbone_pkg::*;
import fta_bus_pkg::*;

module wb_to_fta_bridge(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, err_o, we_i, sel_i, adr_i, dat_i, dat_o, fta_o);
parameter WID=256;
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output reg ack_o;
output reg [2:0] err_o;
input we_i;
input [WID/8-1:0] sel_i;
input [31:0] adr_i;
input [WID-1:0] dat_i;
output reg [WID-1:0] dat_o;
fta_bus_interface.master fta_o;

reg cycd;
reg [5:0] rty_cnt;

always_ff @(posedge clk_i)
begin
	cycd <= cyc_i & ~fta_o.resp.stall;
	if (fta_o.resp.rty)
		cycd <= 1'b0;
end

always_ff @(posedge clk_i)
if (rst_i)
	rty_cnt <= 6'd0;
else begin
	if (fta_o.resp.ack)
		rty_cnt <= 5'd0;
	if (fta_o.resp.rty) begin
		rty_cnt <= rty_cnt + 2'd1;
	end
end

always_ff @(posedge clk_i)
if (rst_i)
	err_o <= fta_bus_pkg::OKAY;
else begin
	if (cyc_i & ~cycd)
		err_o <= fta_bus_pkg::OKAY;
	if (rty_cnt==6'd10)
		err_o <= fta_bus_pkg::ERR;
end

always_ff @(posedge clk_i)
begin
	fta_o.req <= 1000'd0;
	if (cyc_i & ~cycd & cs_i & ~fta_o.resp.stall) begin
		fta_o.req.cyc <= HIGH;
		fta_o.req.we <= we_i;
		fta_o.req.cmd <= we_i ? fta_bus_pkg::CMD_STORE : fta_bus_pkg::CMD_LOAD;
		fta_o.req.sel <= sel_i;
		fta_o.req.adr <= adr_i;
		fta_o.req.data1 <= dat_i;
	end
	if (fta_o.resp.ack || (cyc_i && we_i) || rty_cnt==6'd10) begin
		ack_o <= HIGH;
		dat_o <= fta_o.resp.dat;
	end
	if (!cyc_i) begin
		ack_o <= LOW;
		dat_o <= {WID{1'd0}};
	end
end

endmodule
