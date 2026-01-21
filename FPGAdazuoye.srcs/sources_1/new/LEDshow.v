`timescale 1ns / 1ps
module LEDshow (//数码管显示库
    input[5:0]  op,//选择显示哪个数字
    input[4:0]  idx,//选择哪个数码管显示
    input clk,
    input rst,
    output reg[15:0]  out//显示输出
);

//有的字母没用到就没写（不要喷我呜呜呜）
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        out<=16'b0000000011111111;
    end else begin
        out<=16'b0000000011111111;
        if(op<36) begin//大于等于36为无效码，不显示
            out[idx]<=0;
        end
        if(op==0) begin//显示0
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
        end
        if(op==1) begin//显示1
            out[9]<=1;
            out[10]<=1;
        end
        if(op==2) begin//显示2
            out[8]<=1;
            out[9]<=1;
            out[11]<=1;
            out[12]<=1;
            out[14]<=1;
        end
        if(op==3) begin//显示3
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==4) begin//显示4
            out[9]<=1;
            out[10]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==5) begin//显示5
            out[8]<=1;
            out[13]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==6) begin//显示6
            out[8]<=1;
            out[12]<=1;
            out[13]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==7) begin//显示7
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
        end
        if(op==8) begin//显示8
            out[8]<=1;
            out[9]<=1;
            out[12]<=1;
            out[13]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==9) begin//显示9
            out[8]<=1;
            out[9]<=1;
            out[13]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==10) begin//显示A
            out[8]<=1;
            out[9]<=1;
            out[12]<=1;
            out[13]<=1;
            out[10]<=1;
            out[14]<=1;
        end
        if(op==11) begin//显示B
            out[12]<=1;
            out[13]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==12) begin//显示C
            out[8]<=1;
            out[12]<=1;
            out[13]<=1;
            out[11]<=1;
            out[15]<=1;
        end
        if(op==13) begin//显示D
            out[9]<=1;
            out[12]<=1;
            out[10]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==14) begin//显示E
            out[8]<=1;
            out[12]<=1;
            out[13]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==15) begin//显示F
            out[8]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==16) begin//显示G
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==17) begin//显示H
            out[9]<=1;
            out[10]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==18) begin//显示I
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==19) begin//显示J
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==20) begin//显示K
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==21) begin//显示L
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==22) begin//显示M
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==23) begin//显示N
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==24) begin//显示O
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==25) begin//显示P
            out[8]<=1;
            out[9]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
            out[15]<=1;
        end
        if(op==26) begin//显示Q
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==27) begin//显示R
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==28) begin//显示S
            out[8]<=1;
            out[10]<=1;
            out[13]<=1;
            out[11]<=1;
            out[14]<=1;
        end
        if(op==29) begin//显示T
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==30) begin//显示U
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==31) begin//显示V
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==32) begin//显示W
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==33) begin//显示X
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==34) begin//显示Y
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
        if(op==35) begin//显示Z
            out[8]<=1;
            out[9]<=1;
            out[10]<=1;
            out[11]<=1;
            out[12]<=1;
            out[13]<=1;
            out[14]<=1;
        end
    end
end
endmodule