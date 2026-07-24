module adxl_read(
    input logic        clk_in,          // 25MHz input clock
    input logic        rst_n_in,        // Active low reset
    
    output logic       start_transfer,  // Signal to start SPI transfer 
    input  logic       spi_busy,        // Signal from SPI FSM indicating if SPI is busy
    output logic [7:0] tx_data_out,     // Data to be transmitted over SPI
    input  logic [7:0] rx_data_in,      // Data received from SPI
    output logic       adxl_cs_n,       // Manual control for CS
    
    output logic [15:0] x_out,          // X-axis acceleration data output  
    output logic [15:0] y_out,          // Y-axis acceleration data output
    output logic [15:0] z_out,          // Z-axis acceleration data output
    output logic        data_valid      // Signal indicating that the acceleration data is valid
);

typedef enum logic [4:0]{
    IDLE            = 5'd0,                 // Initial state of the FSM
    WAKE            = 5'd1,                 // Wake
    WAIT_WAKE       = 5'd2,                 // Wait Wake
    WAKE_ADDR       = 5'd3,                  
    WAIT_WAKE_ADDR  = 5'd4,
    WAKE_DATA       = 5'd5,         // ADAUGAT
    WAIT_WAKE_DATA  = 5'd6,
    CS_INACTIVE     = 5'd7,

    READ_CMD        = 5'd8,
    WAIT_READ_CMD   = 5'd9,
    READ_ADDR       = 5'd10,
    WAIT_READ_ADDR  = 5'd11,

    REQ_X_L         = 5'd12,                 // Request to read the low byte of the X-axis acceleration data
    WAIT_X_L        = 5'd13,                 // Wait for the low byte of the X-axis acceleration data to be received
    REQ_X_H         = 5'd14,                 // Request to read the high byte of the X-axis acceleration data
    WAIT_X_H        = 5'd15,                 // Wait for the high byte of the X-axis acceleration data to be received
    REQ_Y_L         = 5'd16,                 // Request to read the low byte of the Y-axis acceleration data
    WAIT_Y_L        = 5'd17,                 // Wait for the low byte of the Y-axis acceleration data to be received
    REQ_Y_H         = 5'd18,                 // Request to read the high byte of the Y-axis acceleration data
    WAIT_Y_H        = 5'd19,                 // Wait for the high byte of the Y-axis acceleration data to be received
    DONE            = 5'd20                  // Final state indicating that all data has been read and is valid

} states;

states state_current, state_next;
logic [7:0] X_L_REG, X_H_REG, Y_L_REG, Y_H_REG;


//=========================================================================================================
// Sequential logic to update the current state based on the next state and reset condition
//=========================================================================================================

always_ff @(posedge clk_in or negedge rst_n_in) begin
    if(~rst_n_in) begin
        state_current <= IDLE; 
    end else begin
        state_current <= state_next;
    end
end

//=========================================================================================================
// Combinational logic to determine the next state based on the current state and spi_busy signal for X
//=========================================================================================================

always_ff @ (posedge clk_in or negedge rst_n_in) begin
    if(~rst_n_in) begin
        X_L_REG <= 8'h00;
        X_H_REG <= 8'h00;
    end
    else begin
        if(state_current == WAIT_X_L && ~spi_busy) X_L_REG <= rx_data_in;
        if(state_current == WAIT_X_H && ~spi_busy) X_H_REG <= rx_data_in;
    end
end

//=========================================================================================================
// Combinational logic to determine the next state based on the current state and spi_busy signal for Y
//=========================================================================================================

always_ff @ (posedge clk_in or negedge rst_n_in) begin
    if(~rst_n_in) begin
        Y_L_REG <= 8'h00;
        Y_H_REG <= 8'h00;
    end
    else begin
        if(state_current == WAIT_Y_L && ~spi_busy) Y_L_REG <= rx_data_in;
        if(state_current == WAIT_Y_H && ~spi_busy) Y_H_REG <= rx_data_in;
    end
end

assign x_out = {X_H_REG, X_L_REG}; // Concatenate high and low bytes for X-axis acceleration data
assign y_out = {Y_H_REG, Y_L_REG}; // Concatenate high and low bytes for Y-axis acceleration data
assign z_out = 16'd0;

//========================================================================================================
// Combinational logic to determine the next state based on the current state and spi_busy signal
//========================================================================================================

always_comb begin
    state_next = state_current;
    case (state_current)
        IDLE:           if(~spi_busy) state_next = WAKE;
        WAKE:           state_next = WAIT_WAKE;
        WAIT_WAKE:      if(~spi_busy) state_next = WAKE_ADDR;
        WAKE_ADDR:      state_next = WAIT_WAKE_ADDR;
        WAIT_WAKE_ADDR: if(~spi_busy) state_next = WAKE_DATA;
        WAKE_DATA:      state_next = WAIT_WAKE_DATA;
        WAIT_WAKE_DATA: if(~spi_busy) state_next = CS_INACTIVE;
        CS_INACTIVE:    state_next = READ_CMD;

        READ_CMD:       state_next = WAIT_READ_CMD;
        WAIT_READ_CMD:  if(~spi_busy) state_next = READ_ADDR;
        READ_ADDR:      state_next = WAIT_READ_ADDR;
        WAIT_READ_ADDR: if(~spi_busy) state_next = REQ_X_L;

        REQ_X_L:        state_next = WAIT_X_L;
        WAIT_X_L:       if(~spi_busy) state_next = REQ_X_H;
        REQ_X_H:        state_next = WAIT_X_H;
        WAIT_X_H:       if(~spi_busy) state_next = REQ_Y_L;
        REQ_Y_L:        state_next = WAIT_Y_L;
        WAIT_Y_L:       if(~spi_busy) state_next = REQ_Y_H;
        REQ_Y_H:        state_next = WAIT_Y_H;
        WAIT_Y_H:       if(~spi_busy) state_next = DONE;
        DONE:           state_next = READ_CMD;                 // infinite loop
        default:        state_next = IDLE;

    endcase
end

//========================================================================================================
// Combinational logic to determine the transfer start signal and transmit data based on the current state
//========================================================================================================

always_comb begin
    start_transfer  = 1'b0;
    tx_data_out     = 8'h00;
    data_valid      = 1'b0; 
    adxl_cs_n       = 1'b0;


    case(state_current)

        IDLE: begin
            adxl_cs_n = 1'b1;                       // Sensor sleeping in STANDBY Mode
        end

        WAKE: begin
            start_transfer  = 1'b1;
            tx_data_out     = 8'h0A;
        end
        WAKE_ADDR: begin
            start_transfer  = 1'b1;
            tx_data_out     = 8'h2D;
        end
        WAKE_DATA: begin
            start_transfer  = 1'b1;
            tx_data_out     = 8'h02;
            
        end
        CS_INACTIVE: begin
            adxl_cs_n = 1'b1;
        end

        READ_CMD: begin
            start_transfer  = 1'b1;
            tx_data_out     = 8'h0B;
        end
        READ_ADDR: begin
            start_transfer  = 1'b1;
            tx_data_out     = 8'h0E;
        end


        REQ_X_L: begin
            start_transfer  = 1'b1;                 // Start SPI transfer to read X_L
            tx_data_out     = 8'h00;                // Start SPI transfer to read X_L
        end
        REQ_X_H: begin
            start_transfer  = 1'b1;                  // Start SPI transfer to read X_H
            tx_data_out     = 8'h00;                    // Start SPI transfer to read X_H
        end
        REQ_Y_L: begin
            start_transfer  = 1'b1;                  // Start SPI transfer to read Y_L
            tx_data_out     = 8'h00;                    // Start SPI transfer to read Y_L
        end
        REQ_Y_H: begin
            start_transfer  = 1'b1;                  // Start SPI transfer to read Y_H
            tx_data_out     = 8'h00;                    // Start SPI transfer to read Y_H
        end
        DONE: begin
            adxl_cs_n       = 1'b1;
            data_valid      = 1'b1;                      // Signal indicating that the acceleration data is valid
        end                
    endcase

end


endmodule


