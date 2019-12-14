// Copyright (c) 2017,19 MiSTer-X

module FlickyMAIN
(
	input				CLK48M,
	input				CLK3M,

	input				RESET,

	input  [20:0]	HID,

	input				VBLK,
	input				VIDCS,
	input   [7:0]	VIDDO,

	output			CPUCLn,
	output [15:0]	CPUAD,
	output  [7:0]	CPUDO,
	output		  	CPUWR,
	
	output			SNDRQ
);

wire			ROMCL   = CLK48M;
wire			CPUCL   = CLK3M;
assign 		CPUCLn  = ~CPUCL;

wire  [7:0]	CPUDI;
wire			CPURD;

wire			cpu_cs_video;
wire  [7:0]	cpu_rd_video;

wire	cpu_m1;
wire	cpu_mreq, cpu_iorq;
wire	_cpu_rd, _cpu_wr;

Z80IP maincpu(
	.reset(RESET),
	.clk(CPUCL),
	.adr(CPUAD),
	.data_in(CPUDI),
	.data_out(CPUDO),
	.m1(cpu_m1),
	.mx(cpu_mreq),
	.ix(cpu_iorq),
	.rd(_cpu_rd),
	.wr(_cpu_wr),
	.intreq(VBLK),
	.nmireq(1'b0)
);

assign		CPUWR = _cpu_wr & cpu_mreq;
assign		CPURD = _cpu_rd & cpu_mreq;

assign		SNDRQ = (CPUAD[4:0] == 5'b1_1000) & cpu_iorq & _cpu_wr;

wire			cpu_cs_port1 = (CPUAD[4:0] == 5'b0_00xx) & cpu_iorq;
wire			cpu_cs_port2 = (CPUAD[4:0] == 5'b0_01xx) & cpu_iorq;
wire			cpu_cs_portS = (CPUAD[4:0] == 5'b0_10xx) & cpu_iorq;
wire			cpu_cs_portA = (CPUAD[4:0] == 5'b0_11x0) & cpu_iorq;
wire			cpu_cs_portB =((CPUAD[4:0] == 5'b0_11x1) | (CPUAD[4:0] == 5'b1_0000)) & cpu_iorq;
wire			cpu_cs_portI = (CPUAD[4:0] == 5'b1_10xx) & cpu_iorq;

//wire [7:0]	cpu_rd_port1 = {`P1LF,`P1RG,3'b111,`P1TA & `P1TB & `P1TC,2'b11}; 
//wire [7:0]	cpu_rd_port2 = {`P2LF,`P2RG,3'b111,`P2TA & `P2TB & `P2TC,2'b11}; 
//wire [7:0]	cpu_rd_portS = {2'b11,`P2ST,`P1ST,3'b111,`COIN}; 
wire [7:0]	cpu_rd_port1 = 8'hFF;
wire [7:0]	cpu_rd_port2 = 8'hFF;
wire [7:0]	cpu_rd_portS = 8'hFF;
wire [7:0]	cpu_rd_portA = 8'hFF;
wire [7:0]	cpu_rd_portB = 8'hFF;

wire [7:0]	cpu_rd_mrom;
wire			cpu_cs_mrom = (CPUAD[15] == 1'b0);
PRGROM prom(ROMCL, cpu_m1, CPUAD[14:0], cpu_rd_mrom );

wire [7:0]	cpu_rd_mram;
wire			cpu_cs_mram = (CPUAD[15:12] == 4'b1100);
SRAM_4096 mainram(CPUCLn, CPUAD[11:0], cpu_rd_mram, cpu_cs_mram & CPUWR, CPUDO );

reg [7:0] vidmode;
always @(posedge CPUCLn) begin
	if ((CPUAD[4:0] == 5'b1_1001) & cpu_iorq & _cpu_wr) begin
		vidmode <= CPUDO;
	end
end

dataselector8 mcpudisel(
	CPUDI,
	VIDCS, VIDDO,
	cpu_cs_port1, cpu_rd_port1,
	cpu_cs_port2, cpu_rd_port2,
	cpu_cs_portS, cpu_rd_portS,
	cpu_cs_portA, cpu_rd_portA,
	cpu_cs_portB, cpu_rd_portB,
	cpu_cs_mram,  cpu_rd_mram,
	cpu_cs_mrom,  cpu_rd_mrom,
	8'hFF
);

endmodule


//----------------------------------
//  Program ROM with Decryptor 
//----------------------------------
module PRGROM
(
	input 				clk,

	input					mrom_m1,
	input     [14:0]	mrom_ad,
	output reg [7:0]	mrom_dt
);

reg  [15:0] madr;
wire  [7:0] mdat;

wire			f		  = mdat[7];
wire  [7:0] xorv    = { f, 1'b0, f, 1'b0, f, 3'b000 }; 
wire  [7:0] andv    = ~(8'hA8);
wire  [1:0] decidx0 = { mdat[5],  mdat[3] } ^ { f, f };
wire  [6:0] decidx  = { madr[12], madr[8], madr[4], madr[0], ~madr[15], decidx0 };
wire  [7:0] dectbl;
wire  [7:0] mdec    = ( mdat & andv ) | ( dectbl ^ xorv );

FlickyDECTBL decrom( clk, decidx, dectbl );
FlickyCPU1IR mainir( clk, madr[14:0], mdat );

reg phase = 1'b0;
always @( negedge clk ) begin
	if ( phase ) mrom_dt <= mdec;
	else madr <= { mrom_m1, mrom_ad };
	phase <= ~phase;
end

endmodule
