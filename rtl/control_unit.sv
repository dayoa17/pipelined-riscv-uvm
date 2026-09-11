module control_unit import rv32i_pkg::*; (
  input  logic [31:0] instr,
  output logic        uses_rs1,
  output logic        uses_rs2,
  output logic        reg_write,
  output logic        mem_read,
  output logic        mem_write,
  output logic        branch,
  output logic        jal,
  output logic        jalr,
  output logic        illegal,
  output alu_op_e     alu_op,
  output alu_a_sel_e  alu_a_sel,
  output alu_b_sel_e  alu_b_sel,
  output wb_sel_e     wb_sel,
  output imm_sel_e    imm_sel
);
  logic [6:0] opcode, funct7;
  logic [2:0] funct3;
  assign opcode = instr[6:0];
  assign funct3 = instr[14:12];
  assign funct7 = instr[31:25];

  always_comb begin
    uses_rs1 = 0; uses_rs2 = 0; reg_write = 0; mem_read = 0; mem_write = 0;
    branch = 0; jal = 0; jalr = 0; illegal = 0;
    alu_op = ALU_ADD; alu_a_sel = A_RS1; alu_b_sel = B_RS2;
    wb_sel = WB_ALU; imm_sel = IMM_I;

    unique case (opcode)
      7'b0110111: begin // LUI
        reg_write = 1; alu_a_sel = A_ZERO; alu_b_sel = B_IMM;
        alu_op = ALU_COPY_B; wb_sel = WB_ALU; imm_sel = IMM_U;
      end
      7'b0010111: begin // AUIPC
        reg_write = 1; alu_a_sel = A_PC; alu_b_sel = B_IMM;
        alu_op = ALU_ADD; wb_sel = WB_ALU; imm_sel = IMM_U;
      end
      7'b1101111: begin // JAL
        reg_write = 1; jal = 1; alu_a_sel = A_PC; alu_b_sel = B_IMM;
        alu_op = ALU_ADD; wb_sel = WB_PC4; imm_sel = IMM_J;
      end
      7'b1100111: begin // JALR
        if (funct3 != 3'b000) illegal = 1;
        uses_rs1 = 1; reg_write = 1; jalr = 1; alu_a_sel = A_RS1;
        alu_b_sel = B_IMM; alu_op = ALU_ADD; wb_sel = WB_PC4; imm_sel = IMM_I;
      end
      7'b1100011: begin // BRANCH
        uses_rs1 = 1; uses_rs2 = 1; branch = 1; imm_sel = IMM_B;
        alu_a_sel = A_PC; alu_b_sel = B_IMM; alu_op = ALU_ADD;
        if (!(funct3 inside {3'b000,3'b001,3'b100,3'b101,3'b110,3'b111})) illegal = 1;
      end
      7'b0000011: begin // LOAD
        uses_rs1 = 1; reg_write = 1; mem_read = 1; imm_sel = IMM_I;
        alu_a_sel = A_RS1; alu_b_sel = B_IMM; alu_op = ALU_ADD; wb_sel = WB_MEM;
        if (!(funct3 inside {3'b000,3'b001,3'b010,3'b100,3'b101})) illegal = 1;
      end
      7'b0100011: begin // STORE
        uses_rs1 = 1; uses_rs2 = 1; mem_write = 1; imm_sel = IMM_S;
        alu_a_sel = A_RS1; alu_b_sel = B_IMM; alu_op = ALU_ADD;
        if (!(funct3 inside {3'b000,3'b001,3'b010})) illegal = 1;
      end
      7'b0010011: begin // OP-IMM
        uses_rs1 = 1; reg_write = 1; imm_sel = IMM_I;
        alu_a_sel = A_RS1; alu_b_sel = B_IMM; wb_sel = WB_ALU;
        unique case (funct3)
          3'b000: alu_op = ALU_ADD;  // ADDI
          3'b010: alu_op = ALU_SLT;  // SLTI
          3'b011: alu_op = ALU_SLTU; // SLTIU
          3'b100: alu_op = ALU_XOR;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          3'b001: begin alu_op = ALU_SLL; if (funct7 != 7'b0000000) illegal = 1; end
          3'b101: begin
            if (funct7 == 7'b0000000) alu_op = ALU_SRL;
            else if (funct7 == 7'b0100000) alu_op = ALU_SRA;
            else illegal = 1;
          end
          default: illegal = 1;
        endcase
      end
      7'b0110011: begin // OP
        uses_rs1 = 1; uses_rs2 = 1; reg_write = 1; alu_a_sel = A_RS1;
        alu_b_sel = B_RS2; wb_sel = WB_ALU;
        unique case (funct3)
          3'b000: begin
            if (funct7 == 7'b0000000) alu_op = ALU_ADD;
            else if (funct7 == 7'b0100000) alu_op = ALU_SUB;
            else illegal = 1;
          end
          3'b001: begin alu_op = ALU_SLL; if (funct7 != 0) illegal = 1; end
          3'b010: begin alu_op = ALU_SLT; if (funct7 != 0) illegal = 1; end
          3'b011: begin alu_op = ALU_SLTU; if (funct7 != 0) illegal = 1; end
          3'b100: begin alu_op = ALU_XOR; if (funct7 != 0) illegal = 1; end
          3'b101: begin
            if (funct7 == 7'b0000000) alu_op = ALU_SRL;
            else if (funct7 == 7'b0100000) alu_op = ALU_SRA;
            else illegal = 1;
          end
          3'b110: begin alu_op = ALU_OR; if (funct7 != 0) illegal = 1; end
          3'b111: begin alu_op = ALU_AND; if (funct7 != 0) illegal = 1; end
          default: illegal = 1;
        endcase
      end
      7'b0001111: begin // FENCE treated as architectural NOP
      end
      7'b1110011: begin // SYSTEM: flag as illegal/trap in this educational core
        illegal = 1;
      end
      default: illegal = 1;
    endcase
  end
endmodule
