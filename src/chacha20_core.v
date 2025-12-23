// ============================================================
// ChaCha20 Core - RFC 8439 Compliant với Debug đầy đủ
// ============================================================

module chacha20_core (
    // Clock and control
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    
    // Data inputs (BIG-ENDIAN byte streams)
    input  wire [255:0] key,      // key[255:248] = byte0 (MSB)
    input  wire [95:0]  nonce,    // nonce[95:88] = byte0 (MSB)
    input  wire [31:0]  counter,  // counter[31:24] = byte0 (MSB)
    
    // Output (LITTLE-ENDIAN 32-bit words)
    output reg  [511:0] key_stream,  // key_stream[511:480] = word0 (MSW)
    output reg          done,
    
    // Debug outputs
    output wire [2:0]    dbg_state_fsm,
    output wire [511:0]  dbg_state,
    output wire [511:0]  dbg_init_state
);

// ============================================================
// FSM STATES
// ============================================================
localparam S_IDLE      = 3'd0;
localparam S_INIT      = 3'd1;
localparam S_ROUND_COL = 3'd2;
localparam S_ROUND_DIA = 3'd3;
localparam S_DONE      = 3'd4;

reg [2:0] state_fsm;
reg [3:0] round_count;
reg [31:0] sum_word;


// ============================================================
// INTERNAL STATE
// ============================================================
reg [511:0] state;
reg [511:0] init_state;

assign dbg_state_fsm  = state_fsm;
assign dbg_state      = state;
assign dbg_init_state = init_state;

// ============================================================
// STATE ACCESS FUNCTIONS với Debug
// ============================================================

function [31:0] get_word;
    input [511:0] st;
    input [3:0]   index;  // 0-15
begin
    // Little-endian: word0 = st[31:0], word1 = st[63:32], ...
    get_word = st[index*32 +: 32];
end
endfunction

function [511:0] set_word;
    input [511:0] st;
    input [3:0]   index;
    input [31:0]  value;
    reg [511:0] tmp;
begin
    tmp = st;
    tmp[index*32 +: 32] = value;
    set_word = tmp;
end
endfunction

// ============================================================
// CONVERSION FUNCTIONS với Debug
// ============================================================

function [31:0] be_to_le_word;
    input [31:0] be_word;
begin
    be_to_le_word = {be_word[7:0], be_word[15:8], be_word[23:16], be_word[31:24]};
end
endfunction

function [31:0] get_key_chunk;
    input [255:0] data;
    input [2:0]   chunk_num;  // 0-7
    reg [31:0] chunk;
begin
    // Key: BE format, key[255:224] = word0 (BE)
    case(chunk_num)
        0: chunk = data[255:224];
        1: chunk = data[223:192];
        2: chunk = data[191:160];
        3: chunk = data[159:128];
        4: chunk = data[127:96];
        5: chunk = data[95:64];
        6: chunk = data[63:32];
        7: chunk = data[31:0];
    endcase
    get_key_chunk = chunk;
end
endfunction

function [31:0] get_nonce_chunk;
    input [95:0] data;
    input [1:0]  chunk_num;  // 0-2
    reg [31:0] chunk;
begin
    // Nonce: BE format, nonce[95:64] = word0 (BE)
    case(chunk_num)
        0: chunk = data[95:64];
        1: chunk = data[63:32];
        2: chunk = data[31:0];
    endcase
    get_nonce_chunk = chunk;
end
endfunction

// QUARTER ROUND 
function [127:0] quarter_round;
    input [31:0] a, b, c, d;
    reg [31:0] a_out, b_out, c_out, d_out;
begin
    $display("  QR Input:  a=%h, b=%h, c=%h, d=%h", a, b, c, d);
    
    // Quarter round operations (Chacha20 QR operations)
    // 1. a += b; d ^= a; d = d <<< 16;
    a_out = a + b;
    d_out = d ^ a_out;
    d_out = {d_out[15:0], d_out[31:16]};  // Rotate left 16
    
    // 2. c += d; b ^= c; b = b <<< 12;
    c_out = c + d_out;
    b_out = b ^ c_out;
    b_out = {b_out[19:0], b_out[31:20]};  // Rotate left 12
    
    // 3. a += b; d ^= a; d = d <<< 8;
    a_out = a_out + b_out;
    d_out = d_out ^ a_out;
    d_out = {d_out[23:0], d_out[31:24]};  // Rotate left 8
    
    // 4. c += d; b ^= c; b = b <<< 7;
    c_out = c_out + d_out;
    b_out = b_out ^ c_out;
    b_out = {b_out[24:0], b_out[31:25]};  // Rotate left 7
    
    $display("  QR Output: a=%h, b=%h, c=%h, d=%h", a_out, b_out, c_out, d_out);
    
    quarter_round = {a_out, b_out, c_out, d_out};
end
endfunction

// ============================================================
// MAIN FSM 
// ============================================================
integer i;  // For loop variable

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        // Reset
        state_fsm   <= S_IDLE;
        done        <= 1'b0;
        key_stream  <= 512'b0;
        state       <= 512'b0;
        init_state  <= 512'b0;
        round_count <= 4'd0;
        
        $display("\n=== DEBUG: RESET ===");
    end else begin
        case(state_fsm)
        
        S_IDLE: begin
            done <= 1'b0;
            if(start) begin
                state_fsm   <= S_INIT;
                round_count <= 4'd0;
                $display("\n=== DEBUG: START detected, moving to INIT ===");
                $display("Input Key (BE): %h", key);
                $display("Input Nonce (BE): %h", nonce);
                $display("Input Counter (BE): %h", counter);
            end
        end
        
        S_INIT: begin
            $display("\n=== DEBUG INIT STATE ===");
            $display("Setting up initial state matrix (Little-endian words)");
            
            // Constants (Little-endian)
            state = set_word(512'b0, 0, 32'h61707865);  // "expa"
            state = set_word(state,  1, 32'h3320646e);  // "nd 3"
            state = set_word(state,  2, 32'h79622d32);  // "2-by"
            state = set_word(state,  3, 32'h6b206574);  // "te k"
            
            $display("Constants: word0-3 = %h %h %h %h", 
                    get_word(state, 0), get_word(state, 1), 
                    get_word(state, 2), get_word(state, 3));
            
            // Key - BE to LE conversion (8 words)
            for(i = 0; i < 8; i = i + 1) begin
                state = set_word(state, 4 + i, 
                               be_to_le_word(get_key_chunk(key, i[2:0])));
                $display("Key word%d: BE=%h -> LE=%h", 
                        i, get_key_chunk(key, i[2:0]), 
                        be_to_le_word(get_key_chunk(key, i[2:0])));
            end
            
            // Counter - KHÔNG áp dụng be_to_le_word vì counter đã là BE
            state = set_word(state, 12, counter);  // ĐÃ SỬA
            $display("Counter word12: BE=%h -> stored as %h (LE)", 
                    counter, counter);  // ĐÃ SỬA
            // ===================================
            
            // Nonce - BE to LE (3 words)
            for(i = 0; i < 3; i = i + 1) begin
                state = set_word(state, 13 + i, 
                               be_to_le_word(get_nonce_chunk(nonce, i[1:0])));
                $display("Nonce word%d: BE=%h -> LE=%h", 
                        i, get_nonce_chunk(nonce, i[1:0]), 
                        be_to_le_word(get_nonce_chunk(nonce, i[1:0])));
            end
            
            // Display full initial state
            $display("\nInitial state matrix (16 LE words):");
            for(i = 0; i < 16; i = i + 1) begin
                if(i % 4 == 0) $write("Row %0d: ", i/4);
                $write("%h ", get_word(state, i));
                if(i % 4 == 3) $display("");
            end
            
            init_state <= state;
            state_fsm  <= S_ROUND_COL;
            $display("===========================\n");
        end
        
        S_ROUND_COL: begin
            $display("\n=== DEBUG COLUMN ROUND %0d ===", round_count);
            
            // Display state before column round
            $display("State before column round:");
            for(i = 0; i < 4; i = i + 1) begin
                $display("Column %0d: %h %h %h %h", 
                        i,
                        get_word(state, i),      // row0
                        get_word(state, i+4),    // row1
                        get_word(state, i+8),    // row2
                        get_word(state, i+12));  // row3
            end
            
            // Column quarter rounds (4 columns)
            $display("\nColumn Quarter Rounds:");
            
            // Column 0: word0, word4, word8, word12
            $display("Column 0 QR:");
            {state[31:0], state[159:128], state[287:256], state[415:384]} = 
                quarter_round(get_word(state, 0), get_word(state, 4),
                            get_word(state, 8), get_word(state, 12));
            
            // Column 1: word1, word5, word9, word13
            $display("Column 1 QR:");
            {state[63:32], state[191:160], state[319:288], state[447:416]} = 
                quarter_round(get_word(state, 1), get_word(state, 5),
                            get_word(state, 9), get_word(state, 13));
            
            // Column 2: word2, word6, word10, word14
            $display("Column 2 QR:");
            {state[95:64], state[223:192], state[351:320], state[479:448]} = 
                quarter_round(get_word(state, 2), get_word(state, 6),
                            get_word(state, 10), get_word(state, 14));
            
            // Column 3: word3, word7, word11, word15
            $display("Column 3 QR:");
            {state[127:96], state[255:224], state[383:352], state[511:480]} = 
                quarter_round(get_word(state, 3), get_word(state, 7),
                            get_word(state, 11), get_word(state, 15));
            
            $display("State after column round %0d:", round_count);
            for(i = 0; i < 16; i = i + 4) begin
                $display("Words %0d-%0d: %h %h %h %h", 
                        i, i+3,
                        get_word(state, i),
                        get_word(state, i+1),
                        get_word(state, i+2),
                        get_word(state, i+3));
            end
            
            state_fsm <= S_ROUND_DIA;
        end
        
        S_ROUND_DIA: begin
            $display("\n=== DEBUG DIAGONAL ROUND %0d ===", round_count);
            
            // Display state before diagonal round
            $display("State before diagonal round:");
            for(i = 0; i < 4; i = i + 1) begin
                $display("Row %0d: %h %h %h %h", 
                        i,
                        get_word(state, i*4),
                        get_word(state, i*4+1),
                        get_word(state, i*4+2),
                        get_word(state, i*4+3));
            end
            
            $display("\nDiagonal Quarter Rounds:");
            
            // Diagonal 0: word0, word5, word10, word15
            $display("Diagonal 0 QR:");
            {state[31:0], state[191:160], state[351:320], state[511:480]} = 
                quarter_round(get_word(state, 0), get_word(state, 5),
                            get_word(state, 10), get_word(state, 15));
            
            // Diagonal 1: word1, word6, word11, word12
            $display("Diagonal 1 QR:");
            {state[63:32], state[223:192], state[383:352], state[415:384]} = 
                quarter_round(get_word(state, 1), get_word(state, 6),
                            get_word(state, 11), get_word(state, 12));
            
            // Diagonal 2: word2, word7, word8, word13
            $display("Diagonal 2 QR:");
            {state[95:64], state[255:224], state[287:256], state[447:416]} = 
                quarter_round(get_word(state, 2), get_word(state, 7),
                            get_word(state, 8), get_word(state, 13));
            
            // Diagonal 3: word3, word4, word9, word14
            $display("Diagonal 3 QR:");
            {state[127:96], state[159:128], state[319:288], state[479:448]} = 
                quarter_round(get_word(state, 3), get_word(state, 4),
                            get_word(state, 9), get_word(state, 14));
            
            // Check if all rounds done
            if(round_count == 4'd9) begin
                $display("DEBUG: All 20 rounds completed (10 column + 10 diagonal)");
                state_fsm <= S_DONE;
                round_count <= 4'd0;
            end else begin
                round_count <= round_count + 4'd1;
                state_fsm <= S_ROUND_COL;
            end
            
            $display("State after diagonal round %0d:", round_count);
            for(i = 0; i < 16; i = i + 4) begin
                $display("Words %0d-%0d: %h %h %h %h", 
                        i, i+3,
                        get_word(state, i),
                        get_word(state, i+1),
                        get_word(state, i+2),
                        get_word(state, i+3));
            end
        end
        
                S_DONE: begin
            $display("\n=== DEBUG FINAL ADDITION ===");
            $display("Final state after 20 rounds:");
            for(i = 0; i < 16; i = i + 4) begin
                $display("Words %0d-%0d: %h %h %h %h", 
                        i, i+3,
                        get_word(state, i),
                        get_word(state, i+1),
                        get_word(state, i+2),
                        get_word(state, i+3));
            end
            
            $display("\nInitial state (for addition):");
            for(i = 0; i < 16; i = i + 4) begin
                $display("Words %0d-%0d: %h %h %h %h", 
                        i, i+3,
                        get_word(init_state, i),
                        get_word(init_state, i+1),
                        get_word(init_state, i+2),
                        get_word(init_state, i+3));
            end
            
            // Final addition: state[i] + init_state[i] for i=0..15
            $display("\nPerforming final addition:");
            for(i = 0; i < 16; i = i + 1) begin
                // Get sum (LE word)
                sum_word = get_word(state, i) + get_word(init_state, i);
                
                // Store as LITTLE-ENDIAN word directly (no byte swapping needed)
                // Word 0 goes to key_stream[31:0], Word 1 to key_stream[63:32], etc.
                key_stream[i*32 +: 32] = sum_word;
                $display("Word%0d: %h + %h = %h (LE word)", 
                        i, 
                        get_word(state, i),
                        get_word(init_state, i),
                        sum_word);
            end
            // ================================================================
            
            $display("\nFinal keystream (16 LE words):");
            for(i = 0; i < 16; i = i + 4) begin
                $display("Words %0d-%0d: %h %h %h %h", 
                        i, i+3,
                        key_stream[i*32 +: 32],
                        key_stream[(i+1)*32 +: 32],
                        key_stream[(i+2)*32 +: 32],
                        key_stream[(i+3)*32 +: 32]);
            end
            
            done <= 1'b1;
            state_fsm <= S_IDLE;
            
                        $display("DEBUG: DONE asserted");
            $display("Keystream hex (byte stream): %h", {
                key_stream[7:0],   key_stream[15:8],  key_stream[23:16], key_stream[31:24],
                key_stream[39:32], key_stream[47:40], key_stream[55:48], key_stream[63:56],
                key_stream[71:64], key_stream[79:72], key_stream[87:80], key_stream[95:88],
                key_stream[103:96], key_stream[111:104], key_stream[119:112], key_stream[127:120],
                key_stream[135:128], key_stream[143:136], key_stream[151:144], key_stream[159:152],
                key_stream[167:160], key_stream[175:168], key_stream[183:176], key_stream[191:184],
                key_stream[199:192], key_stream[207:200], key_stream[215:208], key_stream[223:216],
                key_stream[231:224], key_stream[239:232], key_stream[247:240], key_stream[255:248],
                key_stream[263:256], key_stream[271:264], key_stream[279:272], key_stream[287:280],
                key_stream[295:288], key_stream[303:296], key_stream[311:304], key_stream[319:312],
                key_stream[327:320], key_stream[335:328], key_stream[343:336], key_stream[351:344],
                key_stream[359:352], key_stream[367:360], key_stream[375:368], key_stream[383:376],
                key_stream[391:384], key_stream[399:392], key_stream[407:400], key_stream[415:408],
                key_stream[423:416], key_stream[431:424], key_stream[439:432], key_stream[447:440],
                key_stream[455:448], key_stream[463:456], key_stream[471:464], key_stream[479:472],
                key_stream[487:480], key_stream[495:488], key_stream[503:496], key_stream[511:504]
            });
        end
        
        default: begin
            state_fsm <= S_IDLE;
        end
        endcase
    end
end

endmodule
