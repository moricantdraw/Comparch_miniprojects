`timescale 10ns / 10ns
`include "miniproject2.sv"

module miniproject2tb;

  parameter PWM_INTERVAL = 1200;  // 100 us

  logic clk = 0;
  logic RGB_R;
  logic RGB_G;
  logic RGB_B;

  top #(
      .PWM_INTERVAL(PWM_INTERVAL)
  ) u0 (
      .clk  (clk),
      .RGB_R(RGB_R),
      .RGB_G(RGB_G),
      .RGB_B(RGB_B)
  );

  initial begin
    $dumpfile("miniproject2.vcd");
    $dumpvars(0, miniproject2tb);

    // Optional: Display RGB values periodically
    forever begin
      #100000; // every 1 ms (since timescale is 10ns)
      $display("Time: %0t | RGB_R: %b | RGB_G: %b | RGB_B: %b", $time, RGB_R, RGB_G, RGB_B);
    end
  end

  // Clock generation: 12 MHz (period = 83.33ns -> #4 gives us 125 MHz, adjust if needed)
  always #4 clk = ~clk;  // 125 MHz clock (if you want 12 MHz, use #41)

  // Run the simulation for a fixed time then finish
  initial begin
    #100000000;  // Simulation runs for 1ms * 100,000 = 1 second (adjust as needed)
    $finish;
  end

endmodule
