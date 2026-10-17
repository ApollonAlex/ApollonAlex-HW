// Milestone 3B: initial 64-KiB RAM, single transfer at a time.
// One-cycle registered acknowledge. PicoRV32 keeps mem_valid until mem_ready.
// This is a functional prototype; inferability/BRAM usage is FPGA-dependent.
module HETAProgramRAM (
    input             clk,
    input             resetn,
    input             mem_valid,
    input      [31:0] mem_addr,
    input      [31:0] mem_wdata,
    input       [3:0] mem_wstrb,
    output reg        mem_ready,
    output reg [31:0] mem_rdata,
    output reg [31:0] signature
);
    reg [31:0] mem [0:16383];
    initial begin
        $readmemh("firmware.hex", mem);
    end

    wire [13:0] word_addr = mem_addr[15:2];
    wire write_en = |mem_wstrb;

    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'b0;
            signature <= 32'b0;
        end else begin
            mem_ready <= 1'b0;
            if (mem_valid && !mem_ready) begin
                if (write_en) begin
                    if (mem_wstrb[0]) mem[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
                    if (mem_wstrb[1]) mem[word_addr][15: 8] <= mem_wdata[15: 8];
                    if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
                    if (mem_addr == 32'h0000fffc && mem_wstrb == 4'hf)
                        signature <= mem_wdata;
                end else begin
                    mem_rdata <= mem[word_addr];
                end
                mem_ready <= 1'b1;
            end
        end
    end
endmodule
