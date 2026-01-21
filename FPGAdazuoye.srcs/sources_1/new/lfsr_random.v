module lfsr_random (
    input  wire        clk,
    input  wire        rst_n,
    output wire [15:0] rand_out
);//随机数生成模块
    reg [15:0] lfsr_reg;
    wire feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            lfsr_reg <= 16'hACE1; // 初始种子
        else 
            lfsr_reg <= {lfsr_reg[14:0], feedback};
    end
    assign rand_out = lfsr_reg;
endmodule