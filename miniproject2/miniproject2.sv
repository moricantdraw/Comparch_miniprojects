
module top #(
    parameter PWM_INTERVAL = 1200  // Number of clock cycles for a full PWM period 
) (
    input logic clk, 
    // Output to control LEDs         
    output logic RGB_R,       
    output logic RGB_G,      
    output logic RGB_B        
);

    // Defined inside signals for individual colors' control lines
    logic red, green, blue;

    // Red color cycle starts at a specific state to stagger its phase
    color_cycle #(
        .PWM_INTERVAL(PWM_INTERVAL),
        .INITIAL_STATE(2'b01),         // Starts in HOLD HIGH state
        .INITIAL_STEP_COUNT(83),       // Roughly halfway through the fade step count
        .INITIAL_DUTY_CYCLE(1)         // Full duty cycle
    ) red_light (
        .clk(clk),
        .CLR(red)
    );

    //  Staggered start for green 
    color_cycle #(
        .PWM_INTERVAL(PWM_INTERVAL)
    ) green_light (
        .clk(clk),
        .CLR(green)
    );

    // Staggered start for green
    color_cycle #(
        .PWM_INTERVAL(PWM_INTERVAL),
        .INITIAL_STATE(2'b11)          // Starts in HOLD LOW state
    ) blue_light (
        .clk(clk),
        .CLR(blue)
    );

    // Inverts internal color signals 
    assign RGB_R = ~red;
    assign RGB_G = ~green;
    assign RGB_B = ~blue;

endmodule



// This is the color cycle module. It wraps fade and PWM control to keep everything cycling 
module color_cycle #(
    parameter PWM_INTERVAL = 1200,
    parameter INITIAL_STATE = 2'b00,      // Initial state
    parameter INITIAL_STEP_COUNT = 0,     // Initial step count
    parameter INITIAL_DUTY_CYCLE = 0      // Initial duty cycle
) (
    input logic clk,      
    output logic CLR      // Color output signal 
);

    // Duty cycle value from fade logic
    logic [$clog2(PWM_INTERVAL)-1:0] duty_cycle;
    logic pwm_out;

    // Smoothly changing duty cycle from fade generator 
    fade #(
        .PWM_INTERVAL(PWM_INTERVAL),
        .INITIAL_STATE(INITIAL_STATE),
        .INITIAL_STEP_COUNT(INITIAL_STEP_COUNT),
        .INITIAL_DUTY_CYCLE(INITIAL_DUTY_CYCLE)
    ) fade_inst (
        .clk(clk),
        .cycle_value(duty_cycle)
    );

    // PWM signal from PWM generator referncing duty cycle
    pwm #(
        .PWM_INTERVAL(PWM_INTERVAL)
    ) pwm_inst (
        .clk(clk),
        .pwm_value(duty_cycle),
        .pwm_out(pwm_out)
    );

    // Invert PWM output 
    assign CLR = ~pwm_out;

endmodule



// This is the fade module. It's (hopefully) going to smoothly increases and decreases duty cycle

module fade #(
    parameter STEP_INTERVAL = 12000,             // Clock cycles per fade step 
    parameter STEP_MAX = 166,                    // Steps in a full fade 
    parameter HOLD_MAX = 332,                    // Steps to hold at max/min brightness
    parameter PWM_INTERVAL = 1200,               // PWM period (must match PWM module)
    parameter STEP_SIZE = PWM_INTERVAL / STEP_MAX, // Amount to change per step
    parameter INITIAL_STATE = 2'b00,             // Initial state of FSM
    parameter INITIAL_STEP_COUNT = 0,            // Initial step count
    parameter INITIAL_DUTY_CYCLE = 0             // Starting duty cycle
)(
    input logic clk,                              // System clock input
    output logic [$clog2(PWM_INTERVAL)-1:0] cycle_value  // Output duty cycle value
);

    // Define FSM states
    typedef enum logic [1:0] {
        PWM_INC = 2'b00,        // Increasing brightness
        PWM_HOLD_HIGH = 2'b01,  // Holding at full brightness
        PWM_DEC = 2'b10,        // Decreasing brightness
        PWM_HOLD_LOW = 2'b11    // Holding at zero brightness
    } state_t;

    state_t state = state_t'(INITIAL_STATE);  // Initialize FSM state

    // Counter to track time between steps
    logic [$clog2(STEP_INTERVAL)-1:0] interval_counter = 0;
    // Counter to track the number of steps taken in the current state
    logic [$clog2(HOLD_MAX)-1:0] step_counter = INITIAL_STEP_COUNT;
    
    // Set initial duty cycle based on parameters
    initial cycle_value = INITIAL_DUTY_CYCLE * STEP_SIZE * STEP_MAX;

    // Main fade logic driven by clock
    always_ff @(posedge clk) begin
        if (interval_counter == STEP_INTERVAL - 1) begin
            interval_counter <= 0;  // Reset the interval counter
            
            // Update duty cycle based on state
            case (state)
                PWM_INC: 
                    cycle_value <= (cycle_value + STEP_SIZE < PWM_INTERVAL) 
                                   ? cycle_value + STEP_SIZE 
                                   : PWM_INTERVAL;
                PWM_DEC: 
                    cycle_value <= (cycle_value > STEP_SIZE) 
                                   ? cycle_value - STEP_SIZE 
                                   : 0;
            endcase

            // Increment step counter
            step_counter <= step_counter + 1;

            // State transitions based on step counts
            if ((state == PWM_INC || state == PWM_DEC) && step_counter == STEP_MAX) begin
                state <= state_t'((state == PWM_INC) ? PWM_HOLD_HIGH : PWM_HOLD_LOW);
                step_counter <= 0;
            end else if ((state == PWM_HOLD_HIGH || state == PWM_HOLD_LOW) && step_counter == HOLD_MAX) begin
                state <= state_t'((state == PWM_HOLD_HIGH) ? PWM_DEC : PWM_INC);
                step_counter <= 0;
            end

        end else begin
            interval_counter <= interval_counter + 1;  // Wait for the next step interval
        end
    end

endmodule


// This is the PWM module which generates PWM signal based on duty cycle
module pwm #(
    parameter PWM_INTERVAL = 1200  // Number of clock cycles in one PWM period
)(
    input logic clk,  // System clock input
    input logic [$clog2(PWM_INTERVAL)-1:0] pwm_value,  // Current duty cycle value
    output logic pwm_out  // PWM output signal
);

    // Counter that tracks PWM period
    logic [$clog2(PWM_INTERVAL)-1:0] pwm_counter = 0;

    always_ff @(posedge clk) begin
        pwm_counter <= (pwm_counter == PWM_INTERVAL - 1) 
                       ? 0 
                       : pwm_counter + 1;
    end

    // PWM output is high when counter is less than duty cycle
    assign pwm_out = (pwm_counter < pwm_value);

endmodule
