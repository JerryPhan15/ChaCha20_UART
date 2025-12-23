`timescale 1ns/1ps
// ============================================================
// Testbench: ChaCha20 + UART TX
// Clock : 50 MHz
// UART  : 115200 baud, 8N1
// ============================================================
// SIMULATION ONLY - DO NOT SYNTHESIZE
// ============================================================

module tb_top_uart_chacha20;

    // -------------------------------
    // Clock / Reset
    // -------------------------------
    reg clk;
    reg rst_n;

    localparam CLK_PERIOD = 20; // 50 MHz

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);
    end

    // -------------------------------
    // DUT I/O
    // -------------------------------
    wire uart_tx;
    wire led_done;

    // -------------------------------
    // DUT
    // -------------------------------
    top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_tx  (uart_tx),
        .led_done (led_done)
    );

    // =========================================================
    // UART RX PARAMETERS
    // =========================================================
    localparam BAUD_RATE  = 115200;
    localparam BIT_TIME   = 434;   // clock cycles
    localparam HALF_BIT   = 217;

    // =========================================================
    // UART RX FSM
    // =========================================================
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [8:0]  rx_clk_cnt;
    reg [3:0]  rx_bit_idx;
    reg [7:0]  rx_shift;
    reg [7:0]  rx_byte;
    reg        rx_valid;

    always @(posedge clk) begin
        rx_valid <= 1'b0;

        case (rx_state)

        RX_IDLE: begin
            if (uart_tx == 1'b0) begin
                rx_clk_cnt <= 0;
                rx_state   <= RX_START;
            end
        end

        RX_START: begin
            if (rx_clk_cnt == HALF_BIT) begin
                if (uart_tx == 1'b0) begin
                    rx_clk_cnt <= 0;
                    rx_bit_idx <= 0;
                    rx_state   <= RX_DATA;
                end else begin
                    rx_state <= RX_IDLE;
                end
            end else
                rx_clk_cnt <= rx_clk_cnt + 1;
        end

        RX_DATA: begin
            if (rx_clk_cnt == BIT_TIME) begin
                rx_shift[rx_bit_idx] <= uart_tx;
                rx_clk_cnt <= 0;
                if (rx_bit_idx == 7)
                    rx_state <= RX_STOP;
                else
                    rx_bit_idx <= rx_bit_idx + 1;
            end else
                rx_clk_cnt <= rx_clk_cnt + 1;
        end

        RX_STOP: begin
            if (rx_clk_cnt == BIT_TIME) begin
                rx_byte  <= rx_shift;
                rx_valid <= 1'b1;   // EXACTLY 1 cycle
                rx_state <= RX_IDLE;
                rx_clk_cnt <= 0;
            end else
                rx_clk_cnt <= rx_clk_cnt + 1;
        end

        endcase
    end

    // =========================================================
    // Expected keystream bytes (from DUT key_stream)
    // =========================================================
    reg [7:0] expected_bytes [0:63];
    integer i;

    initial begin
        // Wait until core finishes
        wait (dut.u_chacha20.done == 1'b1);
        $display("[%0t] Capturing expected keystream", $time);

        for (i = 0; i < 16; i = i + 1) begin
            expected_bytes[i*4 + 0] = dut.u_chacha20.key_stream[i*32 +: 8];
            expected_bytes[i*4 + 1] = dut.u_chacha20.key_stream[i*32+8 +: 8];
            expected_bytes[i*4 + 2] = dut.u_chacha20.key_stream[i*32+16+: 8];
            expected_bytes[i*4 + 3] = dut.u_chacha20.key_stream[i*32+24+: 8];
        end
    end

    // =========================================================
    // Byte comparison
    // =========================================================
    integer rx_idx;
    integer err_cnt;

    initial begin
        rx_idx  = 0;
        err_cnt = 0;
    end

    always @(posedge clk) begin
        if (rx_valid) begin
            $display("[%0t] RX byte %0d = 0x%02x",
                     $time, rx_idx, rx_byte);

            if (rx_byte !== expected_bytes[rx_idx]) begin
                $display("ERROR byte %0d exp=0x%02x got=0x%02x",
                         rx_idx, expected_bytes[rx_idx], rx_byte);
                err_cnt = err_cnt + 1;
            end

            rx_idx = rx_idx + 1;

            if (rx_idx == 64) begin
                $display("========================================");
                $display("Bytes received : %0d", rx_idx);
                $display("Errors         : %0d", err_cnt);
                if (err_cnt == 0)
                    $display("TEST PASSED");
                else
                    $display("TEST FAILED");
                $display("========================================");
                #1000;
                $finish;
            end
        end
    end

endmodule
