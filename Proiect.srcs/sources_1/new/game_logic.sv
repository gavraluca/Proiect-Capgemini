`timescale 1ns / 1ps

module game_logic #(
    parameter int BALL_SIZE = 96,
    parameter int H_VISIBLE = 1919,
    parameter int V_VISIBLE = 1079,
    parameter int THRESHOLD = 150,
    parameter int NR_BALLS  = 6
)(
    input  logic        clk,          // clk_148MHz
    input  logic        rst_n,
    input  logic        frame_tick,
    
    // Coordonate pixel curent (de la VGA Controller)
    input  logic [11:0] pixel_x,
    input  logic [11:0] pixel_y,
    
    // Date direct de la senzor
    input  logic [15:0] accel_x,
    input  logic [15:0] accel_y,
    
    // Input-uri utilizator
    input  logic [15:0] sw,
    input  logic        btnC,
    input  logic        btnU,
    input  logic        btnD,
    
    // Iesiri catre ecran / UI
    output logic [3:0]  out_r,
    output logic [3:0]  out_g,
    output logic [3:0]  out_b,
    output logic        is_drawing,
    output logic [10:0] current_bounce_loss,
    output logic [10:0] current_speed_limit  // <-- ADAUGAT PENTRU UI
);

    // ============================================================================
    // VALORI ABSOLUTE SENZOR
    // ============================================================================
    logic [15:0] abs_x;
    logic [15:0] abs_y;
    
    assign abs_x = accel_x[15] ? (~accel_x + 16'b1) : accel_x;
    assign abs_y = accel_y[15] ? (~accel_y + 16'b1) : accel_y;

    // ============================================================================
    // EDGE DETECTORS & DEBOUNCER (Filtru mecanic pentru a preveni erorile la startup)
    // Respecta regula de maxim 1-2 semnale per block
    // ============================================================================
    logic btnC_r1, btnC_r2, btnC_pulse;
    logic btnU_r1, btnU_r2, btnU_pulse;
    logic btnD_r1, btnD_r2, btnD_pulse;

    logic [19:0] debounce_counter = 0;
    logic btnC_stable = 0, btnU_stable = 0, btnD_stable = 0;

    // Timer-ul de filtrare a zgomotului (1 semnal)
    always_ff @(posedge clk) begin
        if (~rst_n) debounce_counter <= 0;
        else        debounce_counter <= debounce_counter + 1;
    end

    // STABILZING butoane C si U (2 semnale)
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            btnC_stable <= 0;
            btnU_stable <= 0;
        end else if (debounce_counter == 20'hFFFFF) begin 
            btnC_stable <= btnC;
            btnU_stable <= btnU;
        end
    end

    // STABLIZING BUTTON btnD (1 semnal)
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            btnD_stable <= 0;
        end else if (debounce_counter == 20'hFFFFF) begin 
            btnD_stable <= btnD;
        end
    end


    // Edge detector CENTER BUTTON - btnC
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            btnC_r1 <= 1'b0; btnC_r2 <= 1'b0;
        end else begin
            btnC_r1 <= btnC_stable; btnC_r2 <= btnC_r1;
        end
    end


    // Edge detector UP BUTTON btnU
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            btnU_r1 <= 1'b0; btnU_r2 <= 1'b0;
        end else begin
            btnU_r1 <= btnU_stable; btnU_r2 <= btnU_r1;
        end
    end

    // Edge detector DOWN BUTTON btnD
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            btnD_r1 <= 1'b0; btnD_r2 <= 1'b0;
        end else begin
            btnD_r1 <= btnD_stable; btnD_r2 <= btnD_r1;
        end
    end

    assign btnC_pulse = btnC_r1 & ~btnC_r2;
    assign btnU_pulse = btnU_r1 & ~btnU_r2;
    assign btnD_pulse = btnD_r1 & ~btnD_r2;

    // ============================================================================
    // PARAMETRI SI SEMNALE BILE
    // ============================================================================
    localparam int BALL_SIZE_DIV = (BALL_SIZE / 2);             
    localparam int radius_sq = BALL_SIZE_DIV * BALL_SIZE_DIV;   
    parameter int BALL_MOVEMENT = 2;

    logic signed [11:0] ball_x [0 : NR_BALLS - 1];
    logic signed [11:0] ball_y [0 : NR_BALLS - 1];

    logic signed [10:0] vel_x [0 : NR_BALLS - 1];
    logic signed [10:0] vel_y [0 : NR_BALLS - 1];
    
    logic signed [12:0] d_x [0 : NR_BALLS - 1];
    logic signed [12:0] d_y [0 : NR_BALLS - 1];
    logic [25:0]        d_x_sq [0 : NR_BALLS - 1];
    logic [25:0]        d_y_sq [0 : NR_BALLS - 1];

    logic draw_circle [0 : NR_BALLS - 1];                                
    logic [5:0] cooldown_x [0 : NR_BALLS - 1];
    logic [5:0] cooldown_y [0 : NR_BALLS - 1];

    logic [3:0] ball_r [0 : NR_BALLS - 1];
    logic [3:0] ball_g [0 : NR_BALLS - 1];
    logic [3:0] ball_b [0 : NR_BALLS - 1];
    logic signed [10:0] bounce_loss [0 : NR_BALLS - 1]; 
    logic signed [10:0] speed_limit [0 : NR_BALLS - 1]; 

    // SELECTIA BILEI: folosind exclusiv sw[14:12]
    logic [2:0] sel_ball;
    assign sel_ball = (sw[14:12] < NR_BALLS) ? sw[14:12] : 3'b000; 
    
    // Iesiri pentru afisarea pe ecran in meniu
    assign current_bounce_loss = bounce_loss[sel_ball];
    assign current_speed_limit = speed_limit[sel_ball];

    // ============================================================================
    // SETARI CULOARE, ELASTICITATE SI VITEZA (Max 1-2 semnale/block)
    // ============================================================================

    // RED + GREEN
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_r[i] <= 4'b1111;
                ball_g[i] <= 4'b1111;
            end
        end else begin
            if(btnC_pulse) begin
                ball_r[sel_ball] <= sw[3:0];
                ball_g[sel_ball] <= sw[7:4];
            end
        end
    end

    // BLUE 
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_b[i] <= 4'b1111;
            end
        end else begin
            if(btnC_pulse) begin
                ball_b[sel_ball] <= sw[11:8];
            end
        end
    end

    // BOUNCE LOSS
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                bounce_loss[i] <= 11'sd2;
            end
        end else begin
            if(btnU_pulse) begin
                if(!btnC_r1) begin // INCREASE ELASTICITY - ONLY UP
                    if(bounce_loss[sel_ball] > 11'sd0)
                        bounce_loss[sel_ball] <= bounce_loss[sel_ball] - 11'sd1;
                end
            end
            if(btnD_pulse) begin
                if(!btnC_r1) begin // DECREASE ELASTICITY - ONLY DOWN
                    if(bounce_loss[sel_ball] < 11'sd8)
                        bounce_loss[sel_ball] <= bounce_loss[sel_ball] + 11'sd1;
                end
            end
        end
    end

    // MAX SPEED
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                speed_limit[i] <= 11'sd10;
            end
        end else begin
            if(btnU_pulse) begin
                if(btnC_r1) begin // SHIFT + UP = INCREASE MAX SPEED
                    if(speed_limit[sel_ball] < 11'sd25)
                        speed_limit[sel_ball] <= speed_limit[sel_ball] + 11'sd1;
                end
            end
            if(btnD_pulse) begin
                if(btnC_r1) begin // SHIFT + DOWN = DECREASE MAX SPEED
                    if(speed_limit[sel_ball] > 11'sd2)
                        speed_limit[sel_ball] <= speed_limit[sel_ball] - 11'sd1;
                end
            end
        end
    end

    // ============================================================================
    // COMPUTING DISTANCES FOR DRAWING THE CIRCLE
    // ============================================================================
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) d_x[i] <= 13'b0;
        end else begin
            for(int i = 0; i < NR_BALLS; i++) d_x[i] <= $signed({1'b0 , pixel_x}) - ball_x[i];
        end
    end

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) d_y[i] <= 13'b0;
        end else begin
            for(int i = 0; i < NR_BALLS; i++) d_y[i] <= $signed({1'b0 , pixel_y}) - ball_y[i];
        end
    end

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) d_x_sq[i] <= 26'b0;
        end else begin
            for(int i = 0; i < NR_BALLS; i++) d_x_sq[i] <= d_x[i] * d_x[i];
        end
    end

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) d_y_sq[i] <= 26'b0;
        end else begin
            for(int i = 0; i < NR_BALLS; i++) d_y_sq[i] <= d_y[i] * d_y[i];
        end
    end

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) draw_circle[i] <= 1'b0;
        end else begin
            for(int i = 0; i < NR_BALLS; i++) draw_circle[i] <= (d_x_sq[i] + d_y_sq[i] <= radius_sq) ? 1'b1 : 1'b0;
        end
    end

    // ============================================================================
    // PHYSICS - AXA X (Logica secventiala cuplata X/Vel pentru sincronizare)
    // ============================================================================
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_x[i]  <= 100 + i * 120;
                vel_x[i]   <= 11'b0;
            end
        end else if(frame_tick)begin
            
            // PASUL 1: Miscare de baza si Senzor (Limitata de speed_limit individual)
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_x[i] <= ball_x[i] + vel_x[i];

                if(abs_x > THRESHOLD) begin
                    if(~accel_x[15]) begin
                        if(vel_x[i] < speed_limit[i]) vel_x[i] <= vel_x[i] + 1;
                    end else begin
                        if(vel_x[i] > -speed_limit[i]) vel_x[i] <= vel_x[i] - 1;
                    end
                end else if(abs_x <= THRESHOLD) begin
                    if(vel_x[i] > 0) vel_x[i] <= vel_x[i] - 1;
                    else if(vel_x[i] < 0) vel_x[i] <= vel_x[i] + 1;
                end
            end

            // PASUL 2: Coliziunea intre BILE 
            for(int i = 0; i < NR_BALLS; i++) begin
                for(int j = i+1; j < NR_BALLS; j++) begin
                    
                    // 1. Broad-phase
                    if(ball_y[i] - ball_y[j] < BALL_SIZE && ball_y[j] - ball_y[i] < BALL_SIZE &&
                       ball_x[i] - ball_x[j] < BALL_SIZE && ball_x[j] - ball_x[i] < BALL_SIZE)  begin
                        
                        // 2. Narrow-phase
                        if ( (24'(ball_x[i]) - 24'(ball_x[j])) * (24'(ball_x[i]) - 24'(ball_x[j])) + 
                             (24'(ball_y[i]) - 24'(ball_y[j])) * (24'(ball_y[i]) - 24'(ball_y[j])) <= BALL_SIZE * BALL_SIZE ) begin
                            
                            // Schimb de viteze
                            if ( (ball_x[i] <= ball_x[j] && vel_x[i] > vel_x[j]) || 
                                 (ball_x[i] >= ball_x[j] && vel_x[i] < vel_x[j]) ) begin
                                
                                vel_x[i] <= vel_x[j];
                                vel_x[j] <= vel_x[i];
                            end 

                            // WALL COLLISION DETECTION
                            if (ball_x[i] < ball_x[j]) begin
                                if (ball_x[i] <= BALL_SIZE_DIV + 4) begin
                                    ball_x[j] <= ball_x[j] + 4; 
                                    vel_x[i] <= 11'b0; 
                                    if(vel_x[j] > -bounce_loss[j])  vel_x[j] <= 11'b0;
                                    else                            vel_x[j] <= -vel_x[j] - bounce_loss[j];
                                end else if (ball_x[j] >= H_VISIBLE - BALL_SIZE_DIV - 4) begin
                                    ball_x[i] <= ball_x[i] - 4; 
                                    vel_x[j] <= 11'b0; 
                                    if(vel_x[i] < bounce_loss[i])   vel_x[i] <= 11'b0;
                                    else                            vel_x[i] <= -vel_x[i] + bounce_loss[i];
                                end else begin
                                    ball_x[i] <= ball_x[i] - 2;
                                    ball_x[j] <= ball_x[j] + 2;
                                end
                            end else begin
                                if (ball_x[j] <= BALL_SIZE_DIV + 4) begin
                                    ball_x[i] <= ball_x[i] + 4;
                                    vel_x[j] <= 11'b0;
                                    if(vel_x[i] > -bounce_loss[i])  vel_x[i] <= 11'b0;
                                    else                            vel_x[i] <= -vel_x[i] - bounce_loss[i];
                                end else if (ball_x[i] >= H_VISIBLE - BALL_SIZE_DIV - 4) begin
                                    ball_x[j] <= ball_x[j] - 4;
                                    vel_x[i] <= 11'b0;
                                    if(vel_x[j] < bounce_loss[j])   vel_x[j] <= 11'b0;
                                    else                            vel_x[j] <= -vel_x[j] + bounce_loss[j];
                                end else begin
                                    ball_x[i] <= ball_x[i] + 2;
                                    ball_x[j] <= ball_x[j] - 2;
                                end
                            end
                        end 
                    end
                end
            end

            // PASUL 3: Coliziunea cu PERETII
            for(int i = 0; i < NR_BALLS; i++) begin
                if(ball_x[i] <= BALL_SIZE_DIV && vel_x[i] < 0) begin
                    ball_x[i] <= BALL_SIZE_DIV;
                    if(vel_x[i] > -bounce_loss[i])  vel_x[i] <= 11'b0;
                    else                            vel_x[i] <= - vel_x[i] - bounce_loss[i];
                end else if (ball_x[i] >= H_VISIBLE - BALL_SIZE_DIV && vel_x[i] > 0) begin
                    ball_x[i] <= H_VISIBLE - BALL_SIZE_DIV;
                    if(vel_x[i] < bounce_loss[i])   vel_x[i] <= 11'b0;
                    else                            vel_x[i] <= - vel_x[i] + bounce_loss[i];
                end
            end
        end
    end

    // ============================================================================
    // PHYSICS - AXA Y (Logica secventiala cuplata Y/Vel pentru sincronizare)
    // ============================================================================
    always_ff @(posedge clk) begin
        if(~rst_n) begin
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_y[i]  <= 100 + i * 100;
                vel_y[i]   <= 11'b0;
            end
        end else if(frame_tick)begin
            
            // PASUL 1: Miscare de baza si Senzor (Limitata de speed_limit)
            for(int i = 0; i < NR_BALLS; i++) begin
                ball_y[i] <= ball_y[i] + vel_y[i];

                if(abs_y > THRESHOLD) begin
                    if(~accel_y[15]) begin
                        if(vel_y[i] < speed_limit[i]) vel_y[i] <= vel_y[i] + 1;
                    end else begin
                        if(vel_y[i] > -speed_limit[i]) vel_y[i] <= vel_y[i] - 1;
                    end
                end else if(abs_y <= THRESHOLD) begin
                    if(vel_y[i] > 0) vel_y[i] <= vel_y[i] - 1;
                    else if(vel_y[i] < 0) vel_y[i] <= vel_y[i] + 1;
                end
            end

            // STEP 2: BALL COLLISION
            for(int i = 0; i < NR_BALLS; i++) begin
                for(int j = i+1; j < NR_BALLS; j++) begin
                    
                    // 1. Broad-phase
                    if(ball_y[i] - ball_y[j] < BALL_SIZE && ball_y[j] - ball_y[i] < BALL_SIZE &&
                       ball_x[i] - ball_x[j] < BALL_SIZE && ball_x[j] - ball_x[i] < BALL_SIZE)  begin
                        
                        // 2. Narrow-phase 
                        if ( (24'(ball_x[i]) - 24'(ball_x[j])) * (24'(ball_x[i]) - 24'(ball_x[j])) + 
                             (24'(ball_y[i]) - 24'(ball_y[j])) * (24'(ball_y[i]) - 24'(ball_y[j])) <= BALL_SIZE * BALL_SIZE ) begin
                            
                            // Schimb de viteze
                            if ( (ball_y[i] <= ball_y[j] && vel_y[i] > vel_y[j]) || 
                                 (ball_y[i] >= ball_y[j] && vel_y[i] < vel_y[j]) ) begin    
                                
                                vel_y[i] <= vel_y[j];
                                vel_y[j] <= vel_y[i];
                            end 

                            // Overlap resolution
                            if (ball_y[i] < ball_y[j]) begin
                                if (ball_y[i] <= BALL_SIZE_DIV + 4) begin
                                    ball_y[j] <= ball_y[j] + 4; 
                                    vel_y[i] <= 11'b0; 
                                    if(vel_y[j] > -bounce_loss[j])  vel_y[j] <= 11'b0;
                                    else                            vel_y[j] <= -vel_y[j] - bounce_loss[j];
                                end else if (ball_y[j] >= V_VISIBLE - BALL_SIZE_DIV - 4) begin
                                    ball_y[i] <= ball_y[i] - 4; 
                                    vel_y[j] <= 11'b0;
                                    if(vel_y[i] < bounce_loss[i])   vel_y[i] <= 11'b0;
                                    else                            vel_y[i] <= -vel_y[i] + bounce_loss[i];
                                end else begin
                                    ball_y[i] <= ball_y[i] - 2;
                                    ball_y[j] <= ball_y[j] + 2;
                                end
                            end else begin
                                if (ball_y[j] <= BALL_SIZE_DIV + 4) begin
                                    ball_y[i] <= ball_y[i] + 4;
                                    vel_y[j] <= 11'b0;
                                    if(vel_y[i] > -bounce_loss[i])  vel_y[i] <= 11'b0;
                                    else                            vel_y[i] <= -vel_y[i] - bounce_loss[i];
                                end else if (ball_y[i] >= V_VISIBLE - BALL_SIZE_DIV - 4) begin
                                    ball_y[j] <= ball_y[j] - 4;
                                    vel_y[i] <= 11'b0;
                                    if(vel_y[j] < bounce_loss[j])   vel_y[j] <= 11'b0;
                                    else                            vel_y[j] <= -vel_y[j] + bounce_loss[j];
                                end else begin
                                    ball_y[i] <= ball_y[i] + 2;
                                    ball_y[j] <= ball_y[j] - 2;
                                end
                            end
                        end 
                    end
                end
            end

            // PASUL 3: Coliziunea cu PERETII
            for(int i = 0; i < NR_BALLS; i++) begin
                if(ball_y[i] <= BALL_SIZE_DIV && vel_y[i] < 0) begin
                    ball_y[i] <= BALL_SIZE_DIV;
                    if(vel_y[i] > -bounce_loss[i])  vel_y[i] <= 11'b0;
                    else                            vel_y[i] <= - vel_y[i] - bounce_loss[i]; 
                end else if (ball_y[i] >= V_VISIBLE - BALL_SIZE_DIV && vel_y[i] > 0) begin
                    ball_y[i] <= V_VISIBLE - BALL_SIZE_DIV;
                    if(vel_y[i] < bounce_loss[i])   vel_y[i] <= 11'b0;
                    else                            vel_y[i] <= - vel_y[i] + bounce_loss[i];
                end
            end
        end
    end

    // ============================================================================
    // OUTPUT COLOR
    // ============================================================================
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            is_drawing <= 1'b0;
            out_r <= 4'b0000;
            out_g <= 4'b0000;
            out_b <= 4'b0000;
        end else begin
            // 1. Definim culoarea de baza (Mov)
            is_drawing <= 1'b0;
            out_r <= 4'b1000;
            out_g <= 4'b0000;
            out_b <= 4'b1000;
            
            // 2. Daca pixelul apartine unei bile, suprascriem culoarea
            for(int i = 0; i < NR_BALLS; i++) begin
                if(draw_circle[i]) begin
                    is_drawing <= 1'b1;
                    out_r <= ball_r[i];
                    out_g <= ball_g[i];
                    out_b <= ball_b[i];
                end
            end
        
            // 3. Daca SW[15] e activ, desenam conturul peste bila selectata
            if (sw[15]) begin
                // Folosim distantele gata calculate in always_ff-ul de mai sus! 
                // Zero delay combinational!
                if ((d_x_sq[sel_ball] + d_y_sq[sel_ball]) <= (BALL_SIZE_DIV + 2)*(BALL_SIZE_DIV + 2) &&
                    (d_x_sq[sel_ball] + d_y_sq[sel_ball]) >  (BALL_SIZE_DIV * BALL_SIZE_DIV)) begin
                    
                    is_drawing <= 1'b1;
                    out_r <= 4'hF;   
                    out_g <= 4'h0;
                    out_b <= 4'h0;
                end
            end
        end
    end

endmodule