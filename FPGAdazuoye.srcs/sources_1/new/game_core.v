module game_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_sync,
    input  wire [15:0] rand_val,
    
    input  wire k_up, k_down, k_left, k_right, k_shoot,

    output reg [9:0]   player_x,
    output reg [9:0]   player_y,
    output reg [3:0]   player_hp,
    output reg [15:0]  score,
    output reg         game_over,

    // 二维数组转一维
    output reg [9:0]   enemy_valid,       // 10个敌人
    output wire [99:0] enemy_x_flat,      
    output wire [99:0] enemy_y_flat,
    
    output reg [4:0]   bullet_valid,      // 5颗子弹
    output wire [49:0] bullet_x_flat,
    output wire [49:0] bullet_y_flat
);

    //显示参数
    parameter H_DISP = 480; 
    parameter V_DISP = 800;
    parameter P_SIZE = 40; 
    parameter E_SIZE = 40;

    reg [9:0] e_x [0:9];
    reg [9:0] e_y [0:9];
    reg [3:0] e_spd [0:9];
    reg [9:0] b_x [0:4];
    reg [9:0] b_y [0:4];
    reg prev_shoot;

    genvar i;
    generate//传回每个敌人和子弹的坐标
        for(i=0; i<10; i=i+1) begin: flat_e
            assign enemy_x_flat[i*10 +: 10] = e_x[i];
            assign enemy_y_flat[i*10 +: 10] = e_y[i];
        end
        for(i=0; i<5; i=i+1) begin: flat_b
            assign bullet_x_flat[i*10 +: 10] = b_x[i];
            assign bullet_y_flat[i*10 +: 10] = b_y[i];
        end
    endgenerate

    integer j, k;
    reg found_slot;
    reg signed [10:0] dx, dy;
    reg [20:0] dist_sq;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            player_x <= (H_DISP-P_SIZE)/2; player_y <= V_DISP-100;
            player_hp <= 3; score <= 0; game_over <= 0;
            enemy_valid <= 0; bullet_valid <= 0; prev_shoot <= 0;
        end else if(frame_sync && !game_over) begin
        
            // 玩家移动
            if(k_up && player_y > 4) player_y <= player_y - 4;
            if(k_down && player_y < V_DISP-P_SIZE-4) player_y <= player_y + 4;
            if(k_left && player_x > 4) player_x <= player_x - 4;
            if(k_right && player_x < H_DISP-P_SIZE-4) player_x <= player_x + 4;

            // 发射子弹
            prev_shoot <= k_shoot;
            if(k_shoot && !prev_shoot) begin
                found_slot = 0; // 每次发射前重置标志位
                for(j=0; j<5; j=j+1) begin
                    // 如果还没找到空位 且 当前槽位有效
                    if(!found_slot && !bullet_valid[j]) begin
                        bullet_valid[j] <= 1;
                        b_x[j] <= player_x + P_SIZE/2 - 5; 
                        b_y[j] <= player_y;
                        found_slot = 1; // 标记已找到，后续循环就不会再进这个if了
                    end
                end
            end

            // 子弹移动
            for(j=0; j<5; j=j+1) begin
                if(bullet_valid[j]) begin
                    if(b_y[j] > 10) b_y[j] <= b_y[j] - 10;
                    else bullet_valid[j] <= 0;
                end
            end

            // 随机敌人生成
            if((rand_val & 16'h001F) == 0) begin 
                found_slot = 0; // 重置标志位
                for(j=0; j<10; j=j+1) begin
                    if(!found_slot && !enemy_valid[j]) begin
                        enemy_valid[j] <= 1;
                        e_y[j] <= 0;
                        e_x[j] <= rand_val[9:0] % (H_DISP - E_SIZE);
                        e_spd[j] <= (rand_val[11:10]) + 2; 
                        found_slot = 1; // 标记找到
                    end
                end
            end

            // 敌人移动
            for(j=0; j<10; j=j+1) begin
                if(enemy_valid[j]) begin
                    if(e_y[j] < V_DISP) e_y[j] <= e_y[j] + e_spd[j];
                    else enemy_valid[j] <= 0;
                end
            end

            // 碰撞检测 (子弹打敌人)
            //距离小于半径就判定为撞上，这样好写（bushi
            for(j=0; j<5; j=j+1) begin
                if(bullet_valid[j]) begin
                    for(k=0; k<10; k=k+1) begin
                        if(enemy_valid[k]) begin
                            dx = (b_x[j] + 5) - (e_x[k] + 20); // 中心距离
                            dy = (b_y[j] + 5) - (e_y[k] + 20);
                            dist_sq = dx*dx + dy*dy;
                            if(dist_sq < 625) begin // 25^2
                                bullet_valid[j] <= 0;
                                enemy_valid[k] <= 0;
                                score <= score + 1;
                            end
                        end
                    end
                end
            end

            //碰撞检测 (敌人撞玩家)
            //由于图片导入用的40x40的矩形，所以用矩形碰撞检测
            for(k=0; k<10; k=k+1) begin
                if(enemy_valid[k]) begin
                    if(player_x < e_x[k]+E_SIZE && player_x+P_SIZE > e_x[k] &&
                       player_y < e_y[k]+E_SIZE && player_y+P_SIZE > e_y[k]) begin
                        enemy_valid[k] <= 0;
                        if(player_hp > 0) player_hp <= player_hp - 1;
                        else game_over <= 1;
                    end
                end
            end
            if(player_hp == 0) game_over <= 1;//没血就si了
        end
    end
endmodule