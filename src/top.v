`timescale 1ns / 1ps

module top(
    input        clk,          // 50 MHz from Tang Mega 138K
    input        rst_n,        // Active-low reset
    output       uart_tx,      // UART TX output
    output       led_done      // LED indicator
);

    // RFC 8439 Test Vector (Big-Endian byte streams as specified)
    localparam [255:0] TEST_KEY = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [95:0]  TEST_NONCE = 96'h000000090000004a00000000;
    localparam [31:0]  TEST_COUNTER = 32'h00000001;
    
    // Internal signals
    wire chacha_start;
    wire chacha_done;
    wire [511:0] chacha_key_stream;
    
    wire uart_start;
    wire uart_busy;
    wire uart_done;
    
    // Debug wires for chacha20_core (not used elsewhere)
    wire [2:0]   chacha_dbg_state_fsm;
    wire [511:0] chacha_dbg_state;
    wire [511:0] chacha_dbg_init_state;
    
    // Instantiate ChaCha20 core (from provided file)
    chacha20_core u_chacha20 (
        .clk(clk),
        .rst_n(rst_n),
        .start(chacha_start),
        .key(TEST_KEY),
        .nonce(TEST_NONCE),
        .counter(TEST_COUNTER),
        .key_stream(chacha_key_stream),
        .done(chacha_done),
        // Connect debug ports to dummy wires
        .dbg_state_fsm(chacha_dbg_state_fsm),
        .dbg_state(chacha_dbg_state),
        .dbg_init_state(chacha_dbg_init_state)
    );
    
    // Instantiate UART stream transmitter
    uart_stream_tx u_uart_stream (
        .clk(clk),
        .rst_n(rst_n),
        .start(uart_start),
        .data_in(chacha_key_stream),  // Will be transmitted in little-endian byte order
        .uart_tx(uart_tx),
        .busy(uart_busy),
        .done(uart_done)
    );
    
    // Instantiate controller
    chacha20_uart_ctrl u_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .chacha_start(chacha_start),
        .chacha_done(chacha_done),
        .chacha_key_stream(chacha_key_stream),
        .uart_start(uart_start),
        .uart_busy(uart_busy),
        .uart_done(uart_done),
        .led_done(led_done)
    );

endmodule