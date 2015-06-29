`include "vscale_ctrl_constants.vh"

module vscale_core(
                   input         clk,
                   input         reset,
                   input         imem_wait,
                   output [31:0] imem_addr,
                   input [31:0]  imem_rdata,
                   input         imem_badmem_e,
                   input         dmem_wait,
                   output        dmem_en,
                   output        dmem_wen,
                   output [2:0]  dmem_size,
                   output [31:0] dmem_addr,
                   output [31:0] dmem_wdata_delayed,
                   input [31:0]  dmem_rdata,
                   input         dmem_badmem_e
                   );
   
   wire [2:0]                    PC_src_sel;   
   wire [31:0]                   PC_PIF;
   
   
   reg [31:0]                    PC_IF;
   wire                          kill_IF;
   wire                          stall_IF;
   
   
   reg [31:0]                    PC_DX;
   reg [31:0]                    inst_DX;
   
   wire                          stall_DX;
   wire [2:0]                    imm_type;
   wire [31:0]                   imm;
   wire [2:0]                    src_a_sel; // fix width
   wire [2:0]                    src_b_sel; // fix width 
   wire [4:0]                    rs1_addr;
   wire [31:0]                   rs1_data;
   wire [4:0]                    rs2_addr;
   wire [31:0]                   rs2_data; 
   wire [3:0]                    alu_op;
   wire [31:0]                   alu_src_a;
   wire [31:0]                   alu_src_b;
   wire [31:0]                   alu_out; 
   wire                          cmp_true;
   wire                          bypass_rs1;
   wire                          bypass_rs2;
   
   
   
   reg                           PC_WB;
   reg [31:0]                    alu_out_WB;
   reg [31:0]                    store_data_WB;
   
   wire                          stall_WB;
   reg [31:0]                    wb_data_WB;
   wire [4:0]                    reg_to_wr_WB;
   wire                          wr_reg_WB;
   wire [2:0]                    wb_src_WB;   
   
   wire [31:0]                   csr_stvec;
   
   assign csr_stvec = 0; // TODO: fix stvec

   vscale_ctrl ctrl(
                    .clk(clk),
                    .reset(reset),
                    .inst_DX(inst_DX),
                    .imem_wait(imem_wait),
                    .imem_badmem_e(imem_badmem_e),
                    .dmem_wait(dmem_wait),
                    .dmem_badmem_e(dmem_badmem_e),
                    .cmp_true(cmp_true),
                    .PC_src_sel(PC_src_sel),
                    .imm_type(imm_type),
                    .src_a_sel(src_a_sel),
                    .src_b_sel(src_b_sel),
                    .bypass_rs1(bypass_rs1),
                    .bypass_rs2(bypass_rs2),
                    .alu_op(alu_op),
                    .dmem_en(dmem_en),
                    .dmem_wen(dmem_wen),
                    .dmem_size(dmem_size),
                    .wr_reg_WB(wr_reg_WB),
                    .reg_to_wr_WB(reg_to_wr_WB),
                    .wb_src_WB(wb_src_WB),
                    .stall_IF(stall_IF),
                    .kill_IF(kill_IF),
                    .stall_DX(stall_DX),
                    .kill_DX(kill_DX),
                    .stall_WB(stall_WB),
                    .kill_WB(kill_WB),
                    .exception(exception)
                    );
   
   
   vscale_PC_mux PCmux(
                       .PC_src_sel(PC_src_sel),
                       .inst_DX(inst_DX),
                       .alu_out(alu_out),
                       .rs1_data(rs1_data),
                       .PC_IF(PC_IF),
                       .PC_DX(PC_DX),
                       .csr_stvec(csr_stvec),
                       .PC_PIF(PC_PIF)
                       );
   
   assign imem_addr = PC_PIF;
   
   always @(posedge clk) begin
      if (reset) begin
         PC_IF <= 0;
      end else if (~stall_IF) begin
         PC_IF <= PC_PIF;        
      end
   end
   
   always @(posedge clk) begin
      if (reset) begin
         inst_DX <= `RV_NOP;
      end else if (~stall_DX) begin
         if (kill_IF) begin
            inst_DX <= `RV_NOP;
         end else begin
            PC_DX <= PC_IF;
            inst_DX <= imem_rdata;
         end     
      end
   end // always @ (posedge hclk)

   assign rs1_addr = inst_DX[19:15];
   assign rs2_addr = inst_DX[24:20];
   
   vscale_regfile regfile(
                          .clk(clk),
                          .ra1(rs1_addr),
                          .rd1(rs1_data),
                          .ra2(rs2_addr),
                          .rd2(rs2_data),
                          .wen(wr_reg_WB),
                          .wa(reg_to_wr_WB),
                          .wd(wb_data_WB)
                          );
   
   vscale_imm_gen imm_gen(
                          .inst(inst_DX),
                          .imm_type(imm_type),
                          .imm(imm)
                          );
   
   vscale_src_a_mux src_a_mux(
                              .src_a_sel(src_a_sel),
                              .PC_DX(PC_DX),
                              .rs1_data(rs1_data),
                              .alu_src_a(alu_src_a)
                              );

   vscale_src_b_mux src_b_mux(
                              .src_b_sel(src_b_sel),
                              .imm(imm),
                              .rs2_data(rs2_data),
                              .alu_src_b(alu_src_b)
                              );
   
   assign src_a_bypassed = bypass_rs1 ? alu_out_WB : rs1_data;
   assign src_b_bypassed = bypass_rs2 ? alu_out_WB : rs2_data;

   vscale_alu alu(
                  .op(alu_op),
                  .in1(alu_src_a),
                  .in2(alu_src_b),
                  .out(alu_out)
                  );
   
   assign cmp_true = alu_out[0];
   
   
   assign dmem_addr = alu_out;
   
   always @(posedge clk) begin
      if (~stall_WB) begin
         PC_WB <= PC_DX;
         store_data_WB <= rs2_data;
         alu_out_WB <= alu_out;
      end
   end
   
   always @(*) begin
      case (wb_src_WB)
        `WB_SRC_ALU : wb_data_WB = alu_out_WB;
        `WB_SRC_MEM : wb_data_WB = dmem_rdata;
        default : wb_data_WB = alu_out_WB;
      endcase
   end
   
   
   assign dmem_wdata_delayed = store_data_WB;
   
endmodule // vscale_dpath

