module SDCard(
	input clk,
	input reset,
	
	input clk_250kHz,
	
	output reg sd_clk,
	output reg sd_cmd,
	output reg sd_cs,
	input sd_dat,
	
	input[9:0] m_addr,
	input[7:0] m_in_data,
	output reg[7:0] m_out_data,
	input m_read,
	input m_write,
	output m_ready,
	
	output reg boot_ready,
	
	output reg[31:0] callback_addr,
	output reg[31:0] callback_data,
	output reg callback,
	
	output reg[15:0] debug
);

typedef enum reg[5:0] {
	ST_INIT,
	ST_SEND_BYTE,
	ST_SEND_COMMAND,
	ST_INIT_0,
	ST_INIT_1,
	ST_INIT_2,
	ST_INIT_3_0_1,
	ST_INIT_3_0_2,
	ST_INIT_3_0_3,
	ST_INIT_3_0_4,
	ST_INIT_3,
	ST_INIT_3_1,
	ST_INIT_4,
	ST_INIT_5,
	ST_INIT_6,
	ST_READ_SECTOR,
	ST_READ_SECTOR_1,
	ST_READ_SECTOR_2,
	ST_READ_SECTOR_3,
	ST_READ_SECTOR_4,
	ST_READ_SECTOR_5,
	ST_WRITE_SECTOR,
	ST_WRITE_SECTOR_1,
	ST_WRITE_SECTOR_2,
	ST_WRITE_SECTOR_3,
	ST_WRITE_SECTOR_4,
	ST_WRITE_SECTOR_5,
	ST_WRITE_SECTOR_6,
	ST_WRITE_SECTOR_7,
	ST_BOOT,
	ST_BOOT_DONE,
	ST_WAIT,
	ST_M_READ_1,
	ST_M_READ_2,
	ST_M_READ_3,
	ST_M_WRITE,
	ST_CALLBACK,
	ST_CALLBACK_1
} State;

State state;

reg[7:0] init_ctr;

State send_byte_ret;
reg[7:0] send_byte_data;
reg[3:0] send_byte_ctr;

State send_command_ret;
reg[2:0] send_command_ctr;
reg[47:0] send_command_data;

State read_sector_ret;
reg[31:0] read_sector_id;
reg[9:0] read_sector_ctr;


reg old_clk_250kHz;
wire clk_250kHz_posedge = ~old_clk_250kHz & clk_250kHz;
wire clk_250kHz_negedge = old_clk_250kHz & ~clk_250kHz;

reg[8:0] ram_addr;
reg[7:0] ram_in_data;
reg ram_write;
wire[7:0] ram_out_data;

reg[31:0] p_sector;
reg[31:0] p_callback;
reg[31:0] p_userdata;
reg[7:0] p_result;

sdcard_ram ram(
	.clock(clk),
	.address(ram_addr),
	.data(ram_in_data),
	.q(ram_out_data),
	.wren(ram_write)
);

assign m_ready = (state == ST_WAIT && m_read == 0 && m_write == 0);


always @(posedge clk or posedge reset) begin
	if (reset) begin
		state <= ST_INIT;
		send_byte_ctr <= 0;
		send_command_ctr <= 0;
		init_ctr <= 0;
		sd_cs <= 1;
		sd_clk <= 1;
		debug <= 0;
		read_sector_ctr <= 0;
		boot_ready <= 0;
		callback <= 0;
	end else begin
		old_clk_250kHz <= clk_250kHz;
		if (clk_250kHz_posedge && (state == ST_SEND_BYTE || state == ST_INIT)) 
				sd_clk <= 1;
		if (clk_250kHz_negedge && (state == ST_SEND_BYTE || state == ST_INIT)) 
				sd_clk <= 0;
		
		case(state)
			ST_SEND_BYTE: begin
				if (clk_250kHz_negedge) begin
					sd_cmd <= send_byte_data[7];
				end
				if (clk_250kHz_posedge) begin
					send_byte_data[0] <= sd_dat;
					send_byte_data[7:1] <= send_byte_data[6:0];
					send_byte_ctr <= send_byte_ctr + 1;
					if (send_byte_ctr == 7) begin
						send_byte_ctr <= 0;
						state <= send_byte_ret;
					end
				end
			end
			ST_SEND_COMMAND: begin
				send_command_ctr <= send_command_ctr + 1;
				send_command_data[47:8] <= send_command_data[39:0];
				send_byte_data <= send_command_data[47:40];
				if (send_command_ctr == 5) begin
					send_command_ctr <= 0;
					send_byte_ret <= send_command_ret;
				end else begin
					send_byte_ret <= ST_SEND_COMMAND;
				end
				state <= ST_SEND_BYTE;
			end
			ST_INIT: begin
				if (clk_250kHz_posedge) begin
					init_ctr <= init_ctr + 1;
				end
				if (init_ctr >= 80) begin
					state <= ST_INIT_0;
					sd_cs <= 0;
				end
				//debug <= 'b100;
			end
			ST_INIT_0: begin
				send_command_data <= 48'h400000000095;
				send_command_ret <= ST_INIT_1;
				state <= ST_SEND_COMMAND;
				//debug <= 'b110;
			end
			ST_INIT_1: begin
				if (send_byte_data == 8'hFF) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_INIT_1;
					state <= ST_SEND_BYTE;
				end else begin
					send_command_data <= 48'h48000001AA87;;
					send_command_ret <= ST_INIT_2;
					state <= ST_SEND_COMMAND;
				end
				//debug <= 'b1;
			end
			ST_INIT_2: begin
				if (send_byte_data == 8'hFF) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_INIT_2;
					state <= ST_SEND_BYTE;
				end else if (send_byte_data == 8'h04) begin
					// v1 init
				end else begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_INIT_3_0_1;
					state <= ST_SEND_BYTE;
				end
				//debug <= 'b11;
			end
			ST_INIT_3_0_1: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_INIT_3_0_2;
				state <= ST_SEND_BYTE;
			end
			ST_INIT_3_0_2: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_INIT_3_0_3;
				state <= ST_SEND_BYTE;
			end
			ST_INIT_3_0_3: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_INIT_3_0_4;
				state <= ST_SEND_BYTE;
			end
			ST_INIT_3_0_4: begin
				send_command_data <= 48'h770000000000;
				send_command_ret <= ST_INIT_3;
				state <= ST_SEND_COMMAND;
			end
			ST_INIT_3: begin
				if (send_byte_data != 8'h1) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_INIT_3;
					state <= ST_SEND_BYTE;
				end else begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_INIT_3_1;
					state <= ST_SEND_BYTE;
				end
				//debug <= 'b111;
			end
			ST_INIT_3_1: begin
				send_command_data <= 48'h6940000000FF;
				send_command_ret <= ST_INIT_4;
				state <= ST_SEND_COMMAND;
			end
			ST_INIT_4: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_INIT_5;
				state <= ST_SEND_BYTE;
				//debug <= 'b1111;
			end
			ST_INIT_5: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_INIT_6;
				state <= ST_SEND_BYTE;
				//debug <= 'b11111;
			end
			ST_INIT_6: begin
				if (send_byte_data != 8'h0) begin
					send_command_data <= 48'h770000000000;
					send_command_ret <= ST_INIT_3;
					state <= ST_SEND_COMMAND;
				end else begin
					state <= ST_BOOT;
				end
			end
			
			ST_READ_SECTOR: begin
				send_command_data <= { 
					8'h51,
					read_sector_id[31:24],
					read_sector_id[23:16],
					read_sector_id[15:8],
					read_sector_id[7:0],
					8'h0
				};
				send_command_ret <= ST_READ_SECTOR_1;
				state <= ST_SEND_COMMAND;
			end
			
			ST_READ_SECTOR_1: begin
				if (send_byte_data != 8'h0) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_READ_SECTOR_1;
					state <= ST_SEND_BYTE;
				end else begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_READ_SECTOR_2;
					state <= ST_SEND_BYTE;
				end				
			end
			
			ST_READ_SECTOR_2: begin
				if (send_byte_data != 8'hFE) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_READ_SECTOR_2;
					state <= ST_SEND_BYTE;
				end else begin
					read_sector_ctr <= 0;
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_READ_SECTOR_3;
					state <= ST_SEND_BYTE;
				end				
			end
			
			ST_READ_SECTOR_3: begin
				ram_in_data <= send_byte_data;
				
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_READ_SECTOR_3;
				state <= ST_SEND_BYTE;
				
				ram_addr <= read_sector_ctr[8:0];
				ram_write <= 1;
				read_sector_ctr <= read_sector_ctr + 1;
				if (read_sector_ctr == 511) begin
					state <= ST_READ_SECTOR_4;
				end
				
				if (read_sector_ctr == 0) begin
					debug[7:0] <= send_byte_data;
				end
			end
			
			ST_READ_SECTOR_4: begin
				ram_write <= 0;
				read_sector_ctr <= 0;
				send_byte_data <= 8'hFF;
				send_byte_ret <= ST_READ_SECTOR_5;
				state <= ST_SEND_BYTE;
			end
			
			ST_READ_SECTOR_5: begin
				send_byte_data <= 8'hFF;
				send_byte_ret <= read_sector_ret;
				state <= ST_SEND_BYTE;
			end
			
			ST_WRITE_SECTOR: begin
				send_command_data <= { 
					8'h58,
					read_sector_id[31:24],
					read_sector_id[23:16],
					read_sector_id[15:8],
					read_sector_id[7:0],
					8'h0
				};
				send_command_ret <= ST_WRITE_SECTOR_1;
				state <= ST_SEND_COMMAND;
			end
			
			ST_WRITE_SECTOR_1: begin
				if (send_byte_data != 8'h0) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_WRITE_SECTOR_1;
					state <= ST_SEND_BYTE;
				end else begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_WRITE_SECTOR_2;
					state <= ST_SEND_BYTE;
				end				
			end
			
			ST_WRITE_SECTOR_2: begin
				send_byte_data <= 8'hFE;
				send_byte_ret <= ST_WRITE_SECTOR_3;
				state <= ST_SEND_BYTE;
				ram_addr <= 0;
				read_sector_ctr[8:0] <= 0;
			end
			
			ST_WRITE_SECTOR_3: begin
				send_byte_data <= ram_out_data;
				send_byte_ret <= ST_WRITE_SECTOR_3;
				state <= ST_SEND_BYTE;
				
				ram_addr <= read_sector_ctr[8:0] + 1;
				read_sector_ctr <= read_sector_ctr + 1;
				if (read_sector_ctr == 511) begin
					send_byte_ret <= ST_WRITE_SECTOR_4;
				end
				
			end
			
			ST_WRITE_SECTOR_4: begin
				read_sector_ctr <= 0;
				send_byte_data <= 8'h00;
				send_byte_ret <= ST_WRITE_SECTOR_5;
				state <= ST_SEND_BYTE;
			end
			
			ST_WRITE_SECTOR_5: begin
				send_byte_data <= 8'h00;
				send_byte_ret <= ST_WRITE_SECTOR_6;
				state <= ST_SEND_BYTE;
			end
			
			ST_WRITE_SECTOR_6: begin
				if (send_byte_data == 8'hFF) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_WRITE_SECTOR_6;
					state <= ST_SEND_BYTE;
				end else begin
					p_result <= send_byte_data;
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_WRITE_SECTOR_7;
					state <= ST_SEND_BYTE;
				end	
			end
			
			ST_WRITE_SECTOR_7: begin
				if (send_byte_data == 8'hFF) begin
					send_byte_data <= 8'hFF;
					send_byte_ret <= ST_WRITE_SECTOR_7;
					state <= ST_SEND_BYTE;
				end else begin
					state <= read_sector_ret;
				end	
			end
			
			ST_BOOT: begin
				read_sector_ret <= ST_BOOT_DONE;
				read_sector_id <= 0;
				state <= ST_READ_SECTOR;
				debug <= 'b1;
			end
			ST_BOOT_DONE: begin
				boot_ready <= 1;
				state <= ST_WAIT;
			end
			ST_WAIT: begin
				if (m_read) begin
					if (m_addr[9] == 0) begin
						ram_addr <= m_addr[8:0];
						state <= ST_M_READ_1;
					end else begin
						if (m_addr[8:0] == 0) begin
							m_out_data <= p_result;
						end
					end
				end else if (m_write) begin
					if (m_addr[9] == 0) begin
						ram_addr <= m_addr[8:0];
						ram_in_data <= m_in_data;
						ram_write <= 1;
						state <= ST_M_WRITE;
					end else begin
						case (m_addr[8:0])
							0: p_sector[7:0] <= m_in_data;
							1: p_sector[15:8] <= m_in_data;
							2: p_sector[23:16] <= m_in_data;
							3: p_sector[31:24] <= m_in_data;
							4: p_callback[7:0] <= m_in_data;
							5: p_callback[15:8] <= m_in_data;
							6: p_callback[23:16] <= m_in_data;
							7: p_callback[31:24] <= m_in_data;
							8: p_userdata[7:0] <= m_in_data;
							9: p_userdata[15:8] <= m_in_data;
							10: p_userdata[23:16] <= m_in_data;
							11: p_userdata[31:24] <= m_in_data;
							12: begin
								read_sector_ret <= ST_CALLBACK;
								read_sector_id <= p_sector;
								state <= ST_READ_SECTOR;
							end
							13: begin
								read_sector_ret <= ST_CALLBACK;
								read_sector_id <= p_sector;
								state <= ST_WRITE_SECTOR;
							end
						endcase
					end
				end
			end
			ST_M_READ_1: begin
				state <= ST_M_READ_2;
			end
			ST_M_READ_2: begin
				state <= ST_M_READ_3;
			end
			ST_M_READ_3: begin
				m_out_data <= ram_out_data;
				state <= ST_WAIT;
			end
			ST_M_WRITE: begin
				ram_write <= 0;
				state <= ST_WAIT;
			end
			ST_CALLBACK: begin
				callback <= 1;
				callback_addr <= p_callback;
				callback_data <= p_userdata;
				state <= ST_CALLBACK_1;
			end
			ST_CALLBACK_1: begin
				callback <= 0;
				state <= ST_WAIT;
			end
		endcase
	end
end
	
endmodule
