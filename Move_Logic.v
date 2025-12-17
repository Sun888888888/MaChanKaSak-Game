`timescale 1ns / 1ps
module Move_Logic(
    input clk_100mhz, input reset, input wait_enable,
    input p1_submit_event, input p2_submit_event,
    input [3:0] p1_answer, input [3:0] p2_answer, input [3:0] correct_ans,
    input [9:0] rope_pos_x,
    output reg move_left, output reg move_right,
    output reg is_game_over, output reg [1:0] winner_code
    );
    localparam WIN_LIMIT_LEFT = 100; localparam WIN_LIMIT_RIGHT = 540;
    always @(posedge clk_100mhz) begin
        if (reset) begin move_left<=0; move_right<=0; is_game_over<=0; winner_code<=0; end
        else begin
            move_left <= 0; move_right <= 0;
            if (rope_pos_x <= WIN_LIMIT_LEFT) begin is_game_over <= 1; winner_code <= 1; end
            else if (rope_pos_x >= WIN_LIMIT_RIGHT) begin is_game_over <= 1; winner_code <= 2; end
            else if (wait_enable) begin
//                if (p1_submit_event) begin if (p1_answer == correct_ans) move_right <= 1; else move_left <= 1; end
//                if (p2_submit_event) begin if (p2_answer == correct_ans) move_left <= 1; else move_right <= 1; end
                if (p1_submit_event) begin if (p1_answer == correct_ans) move_left <= 1; else move_right <= 1; end
                if (p2_submit_event) begin if (p2_answer == correct_ans) move_right <= 1; else move_left <= 1; end
            end
        end
    end
endmodule