// Extends a pulse
// The parameter BIT specifies a power of two in clock cycles to extend by.

module pulse_extender(clk_i, i, o, no);
parameter BIT = 5;
input clk_i;
input i;					// input pulse
output o;					// extended output pulse
output no;				// inverted extended output pulse

reg [BIT:0] cnt;

always_ff @(posedge clk_i)
if (i) begin
	cnt <= {BIT+1{1'b0}};
end
else begin
	if (!cnt[BIT])
		cnt <= cnt + 2'd1;
end

assign o = i | ~cnt[BIT];
assign no = ~o;

endmodule
