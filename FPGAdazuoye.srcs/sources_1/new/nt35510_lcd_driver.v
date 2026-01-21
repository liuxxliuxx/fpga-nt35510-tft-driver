module nt35510_lcd_driver (
    input  wire         clk,
    input  wire         rst_n,
    
    // lcd_ready=1 -> 发送命令 -> 拉高 pixel_en 写入数据
    input  wire [15:0]  pixel_data, // RGB565 像素数据
    input  wire         pixel_en,   // 数据有效使能 (高有效)
    output reg          lcd_ready,  // 1=空闲(初始化完成), 0=忙碌

    //LCD引脚
    output reg  [15:0]  lcd_db,
    output reg          lcd_wr,
    output           lcd_rd,
    output reg          lcd_rs,
    output reg          lcd_cs,
    output reg          lcd_rst,
    output wire         lcd_bl
);

    parameter CLK_FREQ = 100_000_000; // 100MHz
    
    // 状态机定义
    localparam S_HARD_RESET   = 0;
    localparam S_DELAY        = 1;
    localparam S_INIT_ADDR    = 2; // 发送寄存器地址(Cmd)
    localparam S_INIT_DATA    = 3; // 发送寄存器数据(Data)
    localparam S_WR_PULSE     = 4; // 生成写时序脉冲
    localparam S_IDLE         = 5; // 空闲
    localparam S_PIXEL_SETUP  = 6; // 像素写入
    localparam S_NEXT_INDEX   = 7; // 索引递增
    localparam S_PIXEL_HIGH   = 6; // 写像素高 8 位
    localparam S_PIXEL_LOW    = 8; // 写像素低 8 位 (新增状态)

    reg [3:0]  state = S_HARD_RESET;
    reg [3:0]  return_state;        // 延时/脉冲后的返回状态
    reg [3:0]  next_state_after_wr; // 写操作完成后的下一步
    
    reg [31:0] delay_cnt;
    reg [31:0] delay_target;
    reg [2:0]  wr_pulse_cnt;        // 写脉宽计数器

    // 初始化指令存储
    reg [9:0]  rom_index;           // 增加位宽以容纳更多 Gamma 指令
    reg [31:0] rom_data;            // {地址 16bit, 数据 16bit}
    
    assign lcd_bl = 1'b1;           // 背光常亮
    assign lcd_rd = 1'b1;           // 不进行读操作

    // 初始化序列 ROM
    // 格式: {CMD_ADDR(16bit), DATA(16bit)}
    // 特殊指令:
    // 32'hEEEE_EEEE -> 延时 50ms
    // 32'hDDDD_DDDD -> 延时 120us
    // 32'hCCCC_CCCC -> 仅写命令(CMD), 不写数据
    // 32'hFFFF_FFFF -> 结束
    always @(*) begin
        case(rom_index)
            //硬件复位后的延时
            0:   rom_data = 32'hEEEE_EEEE; 
            
            1	:	rom_data={16'hF000,16'h55};
            2	:	rom_data={16'hF001,16'hAA};
            3	:	rom_data={16'hF002,16'h52};
            4	:	rom_data={16'hF003,16'h08};
            5	:	rom_data={16'hF004,16'h01};
            6	:	rom_data={16'hB000,16'h0D};
            7	:	rom_data={16'hB001,16'h0D};
            8	:	rom_data={16'hB002,16'h0D};
            9	:	rom_data={16'hB600,16'h34};
            10	:	rom_data={16'hB601,16'h34};
            11	:	rom_data={16'hB602,16'h34};
            12	:	rom_data={16'hB100,16'h0D};
            13	:	rom_data={16'hB101,16'h0D};
            14	:	rom_data={16'hB102,16'h0D};
            15	:	rom_data={16'hB700,16'h34};
            16	:	rom_data={16'hB701,16'h34};
            17	:	rom_data={16'hB702,16'h34};
            18	:	rom_data={16'hB200,16'h00};
            19	:	rom_data={16'hB201,16'h00};
            20	:	rom_data={16'hB202,16'h00};
            21	:	rom_data={16'hB800,16'h24};
            22	:	rom_data={16'hB801,16'h24};
            23	:	rom_data={16'hB802,16'h24};
            24	:	rom_data={16'hBF00,16'h01};
            25	:	rom_data={16'hB300,16'h0F};
            26	:	rom_data={16'hB301,16'h0F};
            27	:	rom_data={16'hB302,16'h0F};
            28	:	rom_data={16'hB900,16'h34};
            29	:	rom_data={16'hB901,16'h34};
            30	:	rom_data={16'hB902,16'h34};
            31	:	rom_data={16'hB500,16'h08};
            32	:	rom_data={16'hB501,16'h08};
            33	:	rom_data={16'hB502,16'h08};
            34	:	rom_data={16'hC200,16'h03};
            35	:	rom_data={16'hBA00,16'h24};
            36	:	rom_data={16'hBA01,16'h24};
            37	:	rom_data={16'hBA02,16'h24};
            38	:	rom_data={16'hBC00,16'h00};
            39	:	rom_data={16'hBC01,16'h78};
            40	:	rom_data={16'hBC02,16'h00};
            41	:	rom_data={16'hBD00,16'h00};
            42	:	rom_data={16'hBD01,16'h78};
            43	:	rom_data={16'hBD02,16'h00};
            44	:	rom_data={16'hBE00,16'h00};
            45	:	rom_data={16'hBE01,16'h64};
            46	:	rom_data={16'hD100,16'h00};
            47	:	rom_data={16'hD101,16'h33};
            48	:	rom_data={16'hD102,16'h00};
            49	:	rom_data={16'hD103,16'h34};
            50	:	rom_data={16'hD104,16'h00};
            51	:	rom_data={16'hD105,16'h3A};
            52	:	rom_data={16'hD106,16'h00};
            53	:	rom_data={16'hD107,16'h4A};
            54	:	rom_data={16'hD108,16'h00};
            55	:	rom_data={16'hD109,16'h5C};
            56	:	rom_data={16'hD10A,16'h00};
            57	:	rom_data={16'hD10B,16'h81};
            58	:	rom_data={16'hD10C,16'h00};
            59	:	rom_data={16'hD10D,16'hA6};
            60	:	rom_data={16'hD10E,16'h00};
            61	:	rom_data={16'hD10F,16'hE5};
            62	:	rom_data={16'hD110,16'h01};
            63	:	rom_data={16'hD111,16'h13};
            64	:	rom_data={16'hD112,16'h01};
            65	:	rom_data={16'hD113,16'h54};
            66	:	rom_data={16'hD114,16'h01};
            67	:	rom_data={16'hD115,16'h82};
            68	:	rom_data={16'hD116,16'h01};
            69	:	rom_data={16'hD117,16'hCA};
            70	:	rom_data={16'hD118,16'h02};
            71	:	rom_data={16'hD119,16'h00};
            72	:	rom_data={16'hD11A,16'h02};
            73	:	rom_data={16'hD11B,16'h01};
            74	:	rom_data={16'hD11C,16'h02};
            75	:	rom_data={16'hD11D,16'h34};
            76	:	rom_data={16'hD11E,16'h02};
            77	:	rom_data={16'hD11F,16'h67};
            78	:	rom_data={16'hD120,16'h02};
            79	:	rom_data={16'hD121,16'h84};
            80	:	rom_data={16'hD122,16'h02};
            81	:	rom_data={16'hD123,16'hA4};
            82	:	rom_data={16'hD124,16'h02};
            83	:	rom_data={16'hD125,16'hB7};
            84	:	rom_data={16'hD126,16'h02};
            85	:	rom_data={16'hD127,16'hCF};
            86	:	rom_data={16'hD128,16'h02};
            87	:	rom_data={16'hD129,16'hDE};
            88	:	rom_data={16'hD12A,16'h02};
            89	:	rom_data={16'hD12B,16'hF2};
            90	:	rom_data={16'hD12C,16'h02};
            91	:	rom_data={16'hD12D,16'hFE};
            92	:	rom_data={16'hD12E,16'h03};
            93	:	rom_data={16'hD12F,16'h10};
            94	:	rom_data={16'hD130,16'h03};
            95	:	rom_data={16'hD131,16'h33};
            96	:	rom_data={16'hD132,16'h03};
            97	:	rom_data={16'hD133,16'h6D};
            98	:	rom_data={16'hD200,16'h00};
            99	:	rom_data={16'hD201,16'h33};
            100	:	rom_data={16'hD202,16'h00};
            101	:	rom_data={16'hD203,16'h34};
            102	:	rom_data={16'hD204,16'h00};
            103	:	rom_data={16'hD205,16'h3A};
            104	:	rom_data={16'hD206,16'h00};
            105	:	rom_data={16'hD207,16'h4A};
            106	:	rom_data={16'hD208,16'h00};
            107	:	rom_data={16'hD209,16'h5C};
            108	:	rom_data={16'hD20A,16'h00};
            109	:	rom_data={16'hD20B,16'h81};
            110	:	rom_data={16'hD20C,16'h00};
            111	:	rom_data={16'hD20D,16'hA6};
            112	:	rom_data={16'hD20E,16'h00};
            113	:	rom_data={16'hD20F,16'hE5};
            114	:	rom_data={16'hD210,16'h01};
            115	:	rom_data={16'hD211,16'h13};
            116	:	rom_data={16'hD212,16'h01};
            117	:	rom_data={16'hD213,16'h54};
            118	:	rom_data={16'hD214,16'h01};
            119	:	rom_data={16'hD215,16'h82};
            120	:	rom_data={16'hD216,16'h01};
            121	:	rom_data={16'hD217,16'hCA};
            122	:	rom_data={16'hD218,16'h02};
            123	:	rom_data={16'hD219,16'h00};
            124	:	rom_data={16'hD21A,16'h02};
            125	:	rom_data={16'hD21B,16'h01};
            126	:	rom_data={16'hD21C,16'h02};
            127	:	rom_data={16'hD21D,16'h34};
            128	:	rom_data={16'hD21E,16'h02};
            129	:	rom_data={16'hD21F,16'h67};
            130	:	rom_data={16'hD220,16'h02};
            131	:	rom_data={16'hD221,16'h84};
            132	:	rom_data={16'hD222,16'h02};
            133	:	rom_data={16'hD223,16'hA4};
            134	:	rom_data={16'hD224,16'h02};
            135	:	rom_data={16'hD225,16'hB7};
            136	:	rom_data={16'hD226,16'h02};
            137	:	rom_data={16'hD227,16'hCF};
            138	:	rom_data={16'hD228,16'h02};
            139	:	rom_data={16'hD229,16'hDE};
            140	:	rom_data={16'hD22A,16'h02};
            141	:	rom_data={16'hD22B,16'hF2};
            142	:	rom_data={16'hD22C,16'h02};
            143	:	rom_data={16'hD22D,16'hFE};
            144	:	rom_data={16'hD22E,16'h03};
            145	:	rom_data={16'hD22F,16'h10};
            146	:	rom_data={16'hD230,16'h03};
            147	:	rom_data={16'hD231,16'h33};
            148	:	rom_data={16'hD232,16'h03};
            149	:	rom_data={16'hD233,16'h6D};
            150	:	rom_data={16'hD300,16'h00};
            151	:	rom_data={16'hD301,16'h33};
            152	:	rom_data={16'hD302,16'h00};
            153	:	rom_data={16'hD303,16'h34};
            154	:	rom_data={16'hD304,16'h00};
            155	:	rom_data={16'hD305,16'h3A};
            156	:	rom_data={16'hD306,16'h00};
            157	:	rom_data={16'hD307,16'h4A};
            158	:	rom_data={16'hD308,16'h00};
            159	:	rom_data={16'hD309,16'h5C};
            160	:	rom_data={16'hD30A,16'h00};
            161	:	rom_data={16'hD30B,16'h81};
            162	:	rom_data={16'hD30C,16'h00};
            163	:	rom_data={16'hD30D,16'hA6};
            164	:	rom_data={16'hD30E,16'h00};
            165	:	rom_data={16'hD30F,16'hE5};
            166	:	rom_data={16'hD310,16'h01};
            167	:	rom_data={16'hD311,16'h13};
            168	:	rom_data={16'hD312,16'h01};
            169	:	rom_data={16'hD313,16'h54};
            170	:	rom_data={16'hD314,16'h01};
            171	:	rom_data={16'hD315,16'h82};
            172	:	rom_data={16'hD316,16'h01};
            173	:	rom_data={16'hD317,16'hCA};
            174	:	rom_data={16'hD318,16'h02};
            175	:	rom_data={16'hD319,16'h00};
            176	:	rom_data={16'hD31A,16'h02};
            177	:	rom_data={16'hD31B,16'h01};
            178	:	rom_data={16'hD31C,16'h02};
            179	:	rom_data={16'hD31D,16'h34};
            180	:	rom_data={16'hD31E,16'h02};
            181	:	rom_data={16'hD31F,16'h67};
            182	:	rom_data={16'hD320,16'h02};
            183	:	rom_data={16'hD321,16'h84};
            184	:	rom_data={16'hD322,16'h02};
            185	:	rom_data={16'hD323,16'hA4};
            186	:	rom_data={16'hD324,16'h02};
            187	:	rom_data={16'hD325,16'hB7};
            188	:	rom_data={16'hD326,16'h02};
            189	:	rom_data={16'hD327,16'hCF};
            190	:	rom_data={16'hD328,16'h02};
            191	:	rom_data={16'hD329,16'hDE};
            192	:	rom_data={16'hD32A,16'h02};
            193	:	rom_data={16'hD32B,16'hF2};
            194	:	rom_data={16'hD32C,16'h02};
            195	:	rom_data={16'hD32D,16'hFE};
            196	:	rom_data={16'hD32E,16'h03};
            197	:	rom_data={16'hD32F,16'h10};
            198	:	rom_data={16'hD330,16'h03};
            199	:	rom_data={16'hD331,16'h33};
            200	:	rom_data={16'hD332,16'h03};
            201	:	rom_data={16'hD333,16'h6D};
            202	:	rom_data={16'hD400,16'h00};
            203	:	rom_data={16'hD401,16'h33};
            204	:	rom_data={16'hD402,16'h00};
            205	:	rom_data={16'hD403,16'h34};
            206	:	rom_data={16'hD404,16'h00};
            207	:	rom_data={16'hD405,16'h3A};
            208	:	rom_data={16'hD406,16'h00};
            209	:	rom_data={16'hD407,16'h4A};
            210	:	rom_data={16'hD408,16'h00};
            211	:	rom_data={16'hD409,16'h5C};
            212	:	rom_data={16'hD40A,16'h00};
            213	:	rom_data={16'hD40B,16'h81};
            214	:	rom_data={16'hD40C,16'h00};
            215	:	rom_data={16'hD40D,16'hA6};
            216	:	rom_data={16'hD40E,16'h00};
            217	:	rom_data={16'hD40F,16'hE5};
            218	:	rom_data={16'hD410,16'h01};
            219	:	rom_data={16'hD411,16'h13};
            220	:	rom_data={16'hD412,16'h01};
            221	:	rom_data={16'hD413,16'h54};
            222	:	rom_data={16'hD414,16'h01};
            223	:	rom_data={16'hD415,16'h82};
            224	:	rom_data={16'hD416,16'h01};
            225	:	rom_data={16'hD417,16'hCA};
            226	:	rom_data={16'hD418,16'h02};
            227	:	rom_data={16'hD419,16'h00};
            228	:	rom_data={16'hD41A,16'h02};
            229	:	rom_data={16'hD41B,16'h01};
            230	:	rom_data={16'hD41C,16'h02};
            231	:	rom_data={16'hD41D,16'h34};
            232	:	rom_data={16'hD41E,16'h02};
            233	:	rom_data={16'hD41F,16'h67};
            234	:	rom_data={16'hD420,16'h02};
            235	:	rom_data={16'hD421,16'h84};
            236	:	rom_data={16'hD422,16'h02};
            237	:	rom_data={16'hD423,16'hA4};
            238	:	rom_data={16'hD424,16'h02};
            239	:	rom_data={16'hD425,16'hB7};
            240	:	rom_data={16'hD426,16'h02};
            241	:	rom_data={16'hD427,16'hCF};
            242	:	rom_data={16'hD428,16'h02};
            243	:	rom_data={16'hD429,16'hDE};
            244	:	rom_data={16'hD42A,16'h02};
            245	:	rom_data={16'hD42B,16'hF2};
            246	:	rom_data={16'hD42C,16'h02};
            247	:	rom_data={16'hD42D,16'hFE};
            248	:	rom_data={16'hD42E,16'h03};
            249	:	rom_data={16'hD42F,16'h10};
            250	:	rom_data={16'hD430,16'h03};
            251	:	rom_data={16'hD431,16'h33};
            252	:	rom_data={16'hD432,16'h03};
            253	:	rom_data={16'hD433,16'h6D};
            254	:	rom_data={16'hD500,16'h00};
            255	:	rom_data={16'hD501,16'h33};
            256	:	rom_data={16'hD502,16'h00};
            257	:	rom_data={16'hD503,16'h34};
            258	:	rom_data={16'hD504,16'h00};
            259	:	rom_data={16'hD505,16'h3A};
            260	:	rom_data={16'hD506,16'h00};
            261	:	rom_data={16'hD507,16'h4A};
            262	:	rom_data={16'hD508,16'h00};
            263	:	rom_data={16'hD509,16'h5C};
            264	:	rom_data={16'hD50A,16'h00};
            265	:	rom_data={16'hD50B,16'h81};
            266	:	rom_data={16'hD50C,16'h00};
            267	:	rom_data={16'hD50D,16'hA6};
            268	:	rom_data={16'hD50E,16'h00};
            269	:	rom_data={16'hD50F,16'hE5};
            270	:	rom_data={16'hD510,16'h01};
            271	:	rom_data={16'hD511,16'h13};
            272	:	rom_data={16'hD512,16'h01};
            273	:	rom_data={16'hD513,16'h54};
            274	:	rom_data={16'hD514,16'h01};
            275	:	rom_data={16'hD515,16'h82};
            276	:	rom_data={16'hD516,16'h01};
            277	:	rom_data={16'hD517,16'hCA};
            278	:	rom_data={16'hD518,16'h02};
            279	:	rom_data={16'hD519,16'h00};
            280	:	rom_data={16'hD51A,16'h02};
            281	:	rom_data={16'hD51B,16'h01};
            282	:	rom_data={16'hD51C,16'h02};
            283	:	rom_data={16'hD51D,16'h34};
            284	:	rom_data={16'hD51E,16'h02};
            285	:	rom_data={16'hD51F,16'h67};
            286	:	rom_data={16'hD520,16'h02};
            287	:	rom_data={16'hD521,16'h84};
            288	:	rom_data={16'hD522,16'h02};
            289	:	rom_data={16'hD523,16'hA4};
            290	:	rom_data={16'hD524,16'h02};
            291	:	rom_data={16'hD525,16'hB7};
            292	:	rom_data={16'hD526,16'h02};
            293	:	rom_data={16'hD527,16'hCF};
            294	:	rom_data={16'hD528,16'h02};
            295	:	rom_data={16'hD529,16'hDE};
            296	:	rom_data={16'hD52A,16'h02};
            297	:	rom_data={16'hD52B,16'hF2};
            298	:	rom_data={16'hD52C,16'h02};
            299	:	rom_data={16'hD52D,16'hFE};
            300	:	rom_data={16'hD52E,16'h03};
            301	:	rom_data={16'hD52F,16'h10};
            302	:	rom_data={16'hD530,16'h03};
            303	:	rom_data={16'hD531,16'h33};
            304	:	rom_data={16'hD532,16'h03};
            305	:	rom_data={16'hD533,16'h6D};
            306	:	rom_data={16'hD600,16'h00};
            307	:	rom_data={16'hD601,16'h33};
            308	:	rom_data={16'hD602,16'h00};
            309	:	rom_data={16'hD603,16'h34};
            310	:	rom_data={16'hD604,16'h00};
            311	:	rom_data={16'hD605,16'h3A};
            312	:	rom_data={16'hD606,16'h00};
            313	:	rom_data={16'hD607,16'h4A};
            314	:	rom_data={16'hD608,16'h00};
            315	:	rom_data={16'hD609,16'h5C};
            316	:	rom_data={16'hD60A,16'h00};
            317	:	rom_data={16'hD60B,16'h81};
            318	:	rom_data={16'hD60C,16'h00};
            319	:	rom_data={16'hD60D,16'hA6};
            320	:	rom_data={16'hD60E,16'h00};
            321	:	rom_data={16'hD60F,16'hE5};
            322	:	rom_data={16'hD610,16'h01};
            323	:	rom_data={16'hD611,16'h13};
            324	:	rom_data={16'hD612,16'h01};
            325	:	rom_data={16'hD613,16'h54};
            326	:	rom_data={16'hD614,16'h01};
            327	:	rom_data={16'hD615,16'h82};
            328	:	rom_data={16'hD616,16'h01};
            329	:	rom_data={16'hD617,16'hCA};
            330	:	rom_data={16'hD618,16'h02};
            331	:	rom_data={16'hD619,16'h00};
            332	:	rom_data={16'hD61A,16'h02};
            333	:	rom_data={16'hD61B,16'h01};
            334	:	rom_data={16'hD61C,16'h02};
            335	:	rom_data={16'hD61D,16'h34};
            336	:	rom_data={16'hD61E,16'h02};
            337	:	rom_data={16'hD61F,16'h67};
            338	:	rom_data={16'hD620,16'h02};
            339	:	rom_data={16'hD621,16'h84};
            340	:	rom_data={16'hD622,16'h02};
            341	:	rom_data={16'hD623,16'hA4};
            342	:	rom_data={16'hD624,16'h02};
            343	:	rom_data={16'hD625,16'hB7};
            344	:	rom_data={16'hD626,16'h02};
            345	:	rom_data={16'hD627,16'hCF};
            346	:	rom_data={16'hD628,16'h02};
            347	:	rom_data={16'hD629,16'hDE};
            348	:	rom_data={16'hD62A,16'h02};
            349	:	rom_data={16'hD62B,16'hF2};
            350	:	rom_data={16'hD62C,16'h02};
            351	:	rom_data={16'hD62D,16'hFE};
            352	:	rom_data={16'hD62E,16'h03};
            353	:	rom_data={16'hD62F,16'h10};
            354	:	rom_data={16'hD630,16'h03};
            355	:	rom_data={16'hD631,16'h33};
            356	:	rom_data={16'hD632,16'h03};
            357	:	rom_data={16'hD633,16'h6D};
            358	:	rom_data={16'hF000,16'h55};
            359	:	rom_data={16'hF001,16'hAA};
            360	:	rom_data={16'hF002,16'h52};
            361	:	rom_data={16'hF003,16'h08};
            362	:	rom_data={16'hF004,16'h00};
            363	:	rom_data={16'hB100, 16'hCC};
            364	:	rom_data={16'hB101, 16'h00};
            365	:	rom_data={16'hB600,16'h05};
            366	:	rom_data={16'hB700,16'h70};
            367	:	rom_data={16'hB701,16'h70};
            368	:	rom_data={16'hB800,16'h01};
            369	:	rom_data={16'hB801,16'h03};
            370	:	rom_data={16'hB802,16'h03};
            371	:	rom_data={16'hB803,16'h03};
            372	:	rom_data={16'hBC00,16'h02};
            373	:	rom_data={16'hBC01,16'h00};
            374	:	rom_data={16'hBC02,16'h00};
            375	:	rom_data={16'hC900,16'hD0};
            376	:	rom_data={16'hC901,16'h02};
            377	:	rom_data={16'hC902,16'h50};
            378	:	rom_data={16'hC903,16'h50};
            379	:	rom_data={16'hC904,16'h50};
            380	:	rom_data={16'h3500,16'h00};
            381	:	rom_data={16'h3A00,16'h55};

            // Sleep Out
            382:  rom_data = {16'h1100, 16'hCCCC}; 
            
            //Delay 120us
            383:  rom_data = 32'hDDDD_DDDD;
            
            384:  rom_data = {16'h2900, 16'hCCCC};
            
            385:  rom_data = {16'h2C00, 16'hCCCC};

            //结束标志
            386:  rom_data = 32'hFFFF_FFFF; 
            
            default: rom_data = 32'hFFFF_FFFF;
        endcase
    end

    // 主控制状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_HARD_RESET;
            lcd_rst     <= 1'b0;
            lcd_cs      <= 1'b1;
            lcd_wr      <= 1'b1;
            lcd_rs      <= 1'b1;
            lcd_db      <= 16'h0000;
            delay_cnt   <= 0;
            rom_index   <= 0;
            lcd_ready   <= 0;
            wr_pulse_cnt<= 0;
            return_state<= S_HARD_RESET;
            next_state_after_wr <= S_HARD_RESET;
        end else begin
            case (state)
                // 硬件复位，拉低 RST 10ms
                S_HARD_RESET: begin
                    lcd_rst <= 1'b0;
                    if (delay_cnt < (CLK_FREQ / 100)) begin 
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        lcd_rst <= 1'b1;
                        delay_cnt <= 0;
                        state <= S_DELAY;
                        delay_target <= (CLK_FREQ / 20); // 复位后等待 50ms
                        return_state <= S_INIT_ADDR;
                    end
                end
    
                //延时状态
                S_DELAY: begin
                    if (delay_cnt < delay_target) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        state <= return_state;
                    end
                end

                //初始化，准备发送地址
                S_INIT_ADDR: begin
                    if (rom_data == 32'hFFFF_FFFF) begin
                        state <= S_IDLE; // 完成
                    end else if (rom_data == 32'hEEEE_EEEE) begin//延时 and 索引加一
                        delay_target <= (CLK_FREQ / 20);
                        state <= S_DELAY;
                        return_state <= S_NEXT_INDEX;
                    end else if (rom_data == 32'hDDDD_DDDD) begin//延时 and 索引加一
                        delay_target <= (CLK_FREQ / 10000) * 2;
                        state <= S_DELAY;
                        return_state <= S_NEXT_INDEX;
                    end else begin
                        // 发送命令
                        lcd_cs <= 0;
                        lcd_rs <= 0;
                        lcd_db <= rom_data[31:16]; 
                        state <= S_WR_PULSE;
                        next_state_after_wr <= S_INIT_DATA;
                    end
                end

                // 初始化，准备发送数据
                S_INIT_DATA: begin
                    if (rom_data[15:0] == 16'hCCCC) begin//无参命令，跳过
                        lcd_cs <= 1;
                        state <= S_NEXT_INDEX;
                    end else begin // 发送参数部分
                        lcd_rs <= 1; // RS=1 表示数据
                        lcd_db <= rom_data[15:0]; 
                        state <= S_WR_PULSE;
                        next_state_after_wr <= S_NEXT_INDEX; // 写完Data去下一条索引
                    end
                end
                
                // 辅助状态，索引递增
                S_NEXT_INDEX: begin
                    lcd_cs <= 1; // 结束一次传输
                    rom_index <= rom_index + 1;
                    state <= S_INIT_ADDR;
                end
        
                // 写脉冲生成器
                S_WR_PULSE: begin
                    if (wr_pulse_cnt == 0) begin
                        lcd_wr <= 0;
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else if (wr_pulse_cnt < 3) begin
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else begin
                        lcd_wr <= 1;
                        wr_pulse_cnt <= 0;
                        state <= next_state_after_wr;
                    end
                end

                // 空闲状态 (等待外部像素)
                S_IDLE: begin
                    lcd_ready <= 1;
                    lcd_cs <= 1;
                    lcd_wr <= 1;
                    
                    if (pixel_en) begin
                        lcd_ready <= 0;
                        lcd_cs <= 0;
                        lcd_rs <= 1;
                        
                        lcd_db <= pixel_data[15:0]; 
                        
                        state  <= S_PIXEL_LOW; // 跳转到写入状态
                    end
                end
                
                // 每个像素点写两次，这是写第一次
                S_PIXEL_LOW: begin
                    if (wr_pulse_cnt == 0) begin
                        lcd_wr <= 0;
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else if (wr_pulse_cnt < 2) begin 
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else begin
                        lcd_wr <= 1;
                        wr_pulse_cnt <= 0;
                        lcd_db <= pixel_data[15:0]; 
                        
                        state <= S_PIXEL_HIGH; // 跳转到第二次
                    end
                end

                // 每个像素点写两次，这是写第二次
                S_PIXEL_HIGH: begin
                    if (wr_pulse_cnt == 0) begin
                        lcd_wr <= 0; 
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else if (wr_pulse_cnt < 2) begin 
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else begin
                        lcd_wr <= 1;
                        wr_pulse_cnt <= 0;
                        state <= S_IDLE; // 完成一个像素，回到空闲
                    end
                end
                
                // 7. 像素写入
                S_PIXEL_SETUP: begin
                    if (wr_pulse_cnt == 0) begin
                        lcd_wr <= 0;
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else if (wr_pulse_cnt < 2) begin 
                        wr_pulse_cnt <= wr_pulse_cnt + 1;
                    end else begin
                        lcd_wr <= 1;
                        wr_pulse_cnt <= 0;
                        state <= S_IDLE;
                    end
                end

            endcase
        end
    end

endmodule