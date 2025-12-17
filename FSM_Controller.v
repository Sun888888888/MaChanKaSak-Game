`timescale 1ns / 1ps

module FSM_Controller(
    input clk_100mhz,
    input game_tick,      
    input reset,
    input start_game_event,
    input p1_submit_event,
    input p2_submit_event,
    input is_game_over,
    input is_ans_correct, 
    
    output reg o_state_IDLE,
    output reg o_state_WAIT,
    output reg o_state_COUNTDOWN, 
    output reg o_state_WIN,
    output reg o_enable_question_random, 
    output reg [3:0] countdown_val
    );

    localparam S_IDLE=0, S_WAIT=1, S_CHECK=2, S_WIN=3, S_COUNT=4;
    reg [2:0] state, next_state; 
    reg [7:0] delay_timer; 
    
    // ???? Countdown 1.5 ??????
    localparam DELAY_LIMIT = 90; 

    always @(posedge clk_100mhz) begin
        if (reset) begin 
            state <= S_IDLE; 
            delay_timer <= 0; 
        end
        else begin
            state <= next_state;
            
            // Timer ???????
            if (state == S_COUNT) begin 
                if (game_tick) delay_timer <= delay_timer + 1; 
            end 
            else delay_timer <= 0;
        end
    end
    
    // ???????????? 3, 2, 1 (?????? 0.5 ??????)
    always @* begin
        if (delay_timer < 30) countdown_val = 3;      
        else if (delay_timer < 60) countdown_val = 2; 
        else countdown_val = 1;                       
    end

    // Logic ??????? State
    always @* begin
        next_state = state; 
        o_enable_question_random = 0; 
        
        case (state)
            S_IDLE: begin
                if (start_game_event) begin 
                    next_state = S_WAIT; 
                    o_enable_question_random = 1; 
                end
            end
            S_WAIT: begin
                if (p1_submit_event || p2_submit_event) next_state = S_CHECK;
            end
            S_CHECK: begin
                if (is_game_over) next_state = S_WIN; 
                else next_state = S_COUNT;
            end
            S_COUNT: begin
                if (delay_timer >= DELAY_LIMIT) begin 
                    next_state = S_WAIT; 
                    
                    // *** ??????????????? ***
                    // ??????? 1 ???? ??? "??????????????????" ????????????????
                    o_enable_question_random = 1; 
                end
            end
            S_WIN: begin
                if (reset || start_game_event) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    always @* begin
        o_state_IDLE      = (state == S_IDLE);
        o_state_WAIT      = (state == S_WAIT);
        o_state_COUNTDOWN = (state == S_COUNT);
        o_state_WIN       = (state == S_WIN);
    end
endmodule