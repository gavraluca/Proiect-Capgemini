module spi_fsm(
    input logic     clk_in,             // 25MHz input clock
    input logic     spi_tick,           // Tick signal from the SPI clock divider
    input logic     rst_n_in,           // Active low reset

    output logic    cs_out,             // Active low chip select output
    output logic    mosi_out,           // Master Out Slave In output
    input logic     miso_in,            // Master In Slave Out input     
    output logic    sclk_out,           // SPI clock output

    input  logic       start_transfer, 
    output logic       spi_busy,       
    input  logic [7:0] tx_data_in,     
    output logic [7:0] rx_data_out
);

typedef enum logic [1:0]{
    IDLE =      2'b00,                  // FSM states
    START =     2'b01,                  // Start condition state
    TRANSFER =  2'b10,                  // Data transfer state
    STOP =      2'b11                   // Stop condition state
} states;

states state_current, state_next;

logic [7:0] tx_register, tx_next;           // Register to hold the data to be transmitted
logic [7:0] rx_register, rx_next;           // Register to hold the data received 
logic [3:0] bit_counter, bit_counter_next;  // Counter to track the number of bits transmitted/received
logic       sclk_register, sclk_next;       // Register to hold the SPI clock state

assign spi_busy     = (state_current != IDLE);  // Indicate if the SPI is busy
assign rx_data_out  = rx_register;              // Default value for received data
assign mosi_out     = tx_register[7];
assign sclk_out     = sclk_register;

// ============================================================================
// REGISTRII SECVENȚIALI – SEPARAȚI PENTRU A RESPECTA MAXIM 2 SEMNALE/ALWAYS_FF
// ============================================================================

// Bloc 1: stare + registrul de ceas SPI
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        state_current <= IDLE;
        sclk_register <= 1'b0;
    end else begin
        state_current <= state_next;
        sclk_register <= sclk_next;
    end
end

// Bloc 2: registrii de transmisie și recepție
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        tx_register <= 8'b0;
        rx_register <= 8'b0;
    end else begin
        tx_register <= tx_next;
        rx_register <= rx_next;
    end
end

// Bloc 3: contorul de biți
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        bit_counter <= 4'b0;
    end else begin
        bit_counter <= bit_counter_next;
    end
end

// ============================================================================
// LOGICA COMBINAȚIONALĂ (NESCHIMBATĂ)
// ============================================================================
always_comb begin
    state_next          = state_current;
    tx_next             = tx_register;
    rx_next             = rx_register;
    bit_counter_next    = bit_counter;
    sclk_next           = sclk_register;
    cs_out              = 1'b0;

    case(state_current)
        IDLE: begin
            cs_out = 1'b1;
            sclk_next = 1'b0;
            if(start_transfer)begin
                tx_next             = tx_data_in;
                bit_counter_next    = 1'b0;
                state_next          = START;
            end
        end
        START: begin
            if(spi_tick) begin
                sclk_next = 1'b0;
                state_next = TRANSFER;
            end
        end
        TRANSFER: begin
            if(spi_tick) begin
                if(sclk_register == 1'b0) begin
                    sclk_next = 1'b1;
                    rx_next = {rx_register[6:0] , miso_in};
                end
                else begin
                    sclk_next = 1'b0;
                    tx_next = {tx_register[6:0] , 1'b0};
                    bit_counter_next = bit_counter + 1'b1;

                    if(bit_counter_next == 4'b1000) begin
                        state_next = STOP;
                        sclk_next = 1'b0;
                    end
                end
            end
        end
        STOP: begin
            if(spi_tick) begin
                state_next = IDLE;
            end
        end
    endcase
end

endmodule