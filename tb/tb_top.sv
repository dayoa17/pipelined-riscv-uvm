`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import rv32i_uvm_pkg::*;
  logic clk=0;
  always #5 clk=~clk;
  core_if vif(clk);
  rv32i_top top(vif);

  initial begin
    vif.rst_n=0;
    uvm_config_db#(virtual core_if)::set(null,"*","vif",vif);
    run_test();
  end
endmodule
