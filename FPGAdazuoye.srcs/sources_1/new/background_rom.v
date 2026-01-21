module background_rom (
    input  wire         clk,
    input  wire [18:0]  addr,
    output wire [15:0]  data
);//背景图片加载模块

    blk_mem_gen_0 u_bram_ip (
        .clka   (clk),
        .addra  (addr),   // 输入地址
        .douta  (data)    // 输出背景图片对应位置像素点颜色
    );

endmodule