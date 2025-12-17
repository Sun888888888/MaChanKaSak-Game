`timescale 1ns / 1ps

module Clock_Divider(
    input clk_100mhz,
    input reset,
    output game_tick
    );

    localparam COUNTER_LIMIT = 20'd999999;
    localparam COUNTER_BITS = 20;
    
    reg [COUNTER_BITS-1:0] counter;
    reg game_tick_reg;
    
    always @(posedge clk_100mhz) begin
        if(reset) begin
            counter <= 0;
            game_tick_reg <= 1'b0;
        end
        else begin
            if(counter == COUNTER_LIMIT) begin
                counter <= 0;
                game_tick_reg <= ~game_tick_reg;
            end
            else begin
                counter <= counter + 1;
            end
        end
    end
    
    assign game_tick = game_tick_reg;
    
endmodule