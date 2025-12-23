`timescale 1ns / 1ps

module chacha20_uart_ctrl(
    input        clk,
    input        rst_n,
    
    // ChaCha20 core interface
    output reg  chacha_start,
    input       chacha_done,
    input  [511:0] chacha_key_stream,
    
    // UART stream interface
    output reg  uart_start,
    input       uart_busy,
    input       uart_done,
    
    // Status output
    output reg  led_done
);

    // State definitions
    localparam IDLE          = 3'd0;
    localparam START_CHACHA  = 3'd1;
    localparam WAIT_CHACHA   = 3'd2;
    localparam SEND_UART     = 3'd3;
    localparam WAIT_UART     = 3'd4;
    localparam DONE          = 3'd5;
    
    reg [2:0] state;
    reg [511:0] key_stream_reg;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            chacha_start <= 1'b0;
            uart_start <= 1'b0;
            led_done <= 1'b0;
            key_stream_reg <= 512'b0;
        end else begin
            case (state)
                IDLE: begin
                    chacha_start <= 1'b0;
                    uart_start <= 1'b0;
                    led_done <= 1'b0;
                    // Auto-start on reset release (for testing)
                    state <= START_CHACHA;
                end
                
                START_CHACHA: begin
                    chacha_start <= 1'b1;
                    state <= WAIT_CHACHA;
                end
                
                WAIT_CHACHA: begin
                    chacha_start <= 1'b0;
                    if (chacha_done) begin
                        key_stream_reg <= chacha_key_stream;
                        state <= SEND_UART;
                    end
                end
                
                SEND_UART: begin
                    if (!uart_busy) begin
                        uart_start <= 1'b1;
                        state <= WAIT_UART;
                    end
                end
                
                WAIT_UART: begin
                    uart_start <= 1'b0;
                    if (uart_done) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    led_done <= 1'b1;
                    // Stay in DONE state
                    state <= DONE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule