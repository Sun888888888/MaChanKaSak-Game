`timescale 1ns / 1ps

module Input_Handler(
    input  clk_100mhz,
    input  reset,
    input  button_in,
    // ????????? output ??????? wire ???? reg ?? Verilog-2001
    output button_event 
    ); 

    localparam DEBOUNCE_LIMIT = 20'd100000;
    localparam COUNTER_BITS = 20;
    
    // Registers (??? reg ??? logic)
    reg [COUNTER_BITS-1:0] debounce_counter;
    reg button_synched;
    reg prev_button_synched;
    
    // Output Port: ?????????????? reg ????? module ???????????????????????? assign
    wire button_event; // ?????????? wire ?????????????? assign

    // --- Sequential Logic: Debounce and Synchronization (??? always @(posedge clk)) ---
    always @(posedge clk_100mhz) begin
        if(reset) begin
            debounce_counter    <= 0;
            button_synched      <= 1'b0; 
            prev_button_synched <= 1'b0;
        end
        else begin
            // 1. Debounce Counter
            if(button_in == button_synched) begin
                debounce_counter <= 0;
            end
            else begin
                if(debounce_counter == DEBOUNCE_LIMIT) begin
                    button_synched <= button_in;
                    debounce_counter <= 0;
                end
                else begin
                    debounce_counter <= debounce_counter + 1; 
                end
            end
            
            // 2. Edge Detection (Shift Register)
            prev_button_synched <= button_synched; 
        end
    end
    
    // --- Combinational Logic: Edge Event ---
    // Generates a high pulse for one clock cycle when the button is pressed (1 -> 0)
    assign button_event = prev_button_synched & ~button_synched; 

endmodule
