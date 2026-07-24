`timescale 1ns / 1ps

module ui_overlay #(
    parameter H_VISIBLE = 1920,
    parameter V_VISIBLE = 1080
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [11:0]  pixel_x,
    input  logic [11:0]  pixel_y,
    input  logic [15:0]  sw,
    input  logic         pause,
    input  logic [10:0]  bounce_val, 
    input  logic [15:0]  speed_val,  
    output logic [3:0]   ui_r,
    output logic [3:0]   ui_g,
    output logic [3:0]   ui_b,
    output logic         ui_draw
);

    // =============================
    // PARAMETRI PANOU + CULORI
    // =============================
    localparam PANEL_LEFT   = 12'd1520;
    localparam PANEL_RIGHT  = 12'd1919;
    localparam PANEL_TOP    = 12'd0;
    localparam PANEL_BOTTOM = 12'd1079;
    
    localparam PANEL_BG_R = 4'h2, PANEL_BG_G = 4'h0, PANEL_BG_B = 4'h2;
    localparam TEXT_R = 4'hF, TEXT_G = 4'hF, TEXT_B = 4'hF;
    localparam SW_BODY_R = 4'h6, SW_BODY_G = 4'h6, SW_BODY_B = 4'h6;
    localparam SW_ON_R = 4'h0, SW_ON_G = 4'hF, SW_ON_B = 4'h0;
    localparam SW_OFF_R = 4'hF, SW_OFF_G = 4'h0, SW_OFF_B = 4'h0;

    // Culori pentru grupele de switch-uri
    localparam RED_GROUP_R = 4'h9, RED_GROUP_G = 4'h2, RED_GROUP_B = 4'h2;
    localparam GREEN_GROUP_R = 4'h2, GREEN_GROUP_G = 4'h9, GREEN_GROUP_B = 4'h2;
    localparam BLUE_GROUP_R = 4'h2, BLUE_GROUP_G = 4'h2, BLUE_GROUP_B = 4'h9;
    localparam DEFAULT_GROUP_R = 4'h6, DEFAULT_GROUP_G = 4'h6, DEFAULT_GROUP_B = 4'h6;

    // =============================
    // FUNCTII GRAFICE
    // =============================
    function automatic logic in_rect(
        input [11:0] x, y,
        input [11:0] rx, ry, rw, rh
    );
        in_rect = (x >= rx) && (x < rx + rw) &&
                  (y >= ry) && (y < ry + rh);
    endfunction

    function automatic [63:0] get_char_packed(input byte char);
        case (char)
            "A": get_char_packed = 64'h3C66667E66666600;
            "B": get_char_packed = 64'h7C66667C66667C00;
            "C": get_char_packed = 64'h3C66606060663C00;
            "D": get_char_packed = 64'h7C66666666667C00;
            "E": get_char_packed = 64'h7E60607C60607E00;
            "G": get_char_packed = 64'h3C66606E66663C00;
            "H": get_char_packed = 64'h6666667E66666600;
            "I": get_char_packed = 64'h7E18181818187E00;
            "L": get_char_packed = 64'h6060606060607E00;
            "M": get_char_packed = 64'h63777F6B63636300;
            "N": get_char_packed = 64'h66767E7E6E666600;
            "P": get_char_packed = 64'h7C66667C60606000;
            "R": get_char_packed = 64'h7C66667C786C6600;
            "S": get_char_packed = 64'h3C66603C06663C00;
            "T": get_char_packed = 64'h7E18181818181800;
            "U": get_char_packed = 64'h6666666666663C00;
            "V": get_char_packed = 64'h666666663C180000;
            "Y": get_char_packed = 64'h6666663C18181800;
            "a": get_char_packed = 64'h0000780C7CCC7600;
            "b": get_char_packed = 64'h60607C6666667C00;
            "c": get_char_packed = 64'h00003C6660663C00;
            "d": get_char_packed = 64'h04043E6666663E00;
            "e": get_char_packed = 64'h00003C667E603C00;
            "g": get_char_packed = 64'h00003C66663E063C;
            "h": get_char_packed = 64'h60607C6666666600;
            "i": get_char_packed = 64'h1800381818183C00;
            "l": get_char_packed = 64'h3818181818183C00;
            "n": get_char_packed = 64'h00006C7666666600;
            "o": get_char_packed = 64'h00003C6666663C00;
            "p": get_char_packed = 64'h00007C66667C6060;
            "r": get_char_packed = 64'h00006C7660606000;
            "s": get_char_packed = 64'h00003C603C063C00;
            "t": get_char_packed = 64'h10307C3030341800;
            "u": get_char_packed = 64'h0000666666663C00;
            "v": get_char_packed = 64'h00006666663C1800;
            "y": get_char_packed = 64'h00006666663E063C;
            "0": get_char_packed = 64'h3C666E7E76663C00;
            "1": get_char_packed = 64'h1838181818187E00;
            "2": get_char_packed = 64'h3C66060C18307E00;
            "3": get_char_packed = 64'h3C66061C06663C00;
            "4": get_char_packed = 64'h1C3C6CCCFE0C0C00;
            "5": get_char_packed = 64'h7E607C0606663C00;
            "6": get_char_packed = 64'h1C30607C66663C00;
            "7": get_char_packed = 64'h7E660C1818181800;
            "8": get_char_packed = 64'h3C66663C66663C00;
            "9": get_char_packed = 64'h3C66663E060C3800;
            " ": get_char_packed = 64'h0000000000000000;
            "-": get_char_packed = 64'h0000007E00000000;
            ":": get_char_packed = 64'h0000001818001818;
            ",": get_char_packed = 64'h0000000000001830;
            ".": get_char_packed = 64'h0000000000181800;
            default: get_char_packed = 64'h0;
        endcase
    endfunction

    function automatic logic char_px(
        input byte char,
        input [11:0] char_x, char_y
    );
        logic [2:0] row;
        logic [7:0] row_bits;
        logic [63:0] char_data;
        char_data = get_char_packed(char);
        if (pixel_x < char_x || pixel_x >= char_x + 12'd8 ||
            pixel_y < char_y || pixel_y >= char_y + 12'd8)
            char_px = 1'b0;
        else begin
            row = 3'(pixel_y - char_y);
            row_bits = (char_data >> ((7 - row) * 8)) & 8'hFF;
            char_px = row_bits[7 - (pixel_x - char_x)];
        end
    endfunction

    // =============================
    // FUNCTIONS FOR CHARACTER EXTRACT
    // =============================
    function automatic byte get_title1_char(input int idx);
        case (idx)
             0: get_title1_char = "P";
             1: get_title1_char = "a";
             2: get_title1_char = "r";
             3: get_title1_char = "t";
             4: get_title1_char = "i";
             5: get_title1_char = "c";
             6: get_title1_char = "l";
             7: get_title1_char = "e";
             8: get_title1_char = " ";
             9: get_title1_char = "E";
            10: get_title1_char = "n";
            11: get_title1_char = "g";
            12: get_title1_char = "i";
            13: get_title1_char = "n";
            14: get_title1_char = "e";
            default: get_title1_char = " ";
        endcase
    endfunction

    function automatic byte get_title2_char(input int idx);
        case (idx)
             0: get_title2_char = "b";
             1: get_title2_char = "y";
             2: get_title2_char = " ";
             3: get_title2_char = "G";
             4: get_title2_char = "a";
             5: get_title2_char = "v";
             6: get_title2_char = "r";
             7: get_title2_char = "a";
             8: get_title2_char = " ";
             9: get_title2_char = "L";
            10: get_title2_char = "u";
            11: get_title2_char = "c";
            12: get_title2_char = "a";
            13: get_title2_char = " ";
            14: get_title2_char = "-";
            15: get_title2_char = " ";
            16: get_title2_char = "M";
            17: get_title2_char = "i";
            18: get_title2_char = "h";
            19: get_title2_char = "a";
            20: get_title2_char = "i";
            default: get_title2_char = " ";
        endcase
    endfunction

    function automatic byte get_pause_char(input int idx);
        case (idx)
            0: get_pause_char = "P";
            1: get_pause_char = "a";
            2: get_pause_char = "u";
            3: get_pause_char = "s";
            4: get_pause_char = "e";
            default: get_pause_char = " ";
        endcase
    endfunction

    // Funcție care întoarce culoarea de fundal a unui switch în funcție de grup
    function automatic void get_switch_colors(
        input int k,
        output logic [3:0] r, g, b
    );
        if (k < 4) begin          // Sw[3:0] -> RED
            r = RED_GROUP_R;
            g = RED_GROUP_G;
            b = RED_GROUP_B;
        end else if (k < 8) begin // Sw[7:4] -> GREEN
            r = GREEN_GROUP_R;
            g = GREEN_GROUP_G;
            b = GREEN_GROUP_B;
        end else if (k < 12) begin// Sw[11:8] -> BLUE
            r = BLUE_GROUP_R;
            g = BLUE_GROUP_G;
            b = BLUE_GROUP_B;
        end else begin            // Sw[15:12] -> DEFAULT
            r = DEFAULT_GROUP_R;
            g = DEFAULT_GROUP_G;
            b = DEFAULT_GROUP_B;
        end
    endfunction

    // VARIABLES FOR COMPUTING BALL SPEED
    logic [3:0] v_sute;
    logic [3:0] v_zeci;
    logic [3:0] v_unit;

    // =============================
    // MAIN DISPLAY LOGIC
    // =============================
    always_comb begin
        ui_draw = 1'b0;
        ui_r = PANEL_BG_R;
        ui_g = PANEL_BG_G;
        ui_b = PANEL_BG_B;

        // Panou fundal
        if (pixel_x >= PANEL_LEFT && pixel_x <= PANEL_RIGHT &&
            pixel_y >= PANEL_TOP  && pixel_y <= PANEL_BOTTOM) begin
            ui_draw = 1'b1;

            // first title
            for (int i = 0; i < 15; i++) begin
                if (char_px(get_title1_char(i), 12'd1540 + i*12'd8, 12'd20))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};
            end

            // 2nd title
            for (int i = 0; i < 21; i++) begin
                if (char_px(get_title2_char(i), 12'd1540 + i*12'd8, 12'd45))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};
            end

            // pause text
            if (in_rect(pixel_x, pixel_y, 12'd1560, 12'd90, 12'd100, 12'd40)) begin
                {ui_r, ui_g, ui_b} = {SW_BODY_R, SW_BODY_G, SW_BODY_B};
                if (pause) begin
                    if (in_rect(pixel_x, pixel_y, 12'd1565, 12'd100, 12'd20, 12'd20))
                        {ui_r, ui_g, ui_b} = {SW_ON_R, SW_ON_G, SW_ON_B};
                end else begin
                    if (in_rect(pixel_x, pixel_y, 12'd1635, 12'd100, 12'd20, 12'd20))
                        {ui_r, ui_g, ui_b} = {SW_OFF_R, SW_OFF_G, SW_OFF_B};
                end
            end

            // pause tag moved in the right side of the button 
            for (int i = 0; i < 5; i++) begin
                if (char_px(get_pause_char(i), 12'd1680 + i*12'd8, 12'd96))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};
            end

            // SW indicator 0 - 15
            for (int k = 0; k < 16; k++) begin
                automatic int col = k / 8;
                automatic int row = k % 8;
                automatic logic [11:0] sx = 12'd1560 + col * 12'd220;
                automatic logic [11:0] sy = 12'd200 + row * 12'd60;
                automatic logic [3:0] body_r, body_g, body_b;
                // Obține culoarea de grup pentru acest switch
                get_switch_colors(k, body_r, body_g, body_b);

                //NR TAG (ex: "01:")
                if (char_px(8'(48 + (k/10)), sx, sy))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};
                if (char_px(8'(48 + (k%10)), sx + 12'd8, sy))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};
                if (char_px(":", sx + 12'd16, sy))
                    {ui_r, ui_g, ui_b} = {TEXT_R, TEXT_G, TEXT_B};

                // RECTANGLE COLOR
                if (in_rect(pixel_x, pixel_y, sx+12'd30, sy+12'd5, 12'd80, 12'd30)) begin
                    {ui_r, ui_g, ui_b} = {body_r, body_g, body_b};   // COLORED CASE
                    if (sw[k]) begin
                        if (in_rect(pixel_x, pixel_y, sx+12'd35, sy+12'd10, 12'd15, 12'd20))
                            {ui_r, ui_g, ui_b} = {SW_ON_R, SW_ON_G, SW_ON_B};
                    end else begin
                        if (in_rect(pixel_x, pixel_y, sx+12'd95, sy+12'd10, 12'd15, 12'd20))
                            {ui_r, ui_g, ui_b} = {SW_OFF_R, SW_OFF_G, SW_OFF_B};
                    end
                end
            end

            // ----- Etichete grupuri switch-uri -----
            // RED deasupra sw[3:0] (x=1560, y=180)
            if (char_px("R", 12'd1560, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("E", 12'd1568, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("D", 12'd1576, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // GREEN sub RED (x=1560, y=420) pentru sw[7:4]
            if (char_px("G", 12'd1560, 12'd420)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("R", 12'd1568, 12'd420)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("E", 12'd1576, 12'd420)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("E", 12'd1584, 12'd420)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("N", 12'd1592, 12'd420)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // BLUE deasupra sw[11:8] (x=1780, y=180)
            if (char_px("B", 12'd1780, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("L", 12'd1788, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("U", 12'd1796, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("E", 12'd1804, 12'd180)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // PREVISUALIZE SELECTED COLOR
            if (in_rect(pixel_x, pixel_y, 12'd1560, 12'd680, 12'd120, 12'd120)) begin
                // Culoarea din switch-urile [11:8] (B), [7:4] (G), [3:0] (R)
                ui_r = sw[3:0];
                ui_g = sw[7:4];
                ui_b = sw[11:8];
            end

            // SELECTED COLOR TEXT
            if (char_px("S", 12'd1560, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("e", 12'd1568, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("l", 12'd1576, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("e", 12'd1584, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("c", 12'd1592, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("t", 12'd1600, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("e", 12'd1608, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("d", 12'd1616, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px(" ", 12'd1624, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("C", 12'd1632, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("o", 12'd1640, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("l", 12'd1648, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("o", 12'd1656, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("r", 12'd1664, 12'd820)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // ==========================================
            // BOUNCE LOSS DISPLAY
            // ==========================================
            if (char_px("E", 12'd1560, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("l", 12'd1568, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("a", 12'd1576, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("s", 12'd1584, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("t", 12'd1592, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px(":", 12'd1600, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            
            if (char_px(8'(48 + bounce_val[3:0]), 12'd1616, 12'd860)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // ==========================================
            // SPEED DISPLAY
            // ==========================================
            if (char_px("S", 12'd1560, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("p", 12'd1568, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("e", 12'd1576, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("e", 12'd1584, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px("d", 12'd1592, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px(":", 12'd1600, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};

            // digit computing - last digit of...
            v_sute = (speed_val / 100) % 10;
            v_zeci = (speed_val / 10) % 10;
            v_unit = (speed_val) % 10;

            if (char_px(8'(48 + v_sute), 12'd1616, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px(8'(48 + v_zeci), 12'd1624, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
            if (char_px(8'(48 + v_unit), 12'd1632, 12'd900)) {ui_r,ui_g,ui_b} = {TEXT_R,TEXT_G,TEXT_B};
        end
    end

endmodule