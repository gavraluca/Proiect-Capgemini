`timescale 1ns / 1ps

// ============================================================================
// Module: vga_controller
// Description: Generates VGA synchronization signals (hsync, vsync) and 
//              provides the current X and Y pixel coordinates to the top module.
// ============================================================================
module vga_controller (
    input  logic       pix_clk,
    input  logic       rst_n,
    output logic       hsync,
    output logic       vsync,
    output logic       video_on,
    output logic [11:0] pixel_x,
    output logic [11:0] pixel_y
);

    // ============================================================================
    // PARAMETERS
    // ============================================================================
    
    parameter int H_TOTAL   = 2200; // H_TOTAL: Total horizontal pixels (visible area + front porch + sync pulse + back porch)
    parameter int V_TOTAL   = 1125; // V_TOTAL: Total vertical lines (visible area + front porch + sync pulse + back porch)
    parameter int H_VISIBLE = 1919; // H_VISIBLE: Horizontal visible pixels
    parameter int V_VISIBLE = 1079; // V_VISIBLE: Vertical visible lines


    // ============================================================================
    // INTERNAL SIGNALS
    // ============================================================================
    
    logic [11:0] H_Counter = 0; // Counters for tracking the current pixel position on the screen
    logic [11:0] V_Counter = 0;
    
    // ============================================================================
    // SEQUENTIAL LOGIC
    // ============================================================================
    always_ff @(posedge pix_clk) begin
        if (~rst_n) begin
            H_Counter <= 0;
            V_Counter <= 0;
        end else begin
            if (H_Counter < H_TOTAL - 1) begin
                H_Counter <= H_Counter + 1;
            end else begin
                H_Counter <= 0;
                
                if (V_Counter < V_TOTAL - 1) begin
                    V_Counter <= V_Counter + 1;
                end else begin
                    V_Counter <= 0;
                end
            end
        end
    end

    // ==================================================================================
    // COMBINATIONAL LOGIC  Generate active-low sync pulses based on standard VGA timing
    // ==================================================================================
    
    assign hsync    = rst_n ? ~((H_Counter >= 2008) && (H_Counter < 2052)) : 1'b1;
    assign vsync    = rst_n ? ~((V_Counter >= 1084) && (V_Counter < 1089)) : 1'b1;
    
 
    assign video_on = rst_n ?  (H_Counter < 1920  && V_Counter < 1080) : 1'b0;   // Determine if the current pixel is in the visible screen area
    

    assign pixel_x  = H_Counter;        // Output current coordinates for rendering
    assign pixel_y  = V_Counter;

endmodule