module forwarding_unit (
  input  logic [4:0] idex_rs1,
  input  logic [4:0] idex_rs2,
  input  logic [4:0] exmem_rd,
  input  logic       exmem_reg_write,
  input  logic       exmem_mem_read,
  input  logic [4:0] memwb_rd,
  input  logic       memwb_reg_write,
  output logic [1:0] fwd_a,
  output logic [1:0] fwd_b
);
  always_comb begin
    fwd_a = 2'b00;
    fwd_b = 2'b00;
    // EX/MEM result is not forwardable for a load until MEM/WB.
    if (exmem_reg_write && !exmem_mem_read && exmem_rd != 0 && exmem_rd == idex_rs1) fwd_a = 2'b10;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs1) fwd_a = 2'b01;

    if (exmem_reg_write && !exmem_mem_read && exmem_rd != 0 && exmem_rd == idex_rs2) fwd_b = 2'b10;
    else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs2) fwd_b = 2'b01;
  end
endmodule
