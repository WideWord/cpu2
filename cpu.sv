module CPU(
	input clk,
	input reset,
	
	output reg[31:0] m_addr,
	output reg[7:0] m_in,
	input[7:0] m_out,
	output reg m_read,
	output reg m_write,
	input m_ready,
	
	input[31:0] callback1_addr,
	input[31:0] callback1_data,
	input callback1,
	
	output[31:0] debug
);

reg[31:0] regs[32];

typedef enum {
	REG_PC = 31,
	REG_SP = 30,
	REG_FLAGS = 29
} Reg;


typedef enum reg[3:0] {
	ST_FETCH_CMD,
	ST_FETCH_CMD_1,
	ST_FETCH_CMD_2,
	ST_FETCH_CMD_3,
	ST_FETCH_CMD_4,
	ST_EXEC,
	ST_CALLBACK1
} State;

State state;

reg[3:0] cmd_state;

reg[31:0] command;
wire[6:0] opcode = command[6:0];
wire[4:0] oc = command[11:7];
wire[4:0] oa = command[16:12];
wire[14:0] ob = command[31:17];
wire[5:0] ob5 = ob[5:0];
wire[31:0] ob32s = { ob[14] ? 17'h1FFFF : 17'h0, ob };
wire[31:0] ob32 = { 17'h0, ob };

assign debug = regs[0];

reg[31:0] c_callback1_addr;
reg[31:0] c_callback1_data;
reg c_callback1;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		regs[REG_PC] <= 32'h200000;
		state <= ST_FETCH_CMD;
		m_read <= 0;
		m_write <= 0;
		m_in <= 0;
		cmd_state <= 0;
		c_callback1 <= 0;
	end else begin
		
		if (callback1) begin
			c_callback1 <= 1;
			c_callback1_addr <= callback1_addr;
			c_callback1_data <= callback1_data;
		end
	
		case (state)
			ST_FETCH_CMD: begin
				if (c_callback1) begin
					c_callback1 <= 0;
					state <= ST_CALLBACK1;
				end else if (m_ready) begin
					m_addr <= regs[REG_PC];
					m_read <= 1;
					state <= ST_FETCH_CMD_1;
				end
			end
			ST_FETCH_CMD_1: begin
				m_read <= 0;
				if (m_ready) begin
					command[7:0] <= m_out;
					m_addr <= regs[REG_PC] + 1;
					m_read <= 1;
					state <= ST_FETCH_CMD_2;
				end
			end
			ST_FETCH_CMD_2: begin
				m_read <= 0;
				if (m_ready) begin
					command[15:8] <= m_out;
					m_addr <= regs[REG_PC] + 2;
					m_read <= 1;
					state <= ST_FETCH_CMD_3;
				end
			end
			ST_FETCH_CMD_3: begin
				m_read <= 0;
				if (m_ready) begin
					command[23:16] <= m_out;
					m_addr <= regs[REG_PC] + 3;
					m_read <= 1;
					state <= ST_FETCH_CMD_4;
				end
			end
			ST_FETCH_CMD_4: begin
				m_read <= 0;
				if (m_ready) begin
					command[31:24] <= m_out;
					regs[REG_PC] <= regs[REG_PC] + 4;
					state <= ST_EXEC;
				end
			end
			
			ST_EXEC: begin
				case (opcode)
					'h00: begin
						regs[oc] <= regs[oa];
						state <= ST_FETCH_CMD;
					end
					'h01: begin
						regs[oc] <= { 16'h0, oa[0], ob };
						state <= ST_FETCH_CMD;
					end
					'h02: begin
						regs[oc][31:16] <= { oa[0], ob };
						state <= ST_FETCH_CMD;
					end
					
					'h10: begin
						regs[oc] <= regs[oa] + regs[ob5];
						state <= ST_FETCH_CMD;
					end
					'h11: begin
						regs[oc] <= regs[oa] - regs[ob5];
						state <= ST_FETCH_CMD;
					end
					'h12: begin
						regs[oc] <= regs[oa] | regs[ob5];
						state <= ST_FETCH_CMD;
					end
					'h13: begin
						regs[oc] <= regs[oa] & regs[ob5];
						state <= ST_FETCH_CMD;
					end
					
					'h18: begin
						regs[oc] <= regs[oa] + ob32s;
						state <= ST_FETCH_CMD;
					end
					'h1A: begin
						regs[oc] <= regs[oa] | ob32;
						state <= ST_FETCH_CMD;
					end
					'h1B: begin
						regs[oc] <= regs[oa] & ob32;
						state <= ST_FETCH_CMD;
					end
					'h1C: begin
						regs[oc] <= ob32s - regs[oa];
						state <= ST_FETCH_CMD;
					end
					
					'h20: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_in <= regs[oa][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h21: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_in <= regs[oa][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s + 1;
									m_in <= regs[oa][15:8];
									m_write <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h22: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_in <= regs[oa][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s + 1;
									m_in <= regs[oa][15:8];
									m_write <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s + 2;
									m_in <= regs[oa][23:16];
									m_write <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s + 3;
									m_in <= regs[oa][31:24];
									m_write <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h23: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 24'h0, m_out };
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h24: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { m_out[7] ? 24'hFFFFFF : 24'h0, m_out };
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h25: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 24'h0, m_out };
									m_addr <= regs[oc] + ob32s + 1;
									m_read <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 16'h0, m_out, regs[oa][7:0] };
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h26: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 24'h0, m_out };
									m_addr <= regs[oc] + ob32s + 1;
									m_read <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= {  m_out[7] ? 16'hFFFF : 16'h0, m_out, regs[oa][7:0] };
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h27: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[oc] + ob32s;
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 24'h0, m_out };
									m_addr <= regs[oc] + ob32s + 1;
									m_read <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][15:8] <= m_out;
									m_addr <= regs[oc] + ob32s + 2;
									m_read <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][23:16] <= m_out;
									m_addr <= regs[oc] + ob32s + 3;
									m_read <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][31:24] <= m_out;
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h28: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 4;
									m_in <= regs[oa][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 3;
									m_in <= regs[oa][15:8];
									m_write <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 2;
									m_in <= regs[oa][23:16];
									m_write <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 1;
									m_in <= regs[oa][31:24];
									m_write <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								regs[REG_SP] <= regs[REG_SP] - 4;
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h29: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									regs[REG_SP] <= regs[REG_SP] + 4;
									m_addr <= regs[REG_SP];
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa] <= { 24'h0, m_out };
									m_addr <= regs[REG_SP] - 3;
									m_read <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][15:8] <= m_out;
									m_addr <= regs[REG_SP] - 2;
									m_read <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][23:16] <= m_out;
									m_addr <= regs[REG_SP] - 1;
									m_read <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								m_read <= 0;
								if (m_ready) begin
									regs[oa][31:24] <= m_out;
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h2A: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 4;
									m_in <= regs[REG_PC][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 3;
									m_in <= regs[REG_PC][15:8];
									m_write <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 2;
									m_in <= regs[REG_PC][23:16];
									m_write <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 1;
									m_in <= regs[REG_PC][31:24];
									m_write <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								regs[REG_SP] <= regs[REG_SP] - 4;
								regs[REG_PC] <= regs[oa];
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h2B: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 4;
									m_in <= regs[REG_PC][7:0];
									m_write <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 3;
									m_in <= regs[REG_PC][15:8];
									m_write <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 2;
									m_in <= regs[REG_PC][23:16];
									m_write <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_write <= 0;
								if (m_ready) begin
									m_addr <= regs[REG_SP] - 1;
									m_in <= regs[REG_PC][31:24];
									m_write <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								regs[REG_SP] <= regs[REG_SP] - 4;
								regs[REG_PC] <= regs[REG_PC] + ob32s;
								m_write <= 0;
								state <= ST_FETCH_CMD;
								cmd_state <= 0;
							end
						endcase
					end
					
					'h2C: begin
						case (cmd_state)
							0: begin
								if (m_ready) begin
									regs[REG_SP] <= regs[REG_SP] + 4;
									m_addr <= regs[REG_SP];
									m_read <= 1;
									cmd_state <= 1;
								end
							end
							1: begin
								m_read <= 0;
								if (m_ready) begin
									regs[REG_PC] <= { 24'h0, m_out };
									m_addr <= regs[REG_SP] - 3;
									m_read <= 1;
									cmd_state <= 2;
								end
							end
							2: begin
								m_read <= 0;
								if (m_ready) begin
									regs[REG_PC][15:8] <= m_out;
									m_addr <= regs[REG_SP] - 2;
									m_read <= 1;
									cmd_state <= 3;
								end
							end
							3: begin
								m_read <= 0;
								if (m_ready) begin
									regs[REG_PC][23:16] <= m_out;
									m_addr <= regs[REG_SP] - 1;
									m_read <= 1;
									cmd_state <= 4;
								end
							end
							4: begin
								m_read <= 0;
								if (m_ready) begin
									regs[REG_PC][31:24] <= m_out;
									state <= ST_FETCH_CMD;
									cmd_state <= 0;
								end
							end
						endcase
					end
					
					'h30: begin
						regs[REG_FLAGS][4:0] <= {
							regs[oa] == regs[ob],
							regs[oa] > regs[ob],
							regs[oa] < regs[ob],
							$signed(regs[oa]) > $signed(regs[ob]),
							$signed(regs[oa]) < $signed(regs[ob]),
						};
						state <= ST_FETCH_CMD;
					end
					
					'h31: begin
						regs[REG_FLAGS][4:0] <= {
							regs[oa] == ob32s,
							regs[oa] > ob32s,
							regs[oa] < ob32s,
							$signed(regs[oa]) > $signed(ob32s),
							$signed(regs[oa]) < $signed(ob32s),
						};
						state <= ST_FETCH_CMD;
					end
					
					'h32: begin
						if ((regs[REG_FLAGS][4:0] & oa) != 0) begin
							regs[REG_PC] <= regs[REG_PC] + ob32s;
						end
						state <= ST_FETCH_CMD;
					end
					
				endcase
			end
			ST_CALLBACK1: begin
				case (cmd_state)
					0: begin
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 4;
							m_in <= regs[REG_PC][7:0];
							m_write <= 1;
							cmd_state <= 1;
						end
					end
					1: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 3;
							m_in <= regs[REG_PC][15:8];
							m_write <= 1;
							cmd_state <= 2;
						end
					end
					2: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 2;
							m_in <= regs[REG_PC][23:16];
							m_write <= 1;
							cmd_state <= 3;
						end
					end
					3: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 1;
							m_in <= regs[REG_PC][31:24];
							m_write <= 1;
							cmd_state <= 4;
						end
					end
					4: begin
						regs[REG_SP] <= regs[REG_SP] - 4;
						m_write <= 0;
						cmd_state <= 5;
					end
					5: begin
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 4;
							m_in <= c_callback1_data[7:0];
							m_write <= 1;
							cmd_state <= 6;
						end
					end
					6: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 3;
							m_in <= c_callback1_data[15:8];
							m_write <= 1;
							cmd_state <= 7;
						end
					end
					7: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 2;
							m_in <= c_callback1_data[23:16];
							m_write <= 1;
							cmd_state <= 8;
						end
					end
					8: begin
						m_write <= 0;
						if (m_ready) begin
							m_addr <= regs[REG_SP] - 1;
							m_in <= c_callback1_data[31:24];
							m_write <= 1;
							cmd_state <= 9;
						end
					end
					9: begin
						regs[REG_SP] <= regs[REG_SP] - 4;
						regs[REG_PC] <= c_callback1_addr;
						m_write <= 0;
						cmd_state <= 0;
						state <= ST_FETCH_CMD;
					end
				endcase
			end
		endcase
	end
end


endmodule
