module top_lcd_test (
    input           clk,
    input           rst_n,
    
    // 4x4矩阵键盘接口
    input  [3:0]    key_row,
    output [3:0]    key_col,

    // 数码管接口
    output wire [15:0] seg_leds,

    // LCD 接口
    output wire [15:0]  lcd_db,
    output wire         lcd_wr,
    output wire         lcd_rd,
    output wire         lcd_rs,
    output wire         lcd_cs,
    output wire         lcd_rst,
    output wire         lcd_bl
);

    // LCD信号定义
    wire        lcd_ready;
    reg         pixel_en;
    reg [15:0]  pixel_data;
    
    parameter   H_DISP = 480;
    parameter   V_DISP = 800;
    
    reg [9:0]   cnt_x;
    reg [9:0]   cnt_y;
    reg         frame_sync;

    // 游戏信号
    wire [15:0] rand_val;//随机数
    wire k_up, k_down, k_left, k_right, k_shoot;//移动变量
    wire [9:0]  p_x, p_y;//敌人坐标
    wire [3:0]  p_hp;//玩家血量
    wire [15:0] score;//得分
    wire        is_game_over;//似了（

    // 对象数组信号
    wire [9:0]  enemy_valid;
    wire [99:0] enemy_x_flat;//每个敌人的x坐标
    wire [99:0] enemy_y_flat;//每个敌人的y坐标
    wire [4:0]  bullet_valid;
    wire [49:0] bullet_x_flat;//每个子弹x坐标
    wire [49:0] bullet_y_flat;//每个子弹y坐标

    // ROM 信号
    wire [11:0] rom_addr_p;//玩家的
    wire [15:0] rom_data_p;
    reg  [11:0] rom_addr_e;//敌人的
    wire [15:0] rom_data_e;
    
    reg [19:0] rom_addr_bg=0;    // 背景ROM地址
    wire [15:0] rom_data_bg;    // 背景ROM数据（像素点颜色
    reg [19:0] rom_addr_go=0;//游戏结束ROM地址
    wire [15:0] rom_data_go;//游戏结束ROM数据（

    // LCD 驱动调用
    nt35510_lcd_driver u_lcd_driver (
        .clk(clk), .rst_n(rst_n),
        .pixel_data(pixel_data), .pixel_en(pixel_en), .lcd_ready(lcd_ready),
        .lcd_db(lcd_db), .lcd_wr(lcd_wr), .lcd_rd(lcd_rd), .lcd_rs(lcd_rs),
        .lcd_cs(lcd_cs), .lcd_rst(lcd_rst), .lcd_bl(lcd_bl)
    );

    // 随机数
    lfsr_random u_rnd ( .clk(clk), .rst_n(rst_n), .rand_out(rand_val) );

    // 键盘
    matrix_key u_key (
        .clk(clk), .rst_n(rst_n), 
        .row_in(key_row), .col_out(key_col),
        .key_up(k_up), .key_down(k_down), 
        .key_left(k_left), .key_right(k_right), .key_shoot(k_shoot)
    );

    // 游戏核心
    game_core u_game (
        .clk(clk), .rst_n(rst_n), .frame_sync(frame_sync), .rand_val(rand_val),
        .k_up(k_up), .k_down(k_down), .k_left(k_left), .k_right(k_right), .k_shoot(k_shoot),
        .player_x(p_x), .player_y(p_y), .player_hp(p_hp), .score(score), .game_over(is_game_over),
        .enemy_valid(enemy_valid), .enemy_x_flat(enemy_x_flat), .enemy_y_flat(enemy_y_flat),
        .bullet_valid(bullet_valid), .bullet_x_flat(bullet_x_flat), .bullet_y_flat(bullet_y_flat)
    );

    // 贴图 ROM
    player_rom     u_rom_p  (.addr(rom_addr_p), .data(rom_data_p));//自机
    enemy_rom      u_rom_e  (.addr(rom_addr_e), .data(rom_data_e));//敌机
    background_rom u_rom_bg (.clk(clk),.addr(rom_addr_bg), .data(rom_data_bg));//背景
    gameover_rom u_rom_go ( .clk(clk),.addr(rom_addr_go),.data(rom_data_go));//gameover
    
    //数码管参数
    reg [16:0] seg_scan_cnt;
    reg [2:0]  current_idx;
    reg [5:0]  current_op;

    always @(posedge clk or negedge rst_n) begin//数码管扫描显示
        if (!rst_n) begin
            seg_scan_cnt <= 0;
            current_idx  <= 0;
        end else begin
            if (seg_scan_cnt >= 100000) begin
                seg_scan_cnt <= 0;
                current_idx  <= current_idx + 1;
            end else begin
                seg_scan_cnt <= seg_scan_cnt + 1;
            end
        end
    end

    always @(*) begin
        case (current_idx)
            3'd0: current_op = 6'd17;               // 'H'
            3'd1: current_op = 6'd25;               // 'P.'
            3'd2: current_op = {2'b00, p_hp};       // 血量
            3'd3: current_op = 6'd36;               // 空白
            3'd4: current_op = 6'd28;               // 'S'
            3'd5: current_op = 6'd12;               // 'C.'
            3'd6: current_op = (score / 10) % 10;   // 分数十位
            3'd7: current_op = score % 10;          // 分数个位
            default: current_op = 6'd0;
        endcase
    end

    //调用数码管库
    LEDshow u_seg_show (
        .op   (current_op),
        .idx  ({1'b0, current_idx}),
        .clk  (clk),
        .rst(rst_n),
        .out (seg_leds)
    );

    // 渲染计算逻辑 (Renderer)

    // 玩家渲染判定
    wire in_player;
    wire [5:0] p_dx, p_dy;
    assign in_player = (cnt_x >= p_x && cnt_x < p_x + 40 && cnt_y >= p_y && cnt_y < p_y + 40);//为1就渲染
    assign p_dx = cnt_x - p_x;//相对坐标
    assign p_dy = cnt_y - p_y;
    assign rom_addr_p = p_dy * 40 + p_dx;//转化成地址

    // 敌人渲染判定 (多目标)
    reg is_enemy;
    reg [5:0] e_dx, e_dy;
    integer i;
    reg [9:0] curr_ex, curr_ey;

    always @(*) begin
        is_enemy = 0;
        rom_addr_e = 0; 
        for (i = 0; i < 10; i = i + 1) begin//便利每个敌人，逻辑和上面的玩家渲染差不多
            if (enemy_valid[i]) begin
                curr_ex = enemy_x_flat[i*10 +: 10];
                curr_ey = enemy_y_flat[i*10 +: 10];
                if (cnt_x >= curr_ex && cnt_x < curr_ex + 40 &&
                    cnt_y >= curr_ey && cnt_y < curr_ey + 40) begin
                    is_enemy = 1;
                    e_dx = cnt_x - curr_ex;
                    e_dy = cnt_y - curr_ey;
                    rom_addr_e = e_dy * 40 + e_dx; 
                end
            end
        end
    end

    // 子弹渲染判定
    reg is_bullet;
    reg [9:0] bx, by;
    reg signed [10:0] bdx, bdy;
    integer j;
    
    always @(*) begin
        is_bullet = 0;
        for (j = 0; j < 5; j = j + 1) begin
            if (bullet_valid[j]) begin
                bx = bullet_x_flat[j*10 +: 10];
                by = bullet_y_flat[j*10 +: 10];
                if (cnt_x >= bx && cnt_x < bx + 10 && cnt_y >= by && cnt_y < by + 10) begin
                    bdx = cnt_x - (bx + 5);
                    bdy = cnt_y - (by + 5);
                    if (bdx*bdx + bdy*bdy < 25) is_bullet = 1; //圆形子弹
                end
            end
        end
    end

    // 最终像素输出逻辑 (优先级：游戏结束 > 子弹 > 敌人 > 玩家 > 背景)
    localparam C_TRANSPARENT = 16'h0000; // 黑色作为透明色

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_x <= 0; cnt_y <= 0; pixel_en <= 0; pixel_data <= 0; frame_sync <= 0;
            rom_addr_bg<=0;
            rom_addr_go<=0;
        end else begin
            frame_sync <= 0;
            if (lcd_ready) begin
                pixel_en <= 1;
                if (is_game_over) begin
                    pixel_data <= rom_data_go;
                end else if (is_bullet) begin
                    pixel_data <= 16'hFFE0; // 黄色子弹
                end else if (is_enemy) begin
                    // 如果敌人贴图是透明色，则显示其下方的玩家或背景
                    pixel_data <= (rom_data_e == C_TRANSPARENT) ? (in_player ? rom_data_p : rom_data_bg) : rom_data_e;
                end else if (in_player) begin
                    // 如果玩家贴图是透明色，则显示背景
                    pixel_data <= (rom_data_p == C_TRANSPARENT) ? rom_data_bg : rom_data_p;
                end else begin
                    // 显示背景
                    pixel_data <= rom_data_bg;
                end
                rom_addr_bg<=rom_addr_bg+1;
                rom_addr_go<=rom_addr_go+1;
                // 扫描计数器，当前应该渲染的像素点位置
                if (cnt_x < H_DISP - 1) cnt_x <= cnt_x + 1;
                else begin
                    cnt_x <= 0;
                    if (cnt_y < V_DISP - 1) cnt_y <= cnt_y + 1;
                    else begin//整个屏幕渲染完一轮樂
                        cnt_y <= 0;
                        frame_sync <= 1;
                        rom_addr_bg<=0;
                        rom_addr_go<=0;
                    end
                end
            end else begin
                pixel_en <= 0;
            end
        end
    end

endmodule