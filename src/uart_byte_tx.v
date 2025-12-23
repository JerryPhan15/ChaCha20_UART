`timescale 1ns / 1ps

module uart_byte_tx(
    input        clk,
    input        rst_n,
    input        tx_start,
    input  [7:0] tx_data,
    output       tx,
    output       tx_busy
);

    // Internal signals matching existing uart_byte_tx structure
    wire tx_done_internal;
    reg tx_start_reg;
    
    // Instantiate existing UART module (fixed baud rate for 115200 @ 50MHz)
    uart_byte_tx_existing #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(115200)
    ) u_tx (
        .clk(clk),
        .reset_n(rst_n),
        .data_byte(tx_data),
        .send_en(tx_start_reg),
        .uart_tx(tx),
        .tx_done(tx_done_internal),
        .uart_state(tx_busy)
    );
    
    // Register tx_start to ensure proper pulse detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start_reg <= 1'b0;
        end else begin
            if (tx_start && !tx_busy) begin
                tx_start_reg <= 1'b1;
            end else begin
                tx_start_reg <= 1'b0;
            end
        end
    end

endmodule

// Modified version of existing uart_byte_tx with fixed baud rate
module uart_byte_tx_existing #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input        clk,
    input        reset_n,
    input  [7:0] data_byte,
    input        send_en,
    output reg   uart_tx,
    output reg   tx_done,
    output reg   uart_state
);

    wire reset = ~reset_n;
    localparam START_BIT = 1'b0;
    localparam STOP_BIT = 1'b1;
    
    // Baud rate calculation for 50MHz clock
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    
    reg bps_clk;
    reg [15:0] div_cnt;
    reg [3:0] bps_cnt;
    reg [7:0] data_byte_reg;
    reg tx_active;

    // UART state control
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_state <= 1'b0;
            tx_active <= 1'b0;
        end else begin
            if (send_en && !tx_active) begin
                uart_state <= 1'b1;
                tx_active <= 1'b1;
            end else if (bps_cnt == 4'd11) begin
                uart_state <= 1'b0;
                tx_active <= 1'b0;
            end
        end
    end

    // Store data to be transmitted
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_byte_reg <= 8'd0;
        end else if (send_en && !tx_active) begin
            data_byte_reg <= data_byte;
        end
    end

    // Division counter
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt <= 16'd0;
        end else if (uart_state) begin
            if (div_cnt == BAUD_DIV) begin
                div_cnt <= 16'd0;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt <= 16'd0;
        end
    end

    // Generate baud rate clock
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bps_clk <= 1'b0;
        end else if (uart_state && (div_cnt == BAUD_DIV)) begin
            bps_clk <= 1'b1;
        end else begin
            bps_clk <= 1'b0;
        end
    end

    // Baud rate counter
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bps_cnt <= 4'd0;
        end else if (!uart_state) begin
            bps_cnt <= 4'd0;
        end else if (bps_clk) begin
            if (bps_cnt == 4'd11) begin
                bps_cnt <= 4'd0;
            end else begin
                bps_cnt <= bps_cnt + 1'b1;
            end
        end
    end

    // Transmission complete
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_done <= 1'b0;
        end else if (bps_cnt == 4'd11 && bps_clk) begin
            tx_done <= 1'b1;
        end else begin
            tx_done <= 1'b0;
        end
    end

    // UART transmission logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_tx <= 1'b1;
        end else if (uart_state) begin
            case(bps_cnt)
                0: uart_tx <= 1'b1;
                1: uart_tx <= START_BIT;
                2: uart_tx <= data_byte_reg[0];
                3: uart_tx <= data_byte_reg[1];
                4: uart_tx <= data_byte_reg[2];
                5: uart_tx <= data_byte_reg[3];
                6: uart_tx <= data_byte_reg[4];
                7: uart_tx <= data_byte_reg[5];
                8: uart_tx <= data_byte_reg[6];
                9: uart_tx <= data_byte_reg[7];
                10: uart_tx <= STOP_BIT;
                default: uart_tx <= 1'b1;
            endcase
        end else begin
            uart_tx <= 1'b1;
        end
    end

endmodule