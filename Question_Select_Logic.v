`timescale 1ns / 1ps
module Question_Select_Logic(
    input clk_100mhz, 
    input reset, 
    input game_tick, 
    input question_enable,
    output reg question_ready, 
    output reg [3:0] correct_ans, 
    output reg [3:0] selected_q_id
    );
    reg [3:0] lfsr = 4'b1011; 
    reg [3:0] q_id;
    always @(posedge clk_100mhz) begin
        if (reset) begin 
            selected_q_id<=4'd0; 
            correct_ans<=4'd0; 
            question_ready<=1'b0; 
            lfsr<=4'b1011; 
        end else begin
            question_ready <= 1'b0;
            lfsr <= {lfsr[2:0], lfsr[3]^lfsr[2]}; 
            if (question_enable) begin 
                q_id <= lfsr % 10;
                selected_q_id <= lfsr % 10; 
                question_ready <= 1'b1; 
                
                case (lfsr % 10)
                            4'd0: correct_ans<=4'd3; 
                            4'd1: correct_ans<=4'd7; 
                            4'd2: correct_ans<=4'd5; 
                            4'd3: correct_ans<=4'd9; 
                            4'd4: correct_ans<=4'd15;
                            4'd5: correct_ans<=4'd8; 
                            4'd6: correct_ans<=4'd12; 
                            4'd7: correct_ans<=4'd7; 
                            4'd8: correct_ans<=4'd14; 
                            4'd9: correct_ans<=4'd15;
                            default: correct_ans<=4'd0;
                 endcase
            end
        end
    end
//    always @* begin
        
//    end
endmodule