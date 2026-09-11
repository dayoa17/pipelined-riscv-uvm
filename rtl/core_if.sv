interface core_if(input logic clk);
  logic rst_n;
  logic [31:0] imem_addr, imem_rdata;
  logic dmem_valid, dmem_we;
  logic [3:0] dmem_wstrb;
  logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
  logic retire_valid;
  logic [31:0] retire_pc, retire_instr;
  logic retire_rd_we;
  logic [4:0] retire_rd;
  logic [31:0] retire_rd_data;
  logic retire_mem_we;
  logic [31:0] retire_mem_addr, retire_mem_wdata;
  logic retire_illegal;

  // Simple zero-wait-state memory used by the UVM environment.
  logic [31:0] imem [0:1023];
  logic [31:0] dmem [0:1023];

  assign imem_rdata = imem[imem_addr[11:2]];
  assign dmem_rdata = dmem[dmem_addr[11:2]];

  always_ff @(posedge clk) begin
    if (dmem_valid && dmem_we) begin
      if (dmem_wstrb[0]) dmem[dmem_addr[11:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem[dmem_addr[11:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem[dmem_addr[11:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem[dmem_addr[11:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  clocking mon_cb @(negedge clk);
    input retire_valid, retire_pc, retire_instr, retire_rd_we, retire_rd,
          retire_rd_data, retire_mem_we, retire_mem_addr, retire_mem_wdata,
          retire_illegal;
  endclocking
endinterface
