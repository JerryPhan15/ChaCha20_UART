`timescale 1ns / 1ps

module uart_stream_tx(
    input        clk,
    input        rst_n,
    input        start,
    input  [511:0] data_in,
    output       uart_tx,
    output       busy,
    output       done
);

    // State definitions
    localparam IDLE = 2'd0;
    localparam SEND_BYTE = 2'd1;
    localparam WAIT_BUSY = 2'd2;
    localparam DONE_STATE = 2'd3;
    
    reg [1:0] state;
    reg [5:0] byte_counter;  // 0-63 (64 bytes)
    reg [511:0] data_reg;
    reg tx_start;
    reg done_reg;
    wire tx_busy;
    
    // Byte selector for little-endian extraction
    wire [7:0] current_byte;
    
    // Instantiate single byte transmitter
    uart_byte_tx u_tx_byte (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(current_byte),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );
    
    // Byte extraction (little-endian)
    assign current_byte = data_reg[byte_counter*8 +: 8];
    
    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_counter <= 6'd0;
            data_reg <= 512'b0;
            tx_start <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        state <= SEND_BYTE;
                        data_reg <= data_in;
                        byte_counter <= 6'd0;
                    end
                end
                
                SEND_BYTE: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        state <= WAIT_BUSY;
                    end
                end
                
                WAIT_BUSY: begin
                    tx_start <= 1'b0;
                    if (tx_busy) begin
                        // Wait for transmission to start
                        state <= WAIT_BUSY;
                    end else if (byte_counter == 6'd63) begin
                        // All bytes sent
                        state <= DONE_STATE;
                    end else begin
                        // Move to next byte
                        byte_counter <= byte_counter + 1'b1;
                        state <= SEND_BYTE;
                    end
                end
                
                DONE_STATE: begin
                    done_reg <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign busy = (state != IDLE);
    assign done = done_reg;

endmodule