ChaCha20 UART Test Project
1. Project Overview

This project implements the ChaCha20 stream cipher on FPGA and verifies its functionality using UART communication.
A Python script on PC sends the Key, Nonce, and Counter to the FPGA and receives the generated keystream, which is compared against RFC 8439 test vectors.

2. System Architecture

FPGA

Receives ChaCha20 inputs via UART

Executes the ChaCha20 encryption core (20 rounds)

Sends the 512-bit keystream back via UART

PC (Python)

Transmits test data over UART

Receives and displays the keystream

Verifies correctness with reference vectors

3. Operation Flow

Python sends:

256-bit Key

96-bit Nonce

32-bit Counter

FPGA initializes the ChaCha20 state

Performs 20 ChaCha20 rounds

FPGA transmits the keystream via UART

Python validates the output

4. Technologies Used

Verilog HDL – ChaCha20 core and UART

FPGA – TangMega / Gowin FPGA

Python – UART test and verification

UART – PC ↔ FPGA communication

5. Project Goals

Understand ChaCha20 hardware implementation

Verify correctness using standard test vectors

Serve as a foundation for high-speed cryptographic systems

6. Reference

RFC 8439 – ChaCha20 and Poly1305
