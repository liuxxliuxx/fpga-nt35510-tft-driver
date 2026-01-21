module matrix_key (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] row_in,
    output reg  [3:0] col_out,
    output reg        key_up, key_down, key_left, key_right, key_shoot
);//4x4按键矩阵模块
    reg [19:0] cnt;
    wire scan_clk = cnt[16];
    always @(posedge clk) cnt <= cnt + 1;

    reg [1:0] col_idx;
    always @(posedge scan_clk) begin
        col_idx <= col_idx + 1;
        case(col_idx)//按列扫描
            0: col_out <= 4'b1110;
            1: col_out <= 4'b1101;
            2: col_out <= 4'b1011;
            3: col_out <= 4'b0111;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) {key_up, key_down, key_left, key_right, key_shoot} <= 0;
        else begin
            if (col_out[1]==0 && row_in[0]==0) key_up <= 1;//如果扫描到第二列，并且第一行的按钮按下，则上变量置1
            else if(col_out[1]==0) key_up<=0;//如果扫描到第二列，并且按钮松开，则变量置零
            if (col_out[1]==0 && row_in[2]==0) key_down <= 1;//如果扫描到第二列，并且第三行的按钮按下，则下变量置1
            else if(col_out[1]==0) key_down <= 0;//同上
            if (col_out[0]==0 && row_in[1]==0) key_left <= 1;//同上
            else if(col_out[0]==0) key_left <= 0;//同上
            if (col_out[2]==0 && row_in[1]==0) key_right <= 1;//同上
            else if(col_out[2]==0) key_right <= 0;//同上
            if (col_out[1]==0 && row_in[1]==0) key_shoot <= 1; //如果扫描到第二列，并且第二行的按钮按下，则射击变量置1
            else key_shoot <= 0;//如果没扫描到或者没按下，则置零
        end
    end
endmodule