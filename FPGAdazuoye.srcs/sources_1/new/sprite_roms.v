//玩家 and 敌人图片加载模块
module player_rom (
    input  wire [11:0] addr,
    output wire [15:0] data
);
    reg [15:0] mem [0:1599];
    initial $readmemh("final.mem", mem);//玩家图片导入
    assign data = mem[addr];//传回对应位置的玩家图片的像素点颜色
endmodule

module enemy_rom (
    input  wire [11:0] addr,
    output wire [15:0] data
);
    reg [15:0] mem [0:1599];
    initial $readmemh("enemy.mem", mem);//敌人图片导入
    assign data = mem[addr];//传回对应位置敌人图片的像素点颜色
endmodule