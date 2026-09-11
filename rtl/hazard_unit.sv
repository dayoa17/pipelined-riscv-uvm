module hazard_unit (
  input  logic       idex_mem_read,
  input  logic [4:0] idex_rd,
  input  logic [4:0] ifid_rs1,
  input  logic [4:0] ifid_rs2,
  input  logic       ifid_uses_rs1,
  input  logic       ifid_uses_rs2,
  output logic       load_use_stall
);
  always_comb begin
    load_use_stall = idex_mem_read && (idex_rd != 0) &&
      ((ifid_uses_rs1 && idex_rd == ifid_rs1) ||
       (ifid_uses_rs2 && idex_rd == ifid_rs2));
  end
endmodule
