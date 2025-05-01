module ffz144(i, o);
input [143:0] i;
output reg [7:0] o;

wire [5:0] o1,o2,o3;
ffz48 u1 (i[143:96],o1);
ffz48 u2 (i[95:48],o2);
ffz48 u3 (i[47:0],o3);
always_comb
if (o1==6'd63 && o2==6'd63 && o3==6'd63)
	o <= 8'd255;
else if (o1==6'd63 && o2==6'd63)
  o <= o3;
else if (o1==6'd63)
  o <= 8'd48 + o2;
else
  o <= 8'd96 + o1;

endmodule
