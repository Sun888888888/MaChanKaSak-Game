`timescale 1ns / 1ps

// ============================================================================
// 1. TOP MODULE
// ============================================================================
module Top_Module(
    input  CLK100MHZ,   
    input  BTNC,        // Reset
    input  [3:0] SW_P1, // ????? P1
    input  [3:0] SW_P2, // ????? P2
    input  BTNL_P1,     // ??????? P1
    input  BTNR_P2,     // ??????? P2
    input  BTNU_START,  // ???? Start

    output VGASYNC,      
    output VGAHSYNC,     
    output [3:0] VGABlue,
    output [3:0] VGAGreen,
    output [3:0] VGARed,
    output [3:0] LED     // ???????
    );

    // --- Internal Wires ---
    wire game_tick;
    wire p1_submit_event, p2_submit_event, start_game_event;
    
    // FSM Wires
    wire FSM_state_IDLE, FSM_state_WAIT, FSM_state_WIN, FSM_state_COUNTDOWN; 
    wire enable_new_question; 
    wire [3:0] countdown_val; 
    
    // Game Logic Wires
    wire [3:0] current_q_id;
    wire [3:0] current_correct_ans;
    wire question_ready;
    wire [9:0] rope_pos_x;
    wire is_game_over;
    wire [1:0] winner_code;      
    wire move_left_trigger, move_right_trigger;     

    // ** Logic ????????? **
    wire is_current_ans_correct;
    // ??? P1 ?? ??? ???????? OR ??? P2 ?? ??? ????????
    assign is_current_ans_correct = (p1_submit_event && (SW_P1 == current_correct_ans)) || 
                                    (p2_submit_event && (SW_P2 == current_correct_ans));

    // --- Modules Instantiation ---
    
    // 1. Clock Helper (???????? Module ????????)
    Clock_Divider CLK_INST (.clk_100mhz(CLK100MHZ), .reset(BTNC), .game_tick(game_tick));

    // 2. Input Helpers (???????? Module ????????)
    Input_Handler START_INPUT (.clk_100mhz(CLK100MHZ), .reset(BTNC), .button_in(BTNU_START), .button_event(start_game_event));
    Input_Handler P1_INPUT    (.clk_100mhz(CLK100MHZ), .reset(BTNC), .button_in(BTNL_P1),    .button_event(p1_submit_event));
    Input_Handler P2_INPUT    (.clk_100mhz(CLK100MHZ), .reset(BTNC), .button_in(BTNR_P2),    .button_event(p2_submit_event));

    // 3. FSM (Controller) - *???????*
    FSM_Controller FSM_INST (
        .clk_100mhz(CLK100MHZ), .game_tick(game_tick), .reset(BTNC),
        .start_game_event(start_game_event), 
        .p1_submit_event(p1_submit_event), .p2_submit_event(p2_submit_event),
        .is_game_over(is_game_over), .is_ans_correct(is_current_ans_correct), 
        .o_state_IDLE(FSM_state_IDLE), .o_state_WAIT(FSM_state_WAIT),
        .o_state_WIN(FSM_state_WIN), .o_state_COUNTDOWN(FSM_state_COUNTDOWN), 
        .countdown_val(countdown_val), .o_enable_question_random(enable_new_question)
    );

    // 4. Question Select - *???????*
    Question_Select_Logic Q_LOGIC (
        .clk_100mhz(CLK100MHZ), .reset(BTNC), .game_tick(game_tick),
        .question_enable(enable_new_question), .question_ready(question_ready),
        .correct_ans(current_correct_ans), .selected_q_id(current_q_id)
    );
    assign LED = current_q_id; 

    // 5. Move Logic - *???????*
    Move_Logic MOVE_LOGIC_INST (
        .clk_100mhz(CLK100MHZ), .reset(BTNC), .wait_enable(FSM_state_WAIT), 
        .p1_submit_event(p1_submit_event), .p2_submit_event(p2_submit_event),
        .p1_answer(SW_P1), .p2_answer(SW_P2), .correct_ans(current_correct_ans),
        .rope_pos_x(rope_pos_x),
        .move_left(move_left_trigger), .move_right(move_right_trigger), 
        .is_game_over(is_game_over), .winner_code(winner_code)
    );

    // 6. Position Helper (???????? Module ????????)
    Position_Counter POS_CNT_INST (
        .clk_100mhz(CLK100MHZ), .reset(BTNC || FSM_state_IDLE), 
        .move_left(move_left_trigger), .move_right(move_right_trigger),
        .rope_pos_x(rope_pos_x)          
    );

    // 7. VGA Display - *???????*
    Game_Display_Controller VGA_INST (
        .clk_100mhz (CLK100MHZ), .reset(BTNC),
        .q_id(current_q_id), .p1_val(SW_P1), .p2_val(SW_P2),
        .rope_x(rope_pos_x), .winner_code(winner_code),   
        .is_idle(FSM_state_IDLE), .is_countdown(FSM_state_COUNTDOWN), .countdown_val(countdown_val),
        .hsync(VGAHSYNC), .vsync(VGASYNC),
        .red(VGARed), .green(VGAGreen), .blue(VGABlue)
    );

endmodule


// ============================================================================
// HELPER MODULES (Clock, Input, Position)
// ============================================================================

// 1. Clock Divider (32-bit: ??? Countdown ????)
module Clock_Divider(input clk_100mhz, input reset, output reg game_tick);
    reg [31:0] count; 
    localparam DIV_VALUE = 1666666;
    always @(posedge clk_100mhz) begin
        if (reset) begin count <= 0; game_tick <= 0; end
        else begin
            if (count >= DIV_VALUE) begin count <= 0; game_tick <= 1; end
            else begin count <= count + 1; game_tick <= 0; end
        end
    end
endmodule

// 2. Input Handler
module Input_Handler(input clk_100mhz, input reset, input button_in, output reg button_event);
    reg [19:0] counter; reg btn_prev; wire btn_clean;
    always @(posedge clk_100mhz) if (reset) counter <= 0; else if (button_in != btn_prev) counter <= counter + 1; else counter <= 0;
    assign btn_clean = (counter >= 20'd1_000_000) ? button_in : btn_prev;
    always @(posedge clk_100mhz) begin
        if (reset) begin btn_prev <= 0; button_event <= 0; end
        else begin
            if (btn_clean == 1 && btn_prev == 0) button_event <= 1; else button_event <= 0;
            if (counter >= 20'd1_000_000) btn_prev <= button_in; 
        end
    end
endmodule

// 3. Position Counter (??????????????? 45 pixel = 5 ????????)
module Position_Counter(input clk_100mhz, input reset, input move_left, input move_right, output reg [9:0] rope_pos_x);
    always @(posedge clk_100mhz) begin
        if (reset) rope_pos_x <= 320; 
        else begin
            if (move_left && rope_pos_x > 45) rope_pos_x <= rope_pos_x - 45;
            else if (move_right && rope_pos_x < 595) rope_pos_x <= rope_pos_x + 45;
        end
    end
endmodule