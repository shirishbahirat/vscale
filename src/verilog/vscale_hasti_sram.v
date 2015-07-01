`include "vscale_hasti_constants.vh"

module vscale_hasti_sram(
			 input 	       hclk,
                         input 	       hresetn,
                         input [31:0]  haddr,
                         input 	       hwrite,
                         input [2:0]   hsize,
                         input [2:0]   hburst,
                         input 	       hmastlock,
                         input [3:0]   hprot,
                         input [1:0]   htrans,
                         input [31:0]  hwdata,
                         output [31:0] hrdata,
                         output        hready,
                         output        hresp
			 );

   parameter nwords = 1024;

   reg [31:0] 				   mem_rdata;
   reg [31:0] 				   mem [nwords-1:0];

   wire [15:0] 				   low_half;
   wire [7:0] 				   low_byte;
   reg [3:0] 				   wmask;
   reg [31:0] 				   wdata;
   
   wire [29:0] 				   word_addr;
   wire 				   half_sel;
   wire 				   byte_sel;

   reg [29:0] word_addr_reg;
   reg 	      half_sel_reg;
   reg 	      byte_sel_reg;

   assign word_addr = haddr[31:2];
   assign half_sel = haddr[1];
   assign byte_sel = haddr[0];
   
   assign hready = 1'b1;
   assign hresp = `HASTI_RESP_OKAY;

   
   always @(posedge hclk) begin
      word_addr_reg <= word_addr;
      half_sel_reg <= half_sel;
      byte_sel_reg <= byte_sel;
   end

   always @(*) begin
      mem_rdata = mem[word_addr_reg];
   end

   always @(*) begin
      case (hsize)
	`HASTI_SIZE_BYTE : begin
	   wmask = hwrite << haddr[1:0];
	   wdata = {4{hwdata[7:0]}};
	end
	`HASTI_SIZE_HALFWORD : begin
	   wmask = {2{hwrite}} << {haddr[1],1'b0};
	   wdata = {2{hwdata[15:0]}};
	end
	`HASTI_SIZE_WORD : begin
	   wmask = {4{hwrite}};
	   wdata = hwdata;
	end
      endcase // case (hsize)   
   end // always @ begin
   
   integer i;
   always @(posedge hclk) begin
      for (i = 0; i < 4; i = i + 1) begin
	 if (wmask[i]) begin
	    mem[word_addr][8*i +: 8] <= wdata[8*i +: 8];
	 end
      end
   end
   
   assign low_half = half_sel_reg ? mem_rdata[31:16] : mem_rdata[15:0];
   assign low_byte = byte_sel_reg ? low_half[15:8] : low_half[7:0];
   assign hrdata = {mem_rdata[31:16],low_half[15:8],low_byte};

`ifndef SYNTHESIS
   integer i;
   initial begin
      for (i = 0; i < nwords; i = i + 1) begin
	 mem[i] = 0;
      end
   end
`endif
   
endmodule // vscale_hasti_sram

