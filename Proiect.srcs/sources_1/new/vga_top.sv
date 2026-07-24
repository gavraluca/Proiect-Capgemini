`timescale 1ns / 1ps

module vga_top (
    input  logic        clk_100MHz,
    input  logic [15:0] sw,
    input  logic        btnC, btnU, btnD, btnL, btnR,

    output logic        Hsync,
    output logic        Vsync,
    output logic [3:0]  vgaRed, vgaGreen, vgaBlue,

    output logic        spi_cs_n,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_sclk
);

    // ============================================================================
    // 1. PARAMETERS
    // ============================================================================
    parameter int BALL_SIZE = 96;
    parameter int H_VISIBLE = 1919;
    parameter int V_VISIBLE = 1079;
    parameter int THRESHOLD = 150;
    parameter int NR_BALLS  = 6;
    localparam GAME_RIGHT = 1520;

    // ============================================================================
    // 2. INTERNAL SIGNALS
    // ============================================================================
    logic clk_148MHz, clk_25MHz, rst_n;
    logic [11:0] pixel_x, pixel_y;
    logic video_on, frame_tick;
    logic spi_tick, start_transfer, spi_busy;
    logic [7:0] tx_data, rx_data;
    logic [15:0] accel_x, accel_y, accel_z;
    logic data_valid;

    // Pauză
    logic btnL_r1, btnL_r2;
    logic pause;
    logic frame_tick_gated;

    // Conexiuni catre UI
    logic [10:0] current_bounce_loss;
    logic [10:0] current_speed_limit; // <-- Viteza stabila preluata din joc

    // Reset sincronizat de pe btnR
    logic btnR_sync;
    always_ff @(posedge clk_148MHz) begin
        btnR_sync <= btnR;
        rst_n     <= ~btnR_sync;          // activ LOW (apăsat = reset)
    end

    // ============================================================================
    // 3. COMBINATIONAL LOGIC
    // ============================================================================
    assign frame_tick = (pixel_x == H_VISIBLE - 1 && pixel_y == V_VISIBLE - 1);
    assign frame_tick_gated = frame_tick & ~pause;

    // ============================================================================
    // 4. MODULE INSTANTIATIONS
    // ============================================================================
    clk_vga_wrapper clock_gen (
        .clk_100MHz(clk_100MHz), .clk_out1_0(clk_148MHz), .clk_out2_0(clk_25MHz), .reset_rtl_0(1'b1)
    );

    vga_controller vga_sync (
        .pix_clk(clk_148MHz), .rst_n(rst_n),
        .hsync(Hsync), .vsync(Vsync), .video_on(video_on),
        .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

    spi_clk inst_spi_clk (
        .clk_in(clk_25MHz), .rst_n_in(rst_n), .clk_out(spi_tick)
    );

    spi_fsm inst_spi_fsm (
        .clk_in(clk_25MHz), .spi_tick(spi_tick), .rst_n_in(rst_n),
        .cs_out(), .mosi_out(spi_mosi), .miso_in(spi_miso), .sclk_out(spi_sclk),
        .start_transfer(start_transfer), .spi_busy(spi_busy),
        .tx_data_in(tx_data), .rx_data_out(rx_data)
    );

    adxl_read inst_adxl_read (
        .clk_in(clk_25MHz), .rst_n_in(rst_n),
        .start_transfer(start_transfer), .spi_busy(spi_busy),
        .tx_data_out(tx_data), .rx_data_in(rx_data), .adxl_cs_n(spi_cs_n),
        .x_out(accel_x), .y_out(accel_y), .z_out(accel_z), .data_valid(data_valid)
    );

    // ============================================================================
    // 5. GAME LOGIC INTEGRATION
    // ============================================================================
    logic [3:0] ball_r, ball_g, ball_b;   
    logic is_ball;

    game_logic #(
        .BALL_SIZE (BALL_SIZE),
        .H_VISIBLE (GAME_RIGHT - 1),   
        .V_VISIBLE (V_VISIBLE),
        .THRESHOLD (THRESHOLD),
        .NR_BALLS  (NR_BALLS)
    ) physics_engine (
        .clk        (clk_148MHz),
        .rst_n      (rst_n),
        .frame_tick (frame_tick_gated),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .accel_x    (accel_x),
        .accel_y    (accel_y),
        .sw         (sw),
        .btnC       (btnC),
        .btnU       (btnU),
        .btnD       (btnD),
        .out_r      (ball_r),
        .out_g      (ball_g),
        .out_b      (ball_b),
        .is_drawing (is_ball),
        .current_bounce_loss(current_bounce_loss),
        .current_speed_limit(current_speed_limit) // <-- Iesirea catre UI
    );

    logic [3:0] ui_r, ui_g, ui_b;
    logic ui_draw;

    ui_overlay #(
        .H_VISIBLE(H_VISIBLE), .V_VISIBLE(V_VISIBLE)
    ) ui_inst (
        .clk(clk_148MHz), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .sw(sw), .pause(pause),
        .bounce_val(current_bounce_loss),
        .speed_val(16'(current_speed_limit)), // <-- Trimitem viteza maxima, zero-padded pe 16 biti
        .ui_r(ui_r), .ui_g(ui_g), .ui_b(ui_b), .ui_draw(ui_draw)
    );

    // ============================================================================
    // 6. BUTTON DEBOUNCE / EDGE DETECT FOR PAUSE
    // ============================================================================
    // Registrii de shift pentru btnL (2 semnale)
    always_ff @(posedge clk_148MHz) begin
        if (!rst_n) begin
            btnL_r1 <= 1'b0;
            btnL_r2 <= 1'b0;
        end else begin
            btnL_r1 <= btnL;
            btnL_r2 <= btnL_r1;
        end
    end

    // Logica de pauză (1 semnal)
    always_ff @(posedge clk_148MHz) begin
        if (!rst_n) begin
            pause <= 1'b0;
        end else begin
            if (btnL_r1 & ~btnL_r2)
                pause <= ~pause;
        end
    end

    // ============================================================================
    // 7. FINAL VGA OUTPUT (AFIȘAREA CULORILOR – EXCEPȚIA PERMISĂ)
    // ============================================================================
    always_ff @(posedge clk_148MHz) begin
        if (video_on) begin
            if (ui_draw) begin
                vgaRed   <= ui_r;
                vgaGreen <= ui_g;
                vgaBlue  <= ui_b;
            end else if (is_ball) begin
                vgaRed   <= ball_r;
                vgaGreen <= ball_g;
                vgaBlue  <= ball_b;
            end else begin
                vgaRed   <= 4'b1000;
                vgaGreen <= 4'b0000;
                vgaBlue  <= 4'b1000;
            end
        end else begin
            vgaRed   <= 4'b0000;
            vgaGreen <= 4'b0000;
            vgaBlue  <= 4'b0000;
        end
    end

endmodule