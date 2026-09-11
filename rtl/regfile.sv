module regfile (
  input  logic        clk,
  input  logic        we,
  input  logic [4:0]  rs1,
  input  logic [4:0]  rs2,
  input  logic [4:0]  rd,
  input  logic [31:0] wd,
  output logic [31:0] rd1,
  output logic [31:0] rd2
);

  logic [31:0] regs [0:31];
  integer i;

  initial begin
    for (i = 0; i < 32; i++)
      regs[i] = 32'd0;
  end

  assign rd1 = (rs1 == 0) ? 32'd0 : regs[rs1];
  assign rd2 = (rs2 == 0) ? 32'd0 : regs[rs2];

  always @(negedge clk) begin
    if (we && rd != 0)
      regs[rd] <= wd;

    regs[0] <= 32'd0;
  end

endmodule