`timescale 10ns/10ns

// This is the memory module to store the sine wave samples. This memory will be read-only
module memory (
    input logic clk,         
    input logic [6:0] addr,  // Here we're setting up a 7-bit address that we can input to select which memory we want to read
    output logic [8:0] data  // This 9-bit output should provide the corresonding sine wave sample
);
    logic [8:0] mem[128];    // Now we declare our memory array (128 x 9-bit)
    
    initial begin
        $readmemh("sine.txt", mem); // Load sine values from external file for simulation 
    end

    assign data = mem[addr]; // This assigns memory data to output based on address
endmodule

// This FSM module was written to control how the sine wave samples are accessed. This is why we are able to produce a sine wave with less memory 
module fsm (
    input logic clk,       
    output logic [9:0] out  // 10-bit sine wave output
);
    // Here we define 4 quadrants of sine wave as differnt states 
    typedef enum logic [1:0] {
        SINE_1, // 0 to 90 degrees
        SINE_2, // 90 to 180 degrees
        SINE_3, // 180 to 270 degrees
        SINE_4  // 70 to 360 degrees
    } state_t;

    state_t current_state, next_state; // FSM current and next state
    logic [6:0] addr, next_addr;       // 7-bit address for memory lookup
    logic [6:0] counter, next_counter; // Counter to track sample positions
    logic [8:0] mem_out;               // 9-bit sine sample from memory

    // Starting FSM state and memory address at 0 and state 1
    initial begin
        current_state = SINE_1;
        addr = 0;
        counter = 0;
    end

    // Now we can used our memory module for the sine wave samples
    memory mem (
        .clk (clk),   
        .addr(addr),  // Address input for sine lookup
        .data(mem_out) // Memory output (9-bit sine sample)
    );

    // Here we say that On every rising edge of clk the FSM updates its state, the address moves forward or backward based on the state, the counter increments, and the output out is updated.
    always_ff @(posedge clk) begin
        current_state <= next_state;  // Update FSM state
        addr <= next_addr;            // Update memory address
        counter <= counter + 1;       // Increment counter
    end

    // No we can determine the next state, address, and counter behavior
    always_comb begin
        next_state = current_state;  // Default to staying in current state
        next_addr = addr;            // Default to keeping same address
        next_counter = counter + 1;  // Increment counter

        if (counter == 127) begin // If last sample of a quadrant is reached
            next_counter = 0; // Reset counter
            case (current_state)
                SINE_1: begin next_state = SINE_2; next_addr = 127; end // Move to SINE_2, reverse direction
                SINE_2: begin next_state = SINE_3; next_addr = 0; end   // Move to SINE_3, forward direction
                SINE_3: begin next_state = SINE_4; next_addr = 127; end // Move to SINE_4, reverse direction
                SINE_4: begin next_state = SINE_1; next_addr = 0; end   // Back to SINE_1, restart cycle
            endcase
        end else begin
            case (current_state)
                SINE_1, SINE_3: next_addr = addr + 1; // Increase address for SINE_1 & SINE_3
                SINE_2, SINE_4: next_addr = addr - 1; // Decrease address for SINE_2 & SINE_4
            endcase
        end
    end

    // And finally we output our sine wave using this defined quadrant symmetry
    always_ff @(posedge clk) begin
        case (current_state)
            SINE_1, SINE_2: out <= mem_out + 512; // First & second quadrant shift up to positive range)
            SINE_3, SINE_4: out <= 512 - mem_out; // Third & fourth quadrant invert for negative range
        endcase
    end
endmodule

// Our top-level module simply connects the outputs to sine wave generator
module top (
    input logic clk, 
    output logic _9b, _6a, _4a, _2a, _0a, _5a, _3b, _49a, _45a, _48b // 10-bit output
);
    logic [9:0] data; // Store sine wave output
    
    // Instantiate FSM
    fsm wavegen (
        .clk(clk),
        .out(data)
    );

    // Map 10-bit sine output to FPGA GPIO pins 
    assign {_48b, _45a, _49a, _3b, _5a, _0a, _2a, _4a, _6a, _9b} = data;
endmodule
