// Copyright (c) 2017,19 MiSTer-X

//----------------------------------
//  2K SRAM
//----------------------------------
module SRAM_2048( CL, ADRS, OUT, WR, IN );

input				CL;
input  [10:0]	ADRS;
output [7:0]	OUT;
input				WR;
input  [7:0]	IN;


reg [7:0] ramcore [0:2047];
reg [7:0] OUT;

always @( posedge CL ) begin
	if (WR) ramcore[ADRS] <= IN;
	else OUT <= ramcore[ADRS];
end


endmodule


//----------------------------------
//  4K SRAM
//----------------------------------
module SRAM_4096(
	input					clk,
	input	    [11:0]	adrs,
	output reg [7:0]	out,
	input					wr,
	input		  [7:0]	in
);

reg [7:0] ramcore [0:4095];

always @( posedge clk ) begin
	if (wr) ramcore[adrs] <= in;
	else out <= ramcore[adrs];
end

endmodule 


//----------------------------------
//  DualPort RAM
//----------------------------------
module DPRAM2048
(
	input					clk0,
	input [10:0]		adr0,
	input  [7:0]		dat0,
	input					wen0,

	input					clk1,
	input [10:0]		adr1,
	output reg [7:0]	dat1,

	output reg [7:0]	dtr0
);

reg [7:0] core [0:2047];

always @( posedge clk0 ) begin
	if (wen0) core[adr0] <= dat0;
	else dtr0 <= core[adr0];
end

always @( posedge clk1 ) begin
	dat1 <= core[adr1];
end

endmodule


module DPRAM1024
(
	input					clk0,
	input  [9:0]		adr0,
	input  [7:0]		dat0,
	input					wen0,

	input					clk1,
	input  [9:0]		adr1,
	output reg [7:0]	dat1,

	output reg [7:0]	dtr0
);

reg [7:0] core [0:1023];

always @( posedge clk0 ) begin
	if (wen0) core[adr0] <= dat0;
	else dtr0 <= core[adr0];
end

always @( posedge clk1 ) begin
	dat1 <= core[adr1];
end

endmodule


module DPRAM2048_8_16
(
	input					clk0,
	input  [10:0]		adr0,
	input   [7:0]		dat0,
	input					wen0,

	input					clk1,
	input   [9:0]		adr1,
	output [15:0]		dat1,

	output  [7:0]		dtr0
);

wire [7:0] do0, do1;
wire [7:0] doH, doL;

DPRAM1024 core0( clk0, adr0[10:1], dat0, wen0 & (~adr0[0]), clk1, adr1, doL, do0 );
DPRAM1024 core1( clk0, adr0[10:1], dat0, wen0 &   adr0[0],  clk1, adr1, doH, do1 );

assign dtr0 = adr0[0] ? do1 : do0;
assign dat1 = { doH, doL };

endmodule


//----------------------------------
//  VRAM
//----------------------------------
module VRAMs
(
	input					clk0,
	input       [9:0]	adr0,
	output reg  [7:0]	dat0,
	input       [7:0]	dtw0,
	input					wen0,

	input					clk1,
	input       [9:0]	adr1,
	output reg  [7:0]	dat1
);

reg [7:0] core [0:1023];

always @( posedge clk0 ) begin
	if (wen0) core[adr0] <= dtw0;
	else dat0 <= core[adr0];
end

always @( posedge clk1 ) begin
	dat1 <= core[adr1];
end

endmodule

module VRAM
(
	input					clk0,
	input     [10:0]	adr0,
	output     [7:0]	dat0,
	input      [7:0]	dtw0,
	input					wen0,

	input					clk1,
	input       [9:0]	adr1,
	output     [15:0]	dat1
);

wire even = ~adr0[0];
wire  odd =  adr0[0];

wire [7:0] do00, do01, do10, do11;
VRAMs ram0( clk0, adr0[10:1], do00, dtw0, wen0 & even, clk1, adr1, do10 );
VRAMs ram1( clk0, adr0[10:1], do01, dtw0, wen0 &  odd, clk1, adr1, do11 );

assign dat0 = adr0[0] ? do01 : do00;
assign dat1 = { do11, do10 };

endmodule

//----------------------------------
//  DPRAM1024_1
//----------------------------------
module DPRAM1024_1
(
	input			clk0,
	input	[9:0]	adr0,
	output 		rdat0,
	input			wdat0,
	input			we0,
	
	input			clk1,
	input	[9:0]	adr1,
	input			wdat1,
	input			we1
);

DPRAM1024_1B core (
	adr0,adr1,
	clk0,clk1,
	wdat0,wdat1,
	we0,we1,
	rdat0
);
	
endmodule


//----------------------------------
//  DPRAM64_1
//----------------------------------
module DPRAM64_1
(
	input			clk0,
	input	[5:0]	adr0,
	output 		rdat0,
	input			wdat0,
	input			we0,
	
	input			clk1,
	input	[5:0]	adr1,
	input			wdat1,
	input			we1
);

DPRAM1024_1B core (
	adr0,adr1,
	clk0,clk1,
	wdat0,wdat1,
	we0,we1,
	rdat0
);

endmodule


//----------------------------------
//  ScanLine Buffer
//----------------------------------
module LineBuf
(
	input				clkr,
	input	  [9:0]	radr,
	output [10:0]	rdat,

	input				clkw,
	input	  [9:0]	wadr,
	input	 [10:0]	wdat,
	input				we,
	output [10:0]	rdat1
);

DPRAM1024_11B core (
	radr,wadr,
	clkr,clkw,
	16'h0,{5'h0,wdat},
	1'b0,we,
	rdat,rdat1
);

endmodule


//----------------------------------
//  Data Selector (32bits)
//----------------------------------
module dataselector1_32(

	output [31:0] oDATA,

	input iSEL0,
	input [31:0] iDATA0,

	input [31:0] dData
);

assign oDATA = iSEL0 ? iDATA0 :
					dData;

endmodule


//----------------------------------
//  Data Selector 3 to 1
//----------------------------------
module dataselector3(

	output [7:0] oDATA,

	input iSEL0,
	input [7:0] iDATA0,

	input iSEL1,
	input [7:0] iDATA1,

	input iSEL2,
	input [7:0] iDATA2,

	input [7:0] dData
);

assign oDATA = iSEL0 ? iDATA0 :
					iSEL1 ? iDATA1 :
					iSEL2 ? iDATA2 :
					dData;

endmodule


//----------------------------------
//  Data Selector 2 to 1 (11bits)
//----------------------------------
module dataselector2_11(

	output [10:0] oDATA,

	input iSEL0,
	input [10:0] iDATA0,

	input iSEL1,
	input [10:0] iDATA1,

	input [10:0] dData
);

assign oDATA = iSEL0 ? iDATA0 :
					iSEL1 ? iDATA1 :
					dData;

endmodule


//----------------------------------
//  Data Selector 8 to 1
//----------------------------------
module dataselector8(

	output [7:0] oDATA,

	input iSEL0,
	input [7:0] iDATA0,

	input iSEL1,
	input [7:0] iDATA1,

	input iSEL2,
	input [7:0] iDATA2,

	input iSEL3,
	input [7:0] iDATA3,

	input iSEL4,
	input [7:0] iDATA4,

	input iSEL5,
	input [7:0] iDATA5,

	input iSEL6,
	input [7:0] iDATA6,

	input iSEL7,
	input [7:0] iDATA7,

	input [7:0] dData
);

assign oDATA = iSEL0 ? iDATA0 :
					iSEL1 ? iDATA1 :
					iSEL2 ? iDATA2 :
					iSEL3 ? iDATA3 :
					iSEL4 ? iDATA4 :
					iSEL5 ? iDATA5 :
					iSEL6 ? iDATA6 :
					iSEL7 ? iDATA7 :
					dData;

endmodule

//----------------------------------
//  Data Selector 6 to 1
//----------------------------------
module dataselector6(

	output [7:0] oDATA,

	input iSEL0,
	input [7:0] iDATA0,

	input iSEL1,
	input [7:0] iDATA1,

	input iSEL2,
	input [7:0] iDATA2,

	input iSEL3,
	input [7:0] iDATA3,

	input iSEL4,
	input [7:0] iDATA4,

	input iSEL5,
	input [7:0] iDATA5,

	input [7:0] dData
);

assign oDATA = iSEL0 ? iDATA0 :
					iSEL1 ? iDATA1 :
					iSEL2 ? iDATA2 :
					iSEL3 ? iDATA3 :
					iSEL4 ? iDATA4 :
					iSEL5 ? iDATA5 :
					dData;

endmodule


