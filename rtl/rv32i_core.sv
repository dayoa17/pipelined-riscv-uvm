module rv32i_core import rv32i_pkg::*; (
  input  logic        clk,
  input  logic        rst_n,

  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  output logic        dmem_valid,
  output logic        dmem_we,
  output logic [3:0]  dmem_wstrb,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  input  logic [31:0] dmem_rdata,

  output logic        retire_valid,
  output logic [31:0] retire_pc,
  output logic [31:0] retire_instr,
  output logic        retire_rd_we,
  output logic [4:0]  retire_rd,
  output logic [31:0] retire_rd_data,
  output logic        retire_mem_we,
  output logic [31:0] retire_mem_addr,
  output logic [31:0] retire_mem_wdata,
  output logic        retire_illegal
);
  // IF state
  logic [31:0] pc_f;
  assign imem_addr = pc_f;

  // IF/ID
  logic        ifid_valid;
  logic [31:0] ifid_pc, ifid_instr;

  // ID decode
  logic [4:0] id_rs1, id_rs2, id_rd;
  logic [31:0] id_rs1_data, id_rs2_data, id_imm;
  logic id_uses_rs1, id_uses_rs2, id_reg_write, id_mem_read, id_mem_write;
  logic id_branch, id_jal, id_jalr, id_illegal;
  alu_op_e id_alu_op; alu_a_sel_e id_alu_a_sel; alu_b_sel_e id_alu_b_sel;
  wb_sel_e id_wb_sel; imm_sel_e id_imm_sel;
  assign id_rs1 = ifid_instr[19:15];
  assign id_rs2 = ifid_instr[24:20];
  assign id_rd  = ifid_instr[11:7];

  control_unit u_ctrl(.instr(ifid_instr), .uses_rs1(id_uses_rs1), .uses_rs2(id_uses_rs2),
    .reg_write(id_reg_write), .mem_read(id_mem_read), .mem_write(id_mem_write),
    .branch(id_branch), .jal(id_jal), .jalr(id_jalr), .illegal(id_illegal),
    .alu_op(id_alu_op), .alu_a_sel(id_alu_a_sel), .alu_b_sel(id_alu_b_sel),
    .wb_sel(id_wb_sel), .imm_sel(id_imm_sel));
  imm_gen u_imm(.instr(ifid_instr), .sel(id_imm_sel), .imm(id_imm));

  // MEM/WB declarations needed by register file writeback
  logic        memwb_valid, memwb_reg_write, memwb_mem_write, memwb_illegal;
  logic [4:0]  memwb_rd;
  logic [31:0] memwb_pc, memwb_instr, memwb_alu_result, memwb_mem_data, memwb_pc4;
  logic [31:0] memwb_mem_addr, memwb_store_data;
  wb_sel_e     memwb_wb_sel;
  logic [31:0] wb_data;
  always_comb begin
    unique case (memwb_wb_sel)
      WB_MEM: wb_data = memwb_mem_data;
      WB_PC4: wb_data = memwb_pc4;
      default: wb_data = memwb_alu_result;
    endcase
  end

  regfile u_rf(.clk(clk), .we(memwb_valid && memwb_reg_write && !memwb_illegal),
    .rs1(id_rs1), .rs2(id_rs2), .rd(memwb_rd), .wd(wb_data),
    .rd1(id_rs1_data), .rd2(id_rs2_data));

  // ID/EX
  logic        idex_valid, idex_reg_write, idex_mem_read, idex_mem_write;
  logic        idex_branch, idex_jal, idex_jalr, idex_illegal;
  logic [31:0] idex_pc, idex_instr, idex_rs1_data, idex_rs2_data, idex_imm;
  logic [4:0]  idex_rs1, idex_rs2, idex_rd;
  alu_op_e     idex_alu_op; alu_a_sel_e idex_alu_a_sel; alu_b_sel_e idex_alu_b_sel;
  wb_sel_e     idex_wb_sel;

  // Hazard detection
  logic load_use_stall;
  hazard_unit u_haz(.idex_mem_read(idex_mem_read && idex_valid), .idex_rd(idex_rd),
    .ifid_rs1(id_rs1), .ifid_rs2(id_rs2), .ifid_uses_rs1(id_uses_rs1),
    .ifid_uses_rs2(id_uses_rs2), .load_use_stall(load_use_stall));

  // EX/MEM
  logic        exmem_valid, exmem_reg_write, exmem_mem_read, exmem_mem_write, exmem_illegal;
  logic [31:0] exmem_pc, exmem_instr, exmem_alu_result, exmem_store_data, exmem_pc4;
  logic [4:0]  exmem_rd;
  logic [2:0]  exmem_funct3;
  wb_sel_e     exmem_wb_sel;

  logic [1:0] fwd_a, fwd_b;
  forwarding_unit u_fwd(.idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
    .exmem_rd(exmem_rd), .exmem_reg_write(exmem_reg_write && exmem_valid),
    .exmem_mem_read(exmem_mem_read), .memwb_rd(memwb_rd),
    .memwb_reg_write(memwb_reg_write && memwb_valid), .fwd_a(fwd_a), .fwd_b(fwd_b));

  logic [31:0] ex_rs1, ex_rs2, ex_alu_a, ex_alu_b, ex_result;
  always_comb begin
    unique case (fwd_a)
      2'b10: ex_rs1 = exmem_alu_result;
      2'b01: ex_rs1 = wb_data;
      default: ex_rs1 = idex_rs1_data;
    endcase
    unique case (fwd_b)
      2'b10: ex_rs2 = exmem_alu_result;
      2'b01: ex_rs2 = wb_data;
      default: ex_rs2 = idex_rs2_data;
    endcase

    unique case (idex_alu_a_sel)
      A_PC:   ex_alu_a = idex_pc;
      A_ZERO: ex_alu_a = 32'd0;
      default: ex_alu_a = ex_rs1;
    endcase
    unique case (idex_alu_b_sel)
      B_IMM: ex_alu_b = idex_imm;
      B_FOUR: ex_alu_b = 32'd4;
      default: ex_alu_b = ex_rs2;
    endcase
  end
  alu u_alu(.a(ex_alu_a), .b(ex_alu_b), .op(idex_alu_op), .y(ex_result));

  logic branch_cond, redirect_ex;
  logic [31:0] redirect_target;
  always_comb begin
    branch_cond = 1'b0;
    unique case (idex_instr[14:12])
      3'b000: branch_cond = (ex_rs1 == ex_rs2); // BEQ
      3'b001: branch_cond = (ex_rs1 != ex_rs2); // BNE
      3'b100: branch_cond = ($signed(ex_rs1) <  $signed(ex_rs2)); // BLT
      3'b101: branch_cond = ($signed(ex_rs1) >= $signed(ex_rs2)); // BGE
      3'b110: branch_cond = (ex_rs1 <  ex_rs2); // BLTU
      3'b111: branch_cond = (ex_rs1 >= ex_rs2); // BGEU
      default: branch_cond = 1'b0;
    endcase
    redirect_ex = idex_valid && !idex_illegal && (idex_jal || idex_jalr || (idex_branch && branch_cond));
    if (idex_jalr) redirect_target = (ex_rs1 + idex_imm) & 32'hffff_fffe;
    else redirect_target = idex_pc + idex_imm;
  end

  // Data memory formatting (single-cycle response assumed)
  logic [31:0] load_value, shifted_read, aligned_store_data;
  logic [1:0] byte_off;
  assign byte_off = exmem_alu_result[1:0];
  assign dmem_valid = exmem_valid && (exmem_mem_read || exmem_mem_write) && !exmem_illegal;
  assign dmem_we = exmem_mem_write;
  assign dmem_addr = {exmem_alu_result[31:2], 2'b00};

  always_comb begin
    dmem_wstrb = 4'b0000;
    aligned_store_data = 32'd0;
    unique case (exmem_funct3)
      3'b000: begin dmem_wstrb = 4'b0001 << byte_off; aligned_store_data = exmem_store_data << (8*byte_off); end // SB
      3'b001: begin dmem_wstrb = byte_off[1] ? 4'b1100 : 4'b0011; aligned_store_data = exmem_store_data << (8*byte_off); end // SH
      default: begin dmem_wstrb = 4'b1111; aligned_store_data = exmem_store_data; end // SW
    endcase
    dmem_wdata = aligned_store_data;

    shifted_read = dmem_rdata >> (8*byte_off);
    unique case (exmem_funct3)
      3'b000: load_value = {{24{shifted_read[7]}}, shifted_read[7:0]};   // LB
      3'b001: load_value = {{16{shifted_read[15]}}, shifted_read[15:0]}; // LH
      3'b010: load_value = shifted_read;                                  // LW
      3'b100: load_value = {24'd0, shifted_read[7:0]};                    // LBU
      3'b101: load_value = {16'd0, shifted_read[15:0]};                   // LHU
      default: load_value = 32'd0;
    endcase
  end

  // Pipeline registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_f <= 32'd0;
      ifid_valid <= 1'b0;
      idex_valid <= 1'b0;
      exmem_valid <= 1'b0;
      memwb_valid <= 1'b0;
    end else begin
      // WB <= MEM
      memwb_valid <= exmem_valid;
      memwb_pc <= exmem_pc;
      memwb_instr <= exmem_instr;
      memwb_reg_write <= exmem_reg_write;
      memwb_mem_write <= exmem_mem_write;
      memwb_illegal <= exmem_illegal;
      memwb_rd <= exmem_rd;
      memwb_alu_result <= exmem_alu_result;
      memwb_mem_data <= load_value;
      memwb_pc4 <= exmem_pc4;
      memwb_wb_sel <= exmem_wb_sel;
      memwb_mem_addr <= dmem_addr;
      memwb_store_data <= dmem_wdata;

      // MEM <= EX
      exmem_valid <= idex_valid;
      exmem_pc <= idex_pc;
      exmem_instr <= idex_instr;
      exmem_reg_write <= idex_reg_write;
      exmem_mem_read <= idex_mem_read;
      exmem_mem_write <= idex_mem_write;
      exmem_illegal <= idex_illegal;
      exmem_rd <= idex_rd;
      exmem_alu_result <= ex_result;
      exmem_store_data <= ex_rs2;
      exmem_pc4 <= idex_pc + 32'd4;
      exmem_wb_sel <= idex_wb_sel;
      exmem_funct3 <= idex_instr[14:12];

      if (redirect_ex) begin
        pc_f <= redirect_target;
        ifid_valid <= 1'b0;
        idex_valid <= 1'b0;
      end else if (load_use_stall) begin
        // Hold IF/ID and PC; inject bubble into EX.
        pc_f <= pc_f;
        ifid_valid <= ifid_valid;
        idex_valid <= 1'b0;
      end else begin
        // ID <= IF
        idex_valid <= ifid_valid;
        idex_pc <= ifid_pc;
        idex_instr <= ifid_instr;
        idex_rs1_data <= id_rs1_data;
        idex_rs2_data <= id_rs2_data;
        idex_imm <= id_imm;
        idex_rs1 <= id_rs1;
        idex_rs2 <= id_rs2;
        idex_rd <= id_rd;
        idex_reg_write <= id_reg_write;
        idex_mem_read <= id_mem_read;
        idex_mem_write <= id_mem_write;
        idex_branch <= id_branch;
        idex_jal <= id_jal;
        idex_jalr <= id_jalr;
        idex_illegal <= id_illegal;
        idex_alu_op <= id_alu_op;
        idex_alu_a_sel <= id_alu_a_sel;
        idex_alu_b_sel <= id_alu_b_sel;
        idex_wb_sel <= id_wb_sel;

        // IF fetch
        ifid_valid <= 1'b1;
        ifid_pc <= pc_f;
        ifid_instr <= imem_rdata;
        pc_f <= pc_f + 32'd4;
      end
    end
  end

  // Architectural retire trace (one instruction/cycle max)
  assign retire_valid = memwb_valid;
  assign retire_pc = memwb_pc;
  assign retire_instr = memwb_instr;
  assign retire_rd_we = memwb_valid && memwb_reg_write && !memwb_illegal && memwb_rd != 0;
  assign retire_rd = memwb_rd;
  assign retire_rd_data = wb_data;
  assign retire_mem_we = memwb_valid && memwb_mem_write && !memwb_illegal;
  assign retire_mem_addr = memwb_mem_addr;
  assign retire_mem_wdata = memwb_store_data;
  assign retire_illegal = memwb_illegal;
endmodule
