//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2023 ICLAB Fall Course
//   Lab03      : BRIDGE
//   Author     : Ting-Yu Chang
//                
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : BRIDGE_encrypted.v
//   Module Name : BRIDGE
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module BRIDGE(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    direction,
    addr_dram,
    addr_sd,
    // Output Signals
    out_valid,
    out_data,
    // DRAM Signals
    AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY,
	AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP,
    // SD Signals
    MISO,
    MOSI
);

// Input Signals
input clk, rst_n;
input in_valid;
input direction;
input [12:0] addr_dram;
input [15:0] addr_sd;

// Output Signals
output reg out_valid;
output reg [7:0] out_data;

// DRAM Signals
// write address channel
output reg [31:0] AW_ADDR;
output reg AW_VALID;
input AW_READY; // DRAM to Bridge
// write data channel
output reg W_VALID;
output reg [63:0] W_DATA;
input W_READY;
// write response channel
input B_VALID;
input [1:0] B_RESP;
output reg B_READY;
// read address channel
output reg [31:0] AR_ADDR;
output reg AR_VALID;
input AR_READY; // DRAM to Bridge
// read data channel
input [63:0] R_DATA;
input R_VALID;
input [1:0] R_RESP;
output reg R_READY;

// SD Signals
input MISO;
output reg MOSI;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter IDLE = 3'd0, SD_read = 3'd1, DRAM_read = 3'd2, DRAM_write = 3'd3, SD_write = 3'd4, OUTPUT = 3'd5;


//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [2:0] state, next_state;

reg direction_reg;
reg [12:0] addr_dram_reg;
reg [15:0] addr_sd_reg;

wire [63:0] SD_to_DRAM, DRAM_to_SD;
wire SD_stop_call, DRAM_stop_call; 

reg [3:0] OUTPUT_counter;

//==============================================//
//                  design                      //
//==============================================//
always @(*) begin
    case(state)
        IDLE: begin
            if(in_valid) next_state = direction ? SD_read : DRAM_read;
            else next_state = IDLE;
        end
        SD_read: next_state = SD_stop_call ? DRAM_write : SD_read;
        DRAM_read: next_state = DRAM_stop_call ? SD_write : DRAM_read;
        DRAM_write: next_state = DRAM_stop_call ? OUTPUT : DRAM_write;
        SD_write: next_state = SD_stop_call ? OUTPUT : SD_write;
        OUTPUT: next_state = (OUTPUT_counter == 4'd7) ? IDLE : OUTPUT;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= IDLE;
    else state <= next_state;
end

// IDLE state

    // save all inputs
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        direction_reg <= 0;
        addr_dram_reg <= 13'b0;
        addr_sd_reg <= 16'b0;
    end
    else if((state == IDLE) && in_valid) begin
        direction_reg <= direction;
        addr_dram_reg <= addr_dram;
        addr_sd_reg <= addr_sd;
    end
    else begin
        direction_reg <= direction_reg;
        addr_dram_reg <= addr_dram_reg;
        addr_sd_reg <= addr_sd_reg;
    end
end

// SD card
SD SD0(.clk(clk), .rst_n(rst_n), .direction_reg(direction_reg), .addr_sd_reg(addr_sd_reg), .BRIDGE_state(state), .MISO(MISO),
         .MOSI(MOSI), .Data_from_DRAM(DRAM_to_SD), .Data_to_DRAM(SD_to_DRAM), .SD_stop_call(SD_stop_call));

// DRAM
DRAM DRAM0(.clk(clk), .rst_n(rst_n), .direction_reg(direction_reg), .addr_dram_reg(addr_dram_reg), .BRIDGE_state(state), 
            .Data_from_SD(SD_to_DRAM), .Data_to_SD(DRAM_to_SD), .DRAM_stop_call(DRAM_stop_call),
            .AW_READY(AW_READY), .AW_ADDR(AW_ADDR), .AW_VALID(AW_VALID), 
            .W_READY(W_READY), .W_DATA(W_DATA), .W_VALID(W_VALID),
            .B_VALID(B_VALID), .B_RESP(B_RESP), .B_READY(B_READY), 
            .AR_READY(AR_READY), .AR_ADDR(AR_ADDR), .AR_VALID(AR_VALID), 
            .R_DATA(R_DATA), .R_RESP(R_RESP), .R_VALID(R_VALID), .R_READY(R_READY));

// OUTPUT
wire [63:0] transfer_data;

assign transfer_data = direction_reg ? SD_to_DRAM : DRAM_to_SD;
       
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out_data <= 0;
        OUTPUT_counter <= 0;
    end
    else if(state == OUTPUT) begin
        out_valid <= 1;
        OUTPUT_counter <= OUTPUT_counter + 1;
        case(OUTPUT_counter)
            4'd0: out_data <= transfer_data[63:56];
            4'd1: out_data <= transfer_data[55:48];
            4'd2: out_data <= transfer_data[47:40];
            4'd3: out_data <= transfer_data[39:32];
            4'd4: out_data <= transfer_data[31:24];
            4'd5: out_data <= transfer_data[23:16];
            4'd6: out_data <= transfer_data[15:8];
            4'd7: out_data <= transfer_data[7:0];
            default: out_data <= 0;
        endcase
    end
    else begin
        out_valid <= 0;
        out_data <= 0;
        OUTPUT_counter <= 0;
    end
end 

endmodule

module SD(input clk, rst_n, input direction_reg, input [15:0] addr_sd_reg, input [2:0] BRIDGE_state, input MISO,
         output reg MOSI, input [63:0] Data_from_DRAM, output reg [63:0] Data_to_DRAM, output SD_stop_call);

reg [3:0] SD_response_counter;
reg [5:0] command_SD_counter;
reg [6:0] data_from_host_counter;

// FINITE STATE MACHINE
parameter SD_read = 3'd1, SD_write = 3'd4;
parameter idle =  3'd0, command = 3'd1, response = 3'd2, data_from_SD = 3'd3, data_from_host = 3'd4, data_response = 3'd5;
reg[2:0] state, next_state;

always @(*) begin
    case(state)
        idle: next_state = ((BRIDGE_state == SD_read) || (BRIDGE_state == SD_write)) ? command : idle;
        command: next_state = (command_SD_counter == 6'd48) ? response : command;
        response: begin
            if(SD_response_counter == 4'd8) next_state = direction_reg ? data_from_SD : data_from_host;
            else next_state = response;
        end
        data_from_SD: next_state = SD_stop_call ? idle : data_from_SD;
        data_from_host: next_state = (data_from_host_counter == 7'd88) ? data_response : data_from_host;
        data_response: next_state = SD_stop_call ? idle : data_response;
        default: next_state = idle;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= idle;
    else state <= next_state;
end

    // command from host
reg [47:0] command_SD;

always @(*) begin
    if(direction_reg) command_SD = {2'b01, 6'd17, 16'b0, addr_sd_reg, CRC7({2'b01, 6'd17, 16'b0, addr_sd_reg}), 1'b1};    // read
    else command_SD = {2'b01, 6'd24, 16'b0, addr_sd_reg, CRC7({2'b01, 6'd24, 16'b0, addr_sd_reg}), 1'b1}; // write
end

    // Response from SD card
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) SD_response_counter <= 0;
    else if((state == response) && (MISO == 0)) SD_response_counter <= SD_response_counter + 1;
    else SD_response_counter <= 0;
end

    // Read operation: Data from SD card
reg [7:0] start_token_from_SD;
reg [6:0] data_block_counter;
reg [79:0] data_block;

        // start_token
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) start_token_from_SD <= 0;
    else if((state == data_from_SD) && (start_token_from_SD == 8'b01111110)) start_token_from_SD <= start_token_from_SD;
    else if(state == data_from_SD) start_token_from_SD <= (start_token_from_SD << 1) + MISO;
    else start_token_from_SD <= 0;
end
        // data block
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_block <= 0;
        data_block_counter <= 0;
    end
    else if((state == data_from_SD) && (start_token_from_SD == 8'b01111110)) begin
        data_block <= (data_block << 1) + MISO;
        data_block_counter <= data_block_counter + 1;
    end
    else if((state == data_from_SD)) begin
        data_block <= 0;
        data_block_counter <= 0;
    end
    else begin
        data_block <= data_block;
        data_block_counter <= data_block_counter;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) Data_to_DRAM <= 0;
    else if((state == data_from_SD) && (data_block_counter == 7'd80)) Data_to_DRAM <= data_block[79:16];
    else Data_to_DRAM <= Data_to_DRAM;
end

    // Write operation: Data from host
reg [87:0] data_to_MOSI;

always @(*) begin
    data_to_MOSI = {8'hFE, Data_from_DRAM, CRC16_CCITT(Data_from_DRAM)};
end

    // Write operation: Data response from SD card

        // Data response
reg [7:0] data_response_from_SD;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) data_response_from_SD <= 0;
    else if((state == data_response) && (data_response_from_SD == 8'b00000101)) data_response_from_SD <= data_response_from_SD;
    else if(state == data_response) data_response_from_SD <= (data_response_from_SD << 1) + MISO;
    else data_response_from_SD <= 0;
end

        // Busy
wire Busy_end;

assign Busy_end = (state == data_response) && (data_response_from_SD == 8'b00000101) && MISO;

    // MOSI output
reg [3:0] latency_counter;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        MOSI <= 1;
        command_SD_counter <= 0;
        data_from_host_counter <= 0;
        latency_counter <= 0;
    end
    else if((state == command) && MISO) begin
        MOSI <= command_SD[47 - command_SD_counter];
        command_SD_counter <= command_SD_counter + 1;
        data_from_host_counter <= 0;
        latency_counter <= 0;
    end    
    else if((state == data_from_host) && MISO && (latency_counter == 6)) begin
        MOSI <= data_to_MOSI[87 - data_from_host_counter];
        command_SD_counter <= 0;
        data_from_host_counter <= data_from_host_counter + 1;
        latency_counter <= latency_counter;
    end
    else if((state == data_from_host) && MISO) begin
        MOSI <= 1;
        command_SD_counter <= 0;
        data_from_host_counter <= 0;
        latency_counter <= latency_counter + 1;
    end
    else begin
        MOSI <= 1;
        command_SD_counter <= 0;
        data_from_host_counter <= 0;
        latency_counter <= 0;
    end
end

    // stop call
assign SD_stop_call = (data_block_counter == 7'd80) || Busy_end;

////// CRC
function automatic [6:0] CRC7;  // Return 7-bit result
    input [39:0] data;  // 40-bit data input
    reg [6:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 7'h9;  // x^7 + x^3 + 1

    begin
        crc = 7'd0;
        for (i = 0; i < 40; i = i + 1) begin
            data_in = data[39-i];
            data_out = crc[6];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC7 = crc;
    end
endfunction

function automatic [15:0] CRC16_CCITT;  // Return 16-bit result
    input [63:0] data; // 64-bit data input
    reg [15:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 16'h1021;    // x^16 + x^12 + x^5 + 1

    begin
        crc = 16'd0;
        for (i = 0; i < 64; i = i + 1) begin
            data_in = data[63-i];
            data_out = crc[15];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC16_CCITT = crc;
    end
endfunction
endmodule

module DRAM(input clk, rst_n, input direction_reg, input [12:0] addr_dram_reg, input [2:0] BRIDGE_state, 
            input [63:0] Data_from_SD, output reg [63:0] Data_to_SD, output DRAM_stop_call,
            input AW_READY, output reg [31:0] AW_ADDR, output reg AW_VALID, 
            input W_READY, output reg [63:0] W_DATA, output reg W_VALID,
            input B_VALID, input [1:0] B_RESP, output reg B_READY, 
            input AR_READY, output reg [31:0] AR_ADDR, output reg AR_VALID, 
            input [63:0] R_DATA, input [1:0] R_RESP, input R_VALID, output reg R_READY);

// FINITE STATE MACHINE
parameter DRAM_read = 3'd2, DRAM_write = 3'd3;
parameter idle = 3'd0, read_address = 3'd1, read_data = 3'd2, write_address = 3'd3, write_data = 3'd4, write_response = 3'd5;
reg [2:0] state, next_state;

always @(*) begin
    case(state)
        idle: begin
            if(BRIDGE_state == DRAM_read) next_state = read_address;
            else if(BRIDGE_state == DRAM_write) next_state = write_address;
            else next_state = idle;
        end
        write_address: next_state = (AW_VALID && AW_READY) ? write_data : write_address;
        write_data: next_state = (W_VALID && W_READY) ? write_response : write_data;
        write_response: next_state = DRAM_stop_call ? idle : write_response;
        read_address: next_state = (AR_VALID && AR_READY) ? read_data : read_address;
        read_data: next_state = DRAM_stop_call ? idle : read_data;
        default: next_state = idle;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= idle;
    else state <= next_state;
end

    // Write address channel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        AW_VALID <= 0;
        AW_ADDR <= 32'b0;
    end
    else if(state == write_address) begin
        AW_VALID <= 1;
        AW_ADDR <= {19'b0, addr_dram_reg};
    end
    else begin
        AW_VALID <= 0;
        AW_ADDR <= 32'b0;
    end
end

    // Write data channel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        W_VALID <= 0;
        W_DATA <= 64'b0;
    end
    else if(state == write_data) begin
        W_VALID <= 1;
        W_DATA <= Data_from_SD;
    end
    else begin
        W_VALID <= 0;
        W_DATA <= 64'b0;
    end
end

    // Write response channel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) B_READY <= 0;
    else if((state == write_data) || (state == write_response)) B_READY <= 1;
    else B_READY <= 0;
end

    // Read address channel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        AR_VALID <= 0;
        AR_ADDR <= 32'b0;
    end
    else if(state == read_address) begin
        AR_VALID <= 1;
        AR_ADDR <= {19'b0, addr_dram_reg};
    end
    else begin
        AR_VALID <= 0;
        AR_ADDR <= 32'b0;
    end
end

    // Read data channel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) R_READY <= 0;
    else if(state == read_data) R_READY <= 1;
    else R_READY <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) Data_to_SD <= 0;
    else if((state == read_data) && R_VALID && (R_RESP == 2'b00)) Data_to_SD <= R_DATA;
    else Data_to_SD <= Data_to_SD;
end

    // Stop call
assign DRAM_stop_call = (B_READY && B_VALID && (B_RESP == 2'b00)) || (R_READY && R_VALID && (R_RESP == 2'b00));

endmodule