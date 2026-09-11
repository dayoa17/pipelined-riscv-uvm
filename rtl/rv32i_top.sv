module rv32i_top(core_if bus);
  rv32i_core dut(
    .clk(bus.clk), .rst_n(bus.rst_n),
    .imem_addr(bus.imem_addr), .imem_rdata(bus.imem_rdata),
    .dmem_valid(bus.dmem_valid), .dmem_we(bus.dmem_we), .dmem_wstrb(bus.dmem_wstrb),
    .dmem_addr(bus.dmem_addr), .dmem_wdata(bus.dmem_wdata), .dmem_rdata(bus.dmem_rdata),
    .retire_valid(bus.retire_valid), .retire_pc(bus.retire_pc), .retire_instr(bus.retire_instr),
    .retire_rd_we(bus.retire_rd_we), .retire_rd(bus.retire_rd), .retire_rd_data(bus.retire_rd_data),
    .retire_mem_we(bus.retire_mem_we), .retire_mem_addr(bus.retire_mem_addr),
    .retire_mem_wdata(bus.retire_mem_wdata), .retire_illegal(bus.retire_illegal)
  );
endmodule
