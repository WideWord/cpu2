
module cur(
	input CLOCK_50,
	
	input[17:0] SW,
	output[17:0] LEDR,
	output[8:0] LEDG,
	
	output[6:0] HEX0,
	output[6:0] HEX1,
	output[6:0] HEX2,
	output[6:0] HEX3,
	output[6:0] HEX4,
	output[6:0] HEX5,
	output[6:0] HEX6,
	output[6:0] HEX7,
	
	output SRAM_WE_N,
	output SRAM_OE_N,
	output SRAM_LB_N,
	output SRAM_UB_N,
	output SRAM_CE_N,
	inout[15:0] SRAM_DQ,
	output [19:0] SRAM_ADDR,
	
	output SD_CLK,
	output SD_CMD,
	inout[3:0] SD_DAT
);


wire reset = SW[0];
assign LEDR[17] = reset;

wire clk;
wire clk_250kHz;

pll pll(.areset(reset), .inclk0(CLOCK_50), .c0(clk_250kHz), .c1(clk));

wire[31:0] ram_addr; 
wire[7:0] ram_in;
wire[7:0] ram_out;
wire ram_read;
wire ram_write;
wire ram_ready;

assign LEDG[8] = boot_ready;

Memory memory(
	.clk(clk),
	.reset(reset),
	
	.addr(ram_addr),
	.out_data(ram_out),
	.in_data(ram_in),
	.sig_read(ram_read),
	.sig_write(ram_write),
	.ready(ram_ready),
	
	.sram_addr(SRAM_ADDR),
	.sram_data(SRAM_DQ),
	.sram_we_n(SRAM_WE_N),
	.sram_oe_n(SRAM_OE_N),
	.sram_lb_n(SRAM_LB_N),
	.sram_hb_n(SRAM_UB_N),
	
	.sd_addr(sd_addr),
	.sd_in(sd_in),
	.sd_out(sd_out),
	.sd_write(sd_write),
	.sd_read(sd_read),
	.sd_ready(sd_ready)
);

assign SRAM_CE_N = 0;

wire[9:0] sd_addr;
wire[7:0] sd_in;
wire[7:0] sd_out;
wire sd_write;
wire sd_read;
wire sd_ready;
wire boot_ready;

wire[31:0] sd_callback_addr;
wire[31:0] sd_callback_data;
wire sd_callback;

SDCard sd(
	.clk(clk),
	.reset(reset),
	.clk_250kHz(clk_250kHz),
	
	.sd_clk(SD_CLK),
	.sd_cmd(SD_CMD),
	.sd_cs(SD_DAT[3]),
	.sd_dat(SD_DAT[0]),
	
	.m_addr(sd_addr),
	.m_in_data(sd_in),
	.m_out_data(sd_out),
	.m_write(sd_write),
	.m_read(sd_read),
	.m_ready(sd_ready),
	
	.callback_addr(sd_callback_addr),
	.callback_data(sd_callback_data),
	.callback(sd_callback),
	
	.boot_ready(boot_ready)
);

wire[31:0] cpu_debug;

CPU cpu(
	.clk(clk),
	.reset(~boot_ready | reset),
	
	.m_addr(ram_addr),
	.m_in(ram_in),
	.m_out(ram_out),
	.m_read(ram_read),
	.m_write(ram_write),
	.m_ready(ram_ready),
	
	.callback1_addr(sd_callback_addr),
	.callback1_data(sd_callback_data),
	.callback1(sd_callback),
	
	.debug(cpu_debug)
);

wire[6:0] hexDisplay[8];

assign HEX0 = hexDisplay[0];
assign HEX1 = hexDisplay[1];
assign HEX2 = hexDisplay[2];
assign HEX3 = hexDisplay[3];
assign HEX4 = hexDisplay[4];
assign HEX5 = hexDisplay[5];
assign HEX6 = hexDisplay[6];
assign HEX7 = hexDisplay[7];


HEXDisplay32(cpu_debug, hexDisplay);

endmodule
