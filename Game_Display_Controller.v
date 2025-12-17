`timescale 1ns / 1ps

module Game_Display_Controller(
    input  clk_100mhz,
    input  reset,
    input  [3:0] q_id,
    input  [3:0] p1_val,
    input  [3:0] p2_val,
    input  [9:0] rope_x,
    input  [1:0] winner_code,
    input is_idle,              
    input is_countdown,         
    input [3:0] countdown_val,  
    output hsync,
    output vsync,
    output [3:0] red,
    output [3:0] green,
    output [3:0] blue
    );

    // VGA Timing (640x480 @ 60Hz)
    localparam H_TOTAL = 800;
    localparam V_TOTAL = 525;
    
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;
    reg [1:0] tick_cnt;
    wire p_tick = (tick_cnt == 0); 
    
    always @(posedge clk_100mhz) tick_cnt <= tick_cnt + 1;
    
    always @(posedge clk_100mhz) begin
        if(reset) {h_count, v_count} <= 0;
        else if(p_tick) begin
            if(h_count == 799) begin
                h_count <= 0;
                if(v_count == 524) v_count <= 0;
                else v_count <= v_count + 1;
            end
            else h_count <= h_count + 1;
        end
    end
    
    assign hsync = ~(h_count >= 656 && h_count < 752);
    assign vsync = ~(v_count >= 490 && v_count < 492);
    wire video_on = (h_count < 640) && (v_count < 480);

    // Background (IP Core)
    wire [12:0] bg_addr = (v_count[8:3] << 6) + (v_count[8:3] << 4) + h_count[9:3];
    wire [11:0] bg_rgb;
    BG_ROM bg_rom_inst (.clka(clk_100mhz), .addra(bg_addr), .douta(bg_rgb));
    
    wire [11:0] p1_win_rgb;
        P1_WIN_ROM p1_win_rom_inst (
                .clka(clk_100mhz), 
                .addra(bg_addr), 
                .douta(p1_win_rgb) // �ըҡ p1_win.coe
            ); 
            
    wire [11:0] p2_win_rgb;
    P2_WIN_ROM p2_win_rom_inst (
        .clka(clk_100mhz), 
        .addra(bg_addr), 
        .douta(p2_win_rgb) // �ըҡ p2_win.coe
    );

    // Area Definitions
    localparam CW=16, CH=32; // ????????????????
    wire in_p1 = (h_count >= 50 && h_count < 82 && v_count >= 400 && v_count < 432);
    wire in_p2 = (h_count >= 550 && h_count < 582 && v_count >= 400 && v_count < 432);
    wire in_center = (h_count >= 220 && h_count < 380 && v_count >= 80 && v_count < 144);

    // Character Logic
    reg [4:0] char_code;
    reg [5:0] rel_x;
    reg [6:0] rel_y;
    reg is_big;
    
    reg [3:0] nA, nB;
    always @* begin
        case(q_id)
            4'd0: {nA,nB} = {4'd1, 4'd2};
            4'd1: {nA,nB} = {4'd5, 4'd2};
            4'd2: {nA,nB} = {4'd3, 4'd2};
            4'd3: {nA,nB} = {4'd4, 4'd5};
            4'd4: {nA,nB} = {4'd8, 4'd7};
            4'd5: {nA,nB} = {4'd2, 4'd6};
            4'd6: {nA,nB} = {4'd6, 4'd6};
            4'd7: {nA,nB} = {4'd4, 4'd3};
            4'd8: {nA,nB} = {4'd5, 4'd9};
            4'd9: {nA,nB} = {4'd9, 4'd6};
            default: {nA,nB} = {4'd0, 4'd0};
        endcase
    end

    always @* begin
        is_big = 0; char_code = 31; rel_x=0; rel_y=0;
        
        // P1 Score Display
        if (in_p1) begin 
            rel_x = (h_count - 50) % CW; 
            rel_y = v_count - 400;
            if (h_count - 50 < CW) char_code = (p1_val >= 10) ? 1 : p1_val; 
            else char_code = (p1_val >= 10) ? p1_val - 10 : 31;
        end
        // P2 Score Display
        else if (in_p2) begin 
            rel_x = (h_count - 550) % CW; 
            rel_y = v_count - 400;
            if (h_count - 550 < CW) char_code = (p2_val >= 10) ? 1 : p2_val; 
            else char_code = (p2_val >= 10) ? p2_val - 10 : 31;
        end
        // Center Question / Countdown
        else if (in_center) begin 
            is_big = 1;
            rel_x = (h_count - 220) % 32; 
            rel_y = v_count - 80;
            
            if (is_idle) begin // "START"
                case ((h_count - 220) / 32)
                    0: char_code = 16; // S
                    1: char_code = 17; // T
                    2: char_code = 10; // A
                    3: char_code = 18; // R
                    4: char_code = 17; // T
                    default: char_code = 31;
                endcase
            end
            else if (is_countdown) begin // Show 3, 2, 1
                if ((h_count - 220) / 32 == 2) char_code = countdown_val;
                else char_code = 31;
            end
            else begin // Question "A + B"
                case ((h_count - 220) / 32)
                    0: char_code = nA;
                    1: char_code = 20; // +
                    2: char_code = nB;
                    3: char_code = 21; // =
                    4: char_code = 22; // ?
                    default: char_code = 31;
                endcase
            end
        end
    end

    // Font ROM Logic (Bitmap)
    reg [7:0] row_data;
    wire [3:0] rr = is_big ? rel_y[5:2] : rel_y[4:1];
    wire [2:0] rc = is_big ? rel_x[4:2] : rel_x[3:1];

    always @* begin
        case(char_code)
            0: case(rr) 0,15: row_data=0; 1,14: row_data=8'h3C; default: row_data=8'h42; endcase
            1: row_data=8'h18;
            2: case(rr) 1,7,14: row_data=8'h7E; 2,3,4,5,6: row_data=8'h06; 8,9,10,11,12,13: row_data=8'h60; default: row_data=0; endcase
            3: case(rr) 1,7,14: row_data=8'h7E; default: row_data=8'h06; endcase
            4: case(rr) 7: row_data=8'h7E; 8,9,10,11,12,13,14: row_data=8'h06; default: row_data=8'h66; endcase
            5: case(rr) 1,7,14: row_data=8'h7E; 2,3,4,5,6: row_data=8'h60; 8,9,10,11,12,13: row_data=8'h06; default: row_data=0; endcase
            6: case(rr) 1,7,14: row_data=8'h7E; 2,3,4,5,6: row_data=8'h60; default: row_data=8'h66; endcase
            7: case(rr) 1: row_data=8'h7E; default: row_data=8'h06; endcase
            8: case(rr) 1,7,14: row_data=8'h7E; default: row_data=8'h66; endcase
            9: case(rr) 1,7,14: row_data=8'h7E; 8,9,10,11,12,13: row_data=8'h06; default: row_data=8'h66; endcase
            10: case(rr) 1,7: row_data=8'h3C; 4: row_data=8'h7E; default: row_data=8'h42; endcase // A
            16: case(rr) 1,7,14: row_data=8'h7E; 2,3,4,5,6: row_data=8'h60; 8,9,10,11,12,13: row_data=8'h06; default: row_data=0; endcase // S
            17: case(rr) 6: row_data=8'h7E; 4,5,7,8,9,10,11,12,13: row_data=8'h18; 14: row_data=8'h3C; default: row_data=0; endcase // T
            18: case(rr) 4,6,7,8,9,10,11,12,13,14: row_data=8'h18; 5: row_data=8'h28; default: row_data=0; endcase // R
            20: case(rr) 7,8: row_data=8'h7E; 4,5,6,9,10,11: row_data=8'h18; default: row_data=0; endcase // +
            21: case(rr) 6,9: row_data=8'h7E; default: row_data=0; endcase // =
            22: case(rr) 1: row_data=8'h3C; 2,3: row_data=8'h42; 4,5,7: row_data=8'h04; 10: row_data=8'h18; default: row_data=0; endcase // ?
            default: row_data=0;
        endcase
    end

    // Pixel Logic
    wire px = (in_center || in_p1 || in_p2) && row_data[7-rc];
    
    // Rope Logic
    wire rope = (v_count >= 238 && v_count <= 242) || 
                ((h_count >= rope_x - 5) && (h_count <= rope_x + 5) && (v_count >= 230) && (v_count <= 250));

    // Color Output
    reg [11:0] rgb;
    always @* begin
        if(!video_on) rgb = 0;
        else if(winner_code == 1) rgb = p1_win_rgb; // P1 Wins (Green)
        else if(winner_code == 2) rgb = p2_win_rgb; // P2 Wins (Blue)
        else if(px) begin
             if(is_idle) rgb = 12'h0FF; // Start text (Cyan)
             else if(is_countdown) rgb = 12'hF80; // Countdown text (Orange)
             else if(in_center) rgb = 12'hF00; // Question (Red)
             else rgb = 12'hFF0; // Player Inputs (Yellow)
        end
        else if(rope) begin
            // *** ?????????? *** (Red=15, Green=8, Blue=0)
            rgb = 12'hF80; 
        end
        else rgb = bg_rgb; // Background
    end

    assign {red, green, blue} = rgb;

endmodule