package rv32i_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class program_item extends uvm_sequence_item;
    rand int unsigned n_instr;
    rand bit [31:0] instrs[];
    constraint c_size { n_instr inside {[8:128]}; instrs.size() == n_instr; }
    `uvm_object_utils_begin(program_item)
      `uvm_field_int(n_instr, UVM_DEFAULT)
      `uvm_field_array_int(instrs, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="program_item"); super.new(name); endfunction
  endclass

  class retire_item extends uvm_sequence_item;
    bit [31:0] pc, instr;
    bit rd_we;
    bit [4:0] rd;
    bit [31:0] rd_data;
    bit mem_we;
    bit [31:0] mem_addr, mem_wdata;
    bit illegal;
    `uvm_object_utils_begin(retire_item)
      `uvm_field_int(pc, UVM_HEX)
      `uvm_field_int(instr, UVM_HEX)
      `uvm_field_int(rd_we, UVM_DEFAULT)
      `uvm_field_int(rd, UVM_DEFAULT)
      `uvm_field_int(rd_data, UVM_HEX)
      `uvm_field_int(mem_we, UVM_DEFAULT)
      `uvm_field_int(mem_addr, UVM_HEX)
      `uvm_field_int(mem_wdata, UVM_HEX)
      `uvm_field_int(illegal, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="retire_item"); super.new(name); endfunction
  endclass

  class rv32i_sequencer extends uvm_sequencer #(program_item);
    `uvm_component_utils(rv32i_sequencer)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
  endclass

  class rv32i_driver extends uvm_driver #(program_item);
    `uvm_component_utils(rv32i_driver)
    virtual core_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual core_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","core_if not set")
    endfunction
    task run_phase(uvm_phase phase);
      program_item tr;
      int i;
      forever begin
        seq_item_port.get_next_item(tr);
        vif.rst_n <= 0;
        for (i=0; i<1024; i++) begin
          vif.imem[i] = 32'h00000013;
          vif.dmem[i] = 32'd0;
        end
        for (i=0; i<tr.instrs.size() && i<1024; i++) vif.imem[i] = tr.instrs[i];
        repeat(4) @(posedge vif.clk);
        vif.rst_n <= 1;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class rv32i_monitor extends uvm_monitor;
    `uvm_component_utils(rv32i_monitor)
    virtual core_if vif;
    uvm_analysis_port #(retire_item) ap;
    function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual core_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","core_if not set")
    endfunction
    task run_phase(uvm_phase phase);
      retire_item t;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.retire_valid) begin
          t = retire_item::type_id::create("t");
          t.pc = vif.mon_cb.retire_pc;
          t.instr = vif.mon_cb.retire_instr;
          t.rd_we = vif.mon_cb.retire_rd_we;
          t.rd = vif.mon_cb.retire_rd;
          t.rd_data = vif.mon_cb.retire_rd_data;
          t.mem_we = vif.mon_cb.retire_mem_we;
          t.mem_addr = vif.mon_cb.retire_mem_addr;
          t.mem_wdata = vif.mon_cb.retire_mem_wdata;
          t.illegal = vif.mon_cb.retire_illegal;
          ap.write(t);
        end
      end
    endtask
  endclass

  class rv32i_scoreboard extends uvm_subscriber #(retire_item);
    `uvm_component_utils(rv32i_scoreboard)
    bit [31:0] regs[0:31];
    bit [31:0] mem[0:1023];
    bit [31:0] expected_pc;
    int unsigned checked, errors;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void reset_model();
      for (int i=0;i<32;i++) regs[i]='0;
      for (int i=0;i<1024;i++) mem[i]='0;
      expected_pc=0; checked=0; errors=0;
    endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); reset_model(); endfunction

    function automatic bit [31:0] sext12(bit [11:0] x); return {{20{x[11]}},x}; endfunction
    function automatic bit [31:0] imm_i(bit[31:0] i); return sext12(i[31:20]); endfunction
    function automatic bit [31:0] imm_s(bit[31:0] i); return {{20{i[31]}},i[31:25],i[11:7]}; endfunction
    function automatic bit [31:0] imm_b(bit[31:0] i); return {{19{i[31]}},i[31],i[7],i[30:25],i[11:8],1'b0}; endfunction
    function automatic bit [31:0] imm_u(bit[31:0] i); return {i[31:12],12'b0}; endfunction
    function automatic bit [31:0] imm_j(bit[31:0] i); return {{11{i[31]}},i[31],i[19:12],i[20],i[30:21],1'b0}; endfunction

    function void expect_rd(retire_item t, bit we, bit[4:0] rd, bit[31:0] value);
      if (we && rd != 0) begin
        if (!t.rd_we || t.rd != rd || t.rd_data !== value) begin
          errors++;
          `uvm_error("SB",$sformatf("PC=%08x expected x%0d=%08x got we=%0b x%0d=%08x",t.pc,rd,value,t.rd_we,t.rd,t.rd_data))
        end
        regs[rd] = value;
      end else if (t.rd_we) begin
        errors++;
        `uvm_error("SB",$sformatf("Unexpected register write at PC=%08x",t.pc))
      end
      regs[0]=0;
    endfunction

    virtual function void write(retire_item t);
      bit [6:0] op;
      bit [2:0] f3;
      bit [6:0] f7;
      bit [4:0] rs1,rs2,rd;
      bit [31:0] a,b,res,next_pc,addr,raw;
      bit take;
      checked++;
      op=t.instr[6:0]; f3=t.instr[14:12]; f7=t.instr[31:25];
      rs1=t.instr[19:15]; rs2=t.instr[24:20]; rd=t.instr[11:7];
      a=regs[rs1]; b=regs[rs2]; next_pc=t.pc+4;

      if (t.pc !== expected_pc) begin
        errors++;
        `uvm_error("SB",$sformatf("PC mismatch expected=%08x got=%08x",expected_pc,t.pc))
      end

      case(op)
        7'b0110111: expect_rd(t,1,rd,imm_u(t.instr));
        7'b0010111: expect_rd(t,1,rd,t.pc+imm_u(t.instr));
        7'b1101111: begin expect_rd(t,1,rd,t.pc+4); next_pc=t.pc+imm_j(t.instr); end
        7'b1100111: begin expect_rd(t,1,rd,t.pc+4); next_pc=(a+imm_i(t.instr)) & 32'hffff_fffe; end
        7'b1100011: begin
          take=0;
          case(f3)
            3'b000: take=(a==b); 3'b001: take=(a!=b);
            3'b100: take=($signed(a)<$signed(b)); 3'b101: take=($signed(a)>=$signed(b));
            3'b110: take=(a<b); 3'b111: take=(a>=b);
          endcase
          if(take) next_pc=t.pc+imm_b(t.instr);
          expect_rd(t,0,0,0);
        end
        7'b0010011: begin
          case(f3)
            3'b000: res=a+imm_i(t.instr); 3'b010: res=($signed(a)<$signed(imm_i(t.instr)));
            3'b011: res=(a<imm_i(t.instr)); 3'b100: res=a^imm_i(t.instr);
            3'b110: res=a|imm_i(t.instr); 3'b111: res=a&imm_i(t.instr);
            3'b001: res=a<<t.instr[24:20];
            3'b101: begin
 			  if (f7[5])
    			res = $signed(a) >>> t.instr[24:20];
  			  else
    			res = a >> t.instr[24:20];
		end
		  endcase
		  expect_rd(t,1,rd,res);
        end
        7'b0110011: begin
          case(f3)
            3'b000: res=f7[5] ? a-b : a+b; 3'b001: res=a<<b[4:0];
            3'b010: res=($signed(a)<$signed(b)); 3'b011: res=(a<b);
            3'b100: res=a^b;
            3'b101: begin
  			 if (f7[5])
    		   res = $signed(a) >>> b[4:0];
  			else
    		   res = a >> b[4:0];
		end
            3'b110: res=a|b; 
            3'b111: res=a&b;
          endcase
          expect_rd(t,1,rd,res);
        end
        7'b0100011: begin
          addr=a+imm_s(t.instr);
          if(!t.mem_we || t.mem_addr !== {addr[31:2],2'b00}) begin errors++; `uvm_error("SB","Store address/write mismatch") end
          case(f3)
            3'b000: mem[addr[11:2]][8*addr[1:0]+:8]=b[7:0];
            3'b001: begin
              if(addr[1]) mem[addr[11:2]][31:16]=b[15:0];
              else mem[addr[11:2]][15:0]=b[15:0];
            end
            3'b010: mem[addr[11:2]]=b;
          endcase
          expect_rd(t,0,0,0);
        end
        7'b0000011: begin
          addr=a+imm_i(t.instr); raw=mem[addr[11:2]] >> (8*addr[1:0]);
          case(f3)
            3'b000: res={{24{raw[7]}},raw[7:0]};
            3'b001: res={{16{raw[15]}},raw[15:0]};
            3'b010: res=raw;
            3'b100: res={24'd0,raw[7:0]};
            3'b101: res={16'd0,raw[15:0]};
          endcase
          expect_rd(t,1,rd,res);
        end
        7'b0001111: expect_rd(t,0,0,0);
        default: begin
          if(!t.illegal) begin errors++; `uvm_error("SB",$sformatf("Expected illegal for %08x",t.instr)) end
        end
      endcase
      expected_pc=next_pc;
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB",$sformatf("Checked %0d retired instructions; errors=%0d",checked,errors),UVM_NONE)
    endfunction
  endclass

  class rv32i_coverage extends uvm_subscriber #(retire_item);
  `uvm_component_utils(rv32i_coverage)

  bit [6:0] opcode;
  bit [2:0] funct3;
  bit [6:0] funct7;
  bit rd_we, mem_we, illegal;

  covergroup cg;

    cp_opcode: coverpoint opcode {
      bins lui    = {7'h37};
      bins auipc  = {7'h17};
      bins jal    = {7'h6f};
      bins jalr   = {7'h67};
      bins branch = {7'h63};
      bins load   = {7'h03};
      bins store  = {7'h23};
      bins opimm  = {7'h13};
      bins op     = {7'h33};
      bins fence  = {7'h0f};

      ignore_bins system = {7'h73};
    }

    cp_branch_funct3: coverpoint funct3 iff (opcode == 7'h63) {
      bins beq  = {3'b000};
      bins bne  = {3'b001};
      bins blt  = {3'b100};
      bins bge  = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};

      ignore_bins unused = {3'b010, 3'b011};
    }

    cp_load_funct3: coverpoint funct3 iff (opcode == 7'h03) {
      bins lb  = {3'b000};
      bins lh  = {3'b001};
      bins lw  = {3'b010};
      bins lbu = {3'b100};
      bins lhu = {3'b101};

      ignore_bins unused = {3'b011, 3'b110, 3'b111};
    }

    cp_store_funct3: coverpoint funct3 iff (opcode == 7'h23) {
      bins sb = {3'b000};
      bins sh = {3'b001};
      bins sw = {3'b010};

      ignore_bins unused = {3'b011, 3'b100, 3'b101, 3'b110, 3'b111};
    }

    cp_opimm_funct3: coverpoint funct3 iff (opcode == 7'h13) {
      bins addi       = {3'b000};
      bins slli       = {3'b001};
      bins slti       = {3'b010};
      bins sltiu      = {3'b011};
      bins xori       = {3'b100};
      bins shift_right= {3'b101};
      bins ori        = {3'b110};
      bins andi       = {3'b111};
    }

    cp_op_funct3: coverpoint funct3 iff (opcode == 7'h33) {
      bins add_sub    = {3'b000};
      bins sll        = {3'b001};
      bins slt        = {3'b010};
      bins sltu       = {3'b011};
      bins xor_op     = {3'b100};
      bins shift_right= {3'b101};
      bins or_op      = {3'b110};
      bins and_op     = {3'b111};
    }

    cp_funct7_bit5: coverpoint funct7[5]
      iff (
        (opcode == 7'h33 &&
          (funct3 == 3'b000 || funct3 == 3'b101))
        ||
        (opcode == 7'h13 && funct3 == 3'b101)
      ) {
        bins normal     = {0}; 
        bins arithmetic = {1}; 
      }

    cp_rd_write: coverpoint rd_we {
      bins no_write = {0};
      bins write    = {1};
    }

    cp_mem_write: coverpoint mem_we {
      bins no_store = {0};
      bins store    = {1};
    }

    cp_illegal: coverpoint illegal {
      bins legal   = {0};
      bins illegal = {1};
    }

  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new;
  endfunction

  virtual function void write(retire_item t);
    opcode  = t.instr[6:0];
    funct3  = t.instr[14:12];
    funct7  = t.instr[31:25];
    rd_we   = t.rd_we;
    mem_we  = t.mem_we;
    illegal = t.illegal;

    cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(
      "COV",
      $sformatf("Functional coverage = %0.2f%%", cg.get_inst_coverage()),
      UVM_NONE
    )
  endfunction

endclass

  class rv32i_agent extends uvm_agent;
    `uvm_component_utils(rv32i_agent)
    rv32i_sequencer seqr; rv32i_driver drv; rv32i_monitor mon;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr=rv32i_sequencer::type_id::create("seqr",this);
      drv=rv32i_driver::type_id::create("drv",this);
      mon=rv32i_monitor::type_id::create("mon",this);
    endfunction
    function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
  endclass

  class rv32i_env extends uvm_env;
    `uvm_component_utils(rv32i_env)
    rv32i_agent agent; rv32i_scoreboard sb; rv32i_coverage cov;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent=rv32i_agent::type_id::create("agent",this);
      sb=rv32i_scoreboard::type_id::create("sb",this);
      cov=rv32i_coverage::type_id::create("cov",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.mon.ap.connect(sb.analysis_export);
      agent.mon.ap.connect(cov.analysis_export);
    endfunction
  endclass

function automatic bit[31:0] enc_r(
  bit[6:0] f7,
  bit[4:0] rs2,
  bit[4:0] rs1,
  bit[2:0] f3,
  bit[4:0] rd,
  bit[6:0] op
);
  return {f7, rs2, rs1, f3, rd, op};
endfunction


function automatic bit[31:0] enc_i(
  int imm,
  bit[4:0] rs1,
  bit[2:0] f3,
  bit[4:0] rd,
  bit[6:0] op
);
  return {imm[11:0], rs1, f3, rd, op};
endfunction


function automatic bit[31:0] enc_s(
  int imm,
  bit[4:0] rs2,
  bit[4:0] rs1,
  bit[2:0] f3
);
  return {
    imm[11:5],
    rs2,
    rs1,
    f3,
    imm[4:0],
    7'h23
  };
endfunction


function automatic bit[31:0] enc_b(
  int imm,
  bit[4:0] rs2,
  bit[4:0] rs1,
  bit[2:0] f3
);
  return {
    imm[12],
    imm[10:5],
    rs2,
    rs1,
    f3,
    imm[4:1],
    imm[11],
    7'h63
  };
endfunction


function automatic bit[31:0] enc_u(
  int imm,
  bit[4:0] rd,
  bit[6:0] op
);
  return {
    imm[31:12],
    rd,
    op
  };
endfunction


function automatic bit[31:0] enc_j(
  int imm,
  bit[4:0] rd
);
  return {
    imm[20],
    imm[10:1],
    imm[11],
    imm[19:12],
    rd,
    7'h6f
  };
endfunction
      
  class directed_seq extends uvm_sequence #(program_item);
    `uvm_object_utils(directed_seq)
    function new(string name="directed_seq"); super.new(name); endfunction
    task body();
      program_item p=program_item::type_id::create("p");
      start_item(p);
      p.n_instr=24; p.instrs=new[p.n_instr];
      foreach(p.instrs[i]) p.instrs[i]=32'h00000013;
      p.instrs[0]=enc_i(5,0,3'b000,1,7'h13);        
      p.instrs[1]=enc_i(7,0,3'b000,2,7'h13);       
      p.instrs[2]=enc_r(0,2,1,3'b000,3,7'h33);      
      p.instrs[3]=enc_r(7'h20,1,3,3'b000,4,7'h33);  
      p.instrs[4]=enc_s(0,4,0,3'b010);             
      p.instrs[5]=enc_i(0,0,3'b010,5,7'h03);       
      p.instrs[6]=enc_r(0,1,5,3'b000,6,7'h33);      
      p.instrs[7]=enc_b(8,6,6,3'b000);              
      p.instrs[8]=enc_i(99,0,3'b000,7,7'h13);     
      p.instrs[9]=enc_i(42,0,3'b000,7,7'h13);    
      p.instrs[10]=enc_i(1,7,3'b001,8,7'h13);    
      p.instrs[11]=enc_i(-1,0,3'b000,9,7'h13);      
      p.instrs[12]=enc_i(1,9,3'b101,10,7'h13) | (32'h20<<25); 
      finish_item(p);
    endtask
  endclass

  class random_alu_seq extends uvm_sequence #(program_item);
  `uvm_object_utils(random_alu_seq)

  function new(string name="random_alu_seq");
    super.new(name);
  endfunction

  task body();

    program_item p = program_item::type_id::create("p");

    bit [4:0] rd, rs1, rs2;
    bit [2:0] f3;
    bit [6:0] f7;
    int imm;
    int i;

    start_item(p);

    p.n_instr = 128;
    p.instrs = new[p.n_instr];

    foreach (p.instrs[j])
      p.instrs[j] = 32'h00000013;

    p.instrs[0] = enc_i(1, 0, 3'b000, 1, 7'h13);
    p.instrs[1] = enc_i(2, 0, 3'b000, 2, 7'h13);
    p.instrs[2] = enc_i(-1,0, 3'b000, 3, 7'h13); 

    p.instrs[3] = enc_u(32'h12345000, 4, 7'h37); 
    p.instrs[4] = enc_u(32'h00001000, 5, 7'h17); 

    p.instrs[5] = enc_s(0, 3, 0, 3'b000); 
    p.instrs[6] = enc_s(4, 3, 0, 3'b001); 
    p.instrs[7] = enc_s(8, 3, 0, 3'b010); 

    p.instrs[8]  = enc_i(0, 0, 3'b000, 6, 7'h03);
    p.instrs[9]  = enc_i(4, 0, 3'b001, 7, 7'h03); 
    p.instrs[10] = enc_i(8, 0, 3'b010, 8, 7'h03); 
    p.instrs[11] = enc_i(0, 0, 3'b100, 9, 7'h03);
    p.instrs[12] = enc_i(4, 0, 3'b101,10, 7'h03); 

    p.instrs[13] = enc_b(8, 2, 1, 3'b000); 
    p.instrs[14] = enc_b(8, 1, 1, 3'b001); 
    p.instrs[15] = enc_b(8, 1, 2, 3'b100); 
    p.instrs[16] = enc_b(8, 2, 1, 3'b101); 
    p.instrs[17] = enc_b(8, 1, 2, 3'b110); 
    p.instrs[18] = enc_b(8, 2, 1, 3'b111); 

    p.instrs[19] = enc_j(4, 11);

    p.instrs[20] = enc_i(88, 0, 3'b000, 12, 7'h13);
    p.instrs[21] = enc_i(0, 12, 3'b000, 13, 7'h67);

    p.instrs[22] = 32'h0000000f;

    p.instrs[23] = enc_i(5,  1, 3'b000,14,7'h13); 
    p.instrs[24] = enc_i(1,  1, 3'b001,14,7'h13); 
    p.instrs[25] = enc_i(10, 1, 3'b010,14,7'h13);
    p.instrs[26] = enc_i(10, 1, 3'b011,14,7'h13);
    p.instrs[27] = enc_i(7,  1, 3'b100,14,7'h13); 

    p.instrs[28] =
      enc_i(1, 3, 3'b101,14,7'h13);

    p.instrs[29] =
      enc_i(1, 3, 3'b101,14,7'h13) |
      (32'h20 << 25);

    p.instrs[30] = enc_i(7, 1, 3'b110,14,7'h13); 
    p.instrs[31] = enc_i(7, 1, 3'b111,14,7'h13); 

    p.instrs[32] = enc_r(7'h00,2,1,3'b000,15,7'h33); // ADD
    p.instrs[33] = enc_r(7'h20,2,1,3'b000,15,7'h33); // SUB
    p.instrs[34] = enc_r(7'h00,2,1,3'b001,15,7'h33); // SLL
    p.instrs[35] = enc_r(7'h00,2,1,3'b010,15,7'h33); // SLT
    p.instrs[36] = enc_r(7'h00,2,1,3'b011,15,7'h33); // SLTU
    p.instrs[37] = enc_r(7'h00,2,1,3'b100,15,7'h33); // XOR
    p.instrs[38] = enc_r(7'h00,2,1,3'b101,15,7'h33); // SRL
    p.instrs[39] = enc_r(7'h20,2,3,3'b101,15,7'h33); // SRA
    p.instrs[40] = enc_r(7'h00,2,1,3'b110,15,7'h33); // OR
    p.instrs[41] = enc_r(7'h00,2,1,3'b111,15,7'h33); // AND

    p.instrs[42] = 32'h00000073;

    for (i = 43; i < p.n_instr; i++) begin

      rd  = $urandom_range(1,15);
      rs1 = $urandom_range(0,15);
      rs2 = $urandom_range(0,15);

      if ($urandom_range(0,1) == 0) begin

        f3 = $urandom_range(0,7);

        imm = $urandom_range(0,63) - 32;

        case (f3)

          3'b001:
            p.instrs[i] =
              enc_i(
                $urandom_range(0,31),
                rs1,
                f3,
                rd,
                7'h13
              );

          3'b101: begin

            p.instrs[i] =
              enc_i(
                $urandom_range(0,31),
                rs1,
                f3,
                rd,
                7'h13
              );

            if ($urandom_range(0,1))
              p.instrs[i] |= (32'h20 << 25);

          end

          default:
            p.instrs[i] =
              enc_i(
                imm,
                rs1,
                f3,
                rd,
                7'h13
              );

        endcase

      end
      else begin

        f3 = $urandom_range(0,7);
        f7 = 7'h00;

        if (
          (f3 == 3'b000 || f3 == 3'b101) &&
          $urandom_range(0,1)
        )
          f7 = 7'h20;

        p.instrs[i] =
          enc_r(
            f7,
            rs2,
            rs1,
            f3,
            rd,
            7'h33
          );

      end

    end

    finish_item(p);

  endtask
endclass

  class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    rv32i_env env;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=rv32i_env::type_id::create("env",this); endfunction
  endclass

  class directed_test extends base_test;
    `uvm_component_utils(directed_test)
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
      directed_seq seq=directed_seq::type_id::create("seq");
      phase.raise_objection(this); seq.start(env.agent.seqr); repeat(80) @(posedge env.agent.drv.vif.clk); phase.drop_objection(this);
    endtask
  endclass

  class random_test extends base_test;
    `uvm_component_utils(random_test)
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
      random_alu_seq seq=random_alu_seq::type_id::create("seq");
      phase.raise_objection(this); seq.start(env.agent.seqr); repeat(180) @(posedge env.agent.drv.vif.clk); phase.drop_objection(this);
    endtask
  endclass
endpackage