
module Memory(
	input clk,
	input reset,
	
	input[31:0] addr,
	input[7:0] in_data,
	output reg[7:0] out_data,
	input sig_write,
	input sig_read,
	output ready,
	
	output reg[19:0] sram_addr,
	inout reg[15:0] sram_data,
	output sram_we_n,
	output sram_oe_n,
	output sram_lb_n,
	output sram_hb_n,
	
	
	output reg[9:0] sd_addr,
	output reg[7:0] sd_in,
	input[7:0] sd_out,
	output reg sd_write,
	output reg sd_read,
	input sd_ready
);

enum reg[2:0] {
	ST_WAIT,
	ST_READ,
	ST_WRITE,
	ST_SD_READ,
	ST_SD_WRITE
} state;

assign ready = (state == ST_WAIT && sig_write == 0 && sig_read == 0);
reg addr_low_bit;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		sram_we_n <= 1;
		sram_oe_n <= 1;
		sram_lb_n <= 1;
		sram_hb_n <= 1;
		state <= ST_WAIT;
		addr_low_bit <= 0;
		sram_data <= 16'hZZZZ;
		
		sd_write <= 0;
	end else begin
		case (state)
			ST_WAIT: begin
				if (addr[31:21] == 10'h0) begin
					if (sig_write) begin
						sram_addr <= addr[20:1];
						if (!addr[0]) begin
							sram_data <= { 8'd0, in_data };
							sram_lb_n <= 0;
						end else begin
							sram_data <= { in_data, 8'd0 };
							sram_hb_n <= 0;
						end
						sram_we_n <= 0;
						state <= ST_WRITE;
					end else if (sig_read) begin
						sram_addr <= addr[20:1];
						if (!addr[0]) begin
							sram_lb_n <= 0;
						end else begin
							sram_hb_n <= 0;
						end
						addr_low_bit <= addr[0];
						sram_data <= 16'hZZZZ;
						sram_oe_n <= 0;
						state <= ST_READ;
					end
				end else if (addr[31:21] == 10'h1) begin
					if (sig_read) begin
						sd_addr <= addr[8:0];
						sd_read <= 1;
						state <= ST_SD_READ;
					end else if (sig_write) begin
						sd_addr <= addr[8:0];
						sd_in <= in_data;
						sd_write <= 1;
						state <= ST_SD_WRITE;
					end
				end
 			end
			ST_WRITE: begin
				sram_we_n <= 1;
				sram_lb_n <= 1;
				sram_hb_n <= 1;
				state <= ST_WAIT;
			end
			ST_READ: begin
				sram_lb_n <= 1;
				sram_hb_n <= 1;
				sram_oe_n <= 1;
				if (!addr_low_bit) begin
					out_data <= sram_data[7:0];
				end else begin
					out_data <= sram_data[15:8];
				end

				state <= ST_WAIT;
			end			
			ST_SD_READ: begin
				sd_read <= 0;
				if (sd_ready) begin
					state <= ST_WAIT;
					out_data <= sd_out;
				end
			end
			ST_SD_WRITE: begin
				sd_write <= 0;
				if (sd_ready) begin
					state <= ST_WAIT;
				end
			end
		endcase
	end
end


endmodule
