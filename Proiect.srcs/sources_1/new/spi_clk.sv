module spi_clk(
    input logic clk_in,                                      // 25MHz input clock
    input logic rst_n_in,                                    // Active low reset
    output logic clk_out                                     // 5MHz output clock
);

reg [2:0] counter;                                           // 3-bit counter to divide the clock by 5

//============================================================================
//  Sequential logic to increment the counter on each rising edge of clk_in
//============================================================================
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if(~rst_n_in) begin
        counter <= 3'b0;
    end
    else begin
        counter <= counter + 1'b1;
        if(counter == 3'b100) begin                          // Toggle clk_out every 5 cycles to achieve a 5MHz clock from a 25MHz input clock
            counter <= 3'b0;                                 // Reset counter to 0 after reaching 4
        end
    end
end

//==========================================================================
// always_comb block to generate clk_out based on the counter value
//==========================================================================

always_comb begin                                             
    if(counter == 3'b100) begin                              // When counter reaches 4 (5 cycles), toggle clk_out
        clk_out = 1'b1;
    end else begin
        clk_out = 1'b0;                                     // Otherwise, keep clk_out low
    end
end


endmodule

// |-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|
// |         |         |         |         |         |
