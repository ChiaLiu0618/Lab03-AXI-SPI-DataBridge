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
//   File Name   : pseudo_SD.v
//   Module Name : pseudo_SD
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module pseudo_SD (
    clk,
    MOSI,
    MISO
);

input clk;
input MOSI;
output reg MISO;

parameter SD_p_r = "../00_TESTBED/SD_init.dat";

reg [63:0] SD [0:65535];
initial $readmemh(SD_p_r, SD);  // read initial data from SD_init.dat

//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

real CYCLE = `CYCLE_TIME;

reg [5:0] command;
reg [31:0] addr_sd;
reg [7:0] SD_response;
reg [7:0] start_token;

reg [39:0] CRC7_input; 
reg [6:0] CRC7_receive;

reg [63:0] data_block;
reg [15:0] CRC16_CCITT_receive;

integer latency, i;

// SPEC SD-1: Command format should be correct, other command is not allowed.
// SPEC SD-2: The address should be within legal range.
// SPEC SD-3: CRC-7 check should be correct.
// SPEC SD-4: CRC-16-CCITT check should be correct.
// SPEC SD-5: Time between each transmission should be correct.

initial begin
    // reset all signals
    MISO = 1'b1; // reset to high
    command = 0;
    addr_sd = 0;
    CRC7_receive = 0;
    start_token = 8'hFE;
    SD_response = 8'b00000101;
    data_block = 0;
    CRC16_CCITT_receive = 0;
end

always @(negedge clk) begin
    if(MOSI === 1'b0) read_or_write_task;
end
//////////////////////////////////////////////////////////////////////
// {start bit = 1'b0,
// transmission bit = 1'b1,
// 6-bit command = 17(read) or 24(write),
// 32-bit addr_sd = 0 ~ 65535,
// 7-bit CRC7 = {start bit, transmisssion bit, command, addr_sd},
// end bit = 1'b1}

task read_or_write_task; begin
    #CYCLE;
    if(MOSI == 1'b0) begin  // transmission bit should be 1
        $display("*******************************************************************");
        $display("*                         SPEC SD-1 FAIL                          *");    
        $display("* Command format should be correct, other command is not allowed. *");
        $display("*******************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end
    #CYCLE

    for(i=0; i<6; i=i+1) begin
        command[5-i] = MOSI; // read command
        #CYCLE;
    end

    for(i=0; i<32; i=i+1) begin
        addr_sd[31-i] = MOSI;   // read address 
        #CYCLE;
    end

    if(addr_sd > 65535) begin
        $display("*****&********************************************************");
        $display("*                       SPEC SD-2 FAIL                       *");    
        $display("*    The address should be within legal range. (0 ~ 65535)   *");
        $display("**************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    for(i=0; i<7; i=i+1) begin
        CRC7_receive[6-i] = MOSI;  // read CRC7
        #CYCLE;
    end

    // CRC (Cyclic Redundancy Check)
    CRC7_input = {2'b01, command, addr_sd};
    if(CRC7_receive !== CRC7(CRC7_input)) begin
        $display("************************************************************");
        $display("*                      SPEC SD-3 FAIL                      *");    
        $display("*              CRC-7 check should be correct.              *");
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    if(MOSI === 1'b0) begin // end bit should be 1
        $display("*******************************************************************");
        $display("*                         SPEC SD-1 FAIL                          *");    
        $display("* Command format should be correct, other command is not allowed. *");
        $display("*******************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end
    #CYCLE;

    repeat(8 * $urandom_range(0, 8)) #CYCLE;    //wait 0 ~ 8 units, units = 8 cycles

    for(i=0; i<8; i=i+1) begin 
        MISO = 0;   // response from SD card: 8'b0
        #CYCLE;
    end
    MISO = 1; //return to idle

    if(command == 17) Read_task;
    else if(command == 24) Write_task;
    else begin
        $display("*******************************************************************");
        $display("*                         SPEC SD-1 FAIL                          *");    
        $display("* Command format should be correct, other command is not allowed. *");
        $display("*******************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end
end
endtask

//////////////////////////////////////////////////////////////////////
task Read_task; begin
    repeat(8 * $urandom_range(1, 32));  // wait 1 ~ 32 units

    for(i=0; i<8; i=i+1) begin
        MISO = start_token[7-i];    //8-bit start token
        #CYCLE;
    end

    data_block = SD[addr_sd];   // read from SD card
    for(i=0; i<64; i=i+1) begin
        MISO = data_block[63-i];    // print out data block
        #CYCLE;
    end

    CRC16_CCITT_receive = CRC16_CCITT(data_block);
    for(i=0; i<16; i=i+1) begin
        MISO = CRC16_CCITT_receive[15-i];
        #CYCLE;
    end

    MISO = 1;   // return to idle
end
endtask

task Write_task; begin
    latency = 0;
    while(MOSI !== 0) begin
        @(negedge clk);
        latency = latency + 1;
    end
    if((latency > (256+8)) || (latency<(8+8)) || (latency%8 !== 0)) begin
        $display("*****************************************************************");
        $display("*                         SPEC SD-5 FAIL                        *");    
        $display("*       Time between each transmission should be correct.       *");
        $display("*****************************************************************");
        if(latency > (256+8)) begin
        $display("*****************************************************************");
        $display("*                         SPEC SD-5 FAIL                        *");    
        $display("*                           over 256+8.                         *");
        $display("*****************************************************************");
        end
        if(latency<(8+8)) begin
        $display("*****************************************************************");
        $display("*                         SPEC SD-5 FAIL                        *");    
        $display("*                         lower than 8+8.                       *");
        $display("*****************************************************************");
        end
        if(latency%8 !== 0) begin
        $display("*****************************************************************");
        $display("*                         SPEC SD-5 FAIL                        *");    
        $display("*                       not multiples of 8.                     *");
        $display("*****************************************************************");
        end
        repeat(2) #CYCLE;
        $finish;
    end
    #CYCLE;

    for(i=0; i<64; i=i+1) begin
        data_block[63-i] = MOSI;    // copy message into data block;
        #CYCLE;
    end

    for(i=0; i<16; i=i+1) begin
        CRC16_CCITT_receive[15-i] = MOSI;
        #CYCLE;
    end

    if(CRC16_CCITT_receive !== CRC16_CCITT(data_block)) begin
        $display("****************************************************************");
        $display("*                        SPEC SD-4 FAIL                        *");    
        $display("*                  CRC-16-CCITT check should be correct.       *");
        $display("****************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    for(i=0; i<8; i=i+1) begin
        MISO = SD_response[7-i];
        #CYCLE;
    end

    MISO = 0;   // busy, keep low
    repeat(8 * $urandom_range(0, 32));   // wait 0 ~ 32 units

    @(negedge clk);
    SD[addr_sd] = data_block;   // write data into SD card

    MISO = 1;   // return to idle
end
endtask

task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                 Error message from pseudo_SD.v                        *");
end endtask

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