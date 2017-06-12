module HEXDisplay4(
	input[3:0] value,
	output[6:0] segments
);

always @(value)
	case(value)
		4'h1: segments = 7'b1111001;	// ---t----
		4'h2: segments = 7'b0100100; 	// |	  |
		4'h3: segments = 7'b0110000; 	// lt	 rt
		4'h4: segments = 7'b0011001; 	// |	  |
		4'h5: segments = 7'b0010010; 	// ---m----
		4'h6: segments = 7'b0000010; 	// |	  |
		4'h7: segments = 7'b1111000; 	// lb	 rb
		4'h8: segments = 7'b0000000; 	// |	  |
		4'h9: segments = 7'b0011000; 	// ---b----
		4'ha: segments = 7'b0001000;
		4'hb: segments = 7'b0000011;
		4'hc: segments = 7'b1000110;
		4'hd: segments = 7'b0100001;
		4'he: segments = 7'b0000110;
		4'hf: segments = 7'b0001110;
		4'h0: segments = 7'b1000000;
	endcase

endmodule

module HEXDisplay32(
	input[31:0] value,
	output[6:0] segments[8]
);

genvar i;
generate
for (i = 0; i < 8; i = i + 1) begin : display_generation
	HEXDisplay4 disp(value[(i * 4) + 3:(i * 4)], segments[i]);
end
endgenerate

endmodule
