module ez8_cpu (
    input clk,
    input reset,
    input pause,

    input [11:0] instr_writeaddr,
    input [15:0] instr_writedata,
    input instr_write_en,

    output stopped,
    output error,
    output [7:0] accum_out
);

wire [11:0] pc;
wire pc_kill;
wire pc_stopped;
wire kill_write = pc_kill || pause || pc_stopped;

assign stopped = pc_stopped;
wire running = !pause && !pc_stopped;

wire [11:0] goto_addr;
wire goto;
wire call;
wire skip;
wire ret;

pc_ctrl pcc (
    .clk (clk),
    .reset (reset),
    .pause (pause),

    .goto_addr (goto_addr),
    .goto (goto),
    .call (call),
    .skip (skip),
    .ret (ret),
    .error (error),
    .stopped (pc_stopped),

    .pc_out (pc),
    .kill (pc_kill)
);

wire [15:0] instr;
assign goto_addr = instr[11:0];
assign goto = (instr[15:13] == 3'b100);
assign call = (instr[15:12] == 4'b1001);
assign ret = (instr[15:12] == 4'b1101);

instr_mem im (
    .rdclock (clk),
    .wrclock (clk),
    .rdclocken (running),
    .rdaddress (pc),
    .q (instr),
    .wraddress (instr_writeaddr),
    .data (instr_writedata),
    .wren (instr_write_en)
);

wire z;
wire c_forward;
wire c_backward;
wire z_write;
wire c_write;
wire gie_write;
wire gie;

reg [3:0] opcode;
reg [7:0] operand;
reg [2:0] selector;
reg direction;


always @(posedge clk) begin
    opcode <= instr[15:12];
    operand <= instr[11:4];
    selector <= instr[3:1];
    direction <= instr[0];
end

wire [7:0] mem_writedata;
wire mem_write_en;
wire [7:0] mem_readaddr = instr[11:4];
wire [7:0] mem_readdata;
wire accum_write;
wire [7:0] accum;

assign accum_out = accum;

mem_ctrl mc (
    .clk (clk),
    .reset (reset),
    .pause (!running),

    .zin (z),
    .z_write (z_write && !kill_write),
    .cin (c_backward),
    .c_write (c_write && !kill_write),
    .cout (c_forward),
    .giein (gie),
    .gie_write (gie_write),

    .writeaddr (operand),
    .writedata (mem_writedata),
    .write_en (mem_write_en && !kill_write),

    .readaddr (mem_readaddr),
    .readdata (mem_readdata),

    .accum_write (accum_write && !kill_write),
    .accum_out (accum)
);

alu alu0 (
    .opcode (opcode),
    .operand (operand),
    .regvalue (mem_readdata),
    .accum (accum),
    .selector (selector),
    .direction (direction),
    .cin (c_forward),

    .result (mem_writedata),
    .accum_write (accum_write),
    .reg_write (mem_write_en),
    .z_write (z_write),
    .zout (z),
    .c_write (c_write),
    .cout (c_backward),
    .gieout (gie),
    .gie_write (gie_write),
    .skip (skip)
);

endmodule