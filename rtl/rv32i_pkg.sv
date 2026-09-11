package rv32i_pkg;
  typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
    ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND,
    ALU_COPY_B
  } alu_op_e;

  typedef enum logic [2:0] {
    WB_ALU, WB_MEM, WB_PC4, WB_IMM
  } wb_sel_e;

  typedef enum logic [2:0] {
    IMM_I, IMM_S, IMM_B, IMM_U, IMM_J
  } imm_sel_e;

  typedef enum logic [1:0] {
    A_RS1, A_PC, A_ZERO
  } alu_a_sel_e;

  typedef enum logic [1:0] {
    B_RS2, B_IMM, B_FOUR
  } alu_b_sel_e;
endpackage
