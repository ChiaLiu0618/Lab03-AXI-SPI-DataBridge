`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

`include "../00_TESTBED/pseudo_DRAM.v"
`include "../00_TESTBED/pseudo_SD.v"

module PATTERN(
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

/* Input for design */
output reg        clk, rst_n;
output reg        in_valid;
output reg        direction;
output reg [12:0] addr_dram;
output reg [15:0] addr_sd;

/* Output for pattern */
input        out_valid;
input  [7:0] out_data; 

// DRAM Signals
// write address channel
input [31:0] AW_ADDR;
input AW_VALID;
output AW_READY;
// write data channel
input W_VALID;
input [63:0] W_DATA;
output W_READY;
// write response channel
output B_VALID;
output [1:0] B_RESP;
input B_READY;

// read address channel
input [31:0] AR_ADDR;
input AR_VALID;
output AR_READY;
// read data channel
output [63:0] R_DATA;
output R_VALID;
output [1:0] R_RESP;
input R_READY;

// SD Signals
output MISO;
input MOSI;

// parameter and variable
real CYCLE = `CYCLE_TIME;
integer pat_read;
integer PAT_NUM;
integer total_latency, latency;
integer i_pat;
integer fscanf_int;

// execute once
initial begin
    pat_read = $fopen("../00_TESTBED/Input.txt", "r");
    reset_signal_task;

    i_pat = 0;
    total_latency = 0;
    fscanf_int = $fscanf(pat_read, "%d", PAT_NUM);
    for (i_pat = 1; i_pat <= PAT_NUM; i_pat = i_pat + 1) begin
        input_task;
        wait_out_valid_task;
        check_ans_task;
        total_latency = total_latency + latency;
        $display("PASS PATTERN NO.%4d", i_pat);
    end
    $fclose(pat_read);

    $writememh("../00_TESTBED/DRAM_final.dat", u_DRAM.DRAM);
    $writememh("../00_TESTBED/SD_final.dat", u_SD.SD);
    YOU_PASS_task;
end

//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

// SPEC MAIN-1: All output signals should be reset after the reset signal is asserted.
// SPEC MAIN-2: The out_data should be reset when your out_valid is low.
// SPEC MAIN-3: The execution latency is limited in 10000 cycles.
// SPEC MAIN-4: The out_valid and out_data must be asserted in 8 cycles.
// SPEC MAIN-5: The out_data should be correct when out_valid is high.
// SPEC MAIN-6: The data in the DRAM and SD card should be correct when out_valid is high.

// generate clock signal
always #(CYCLE/2.0) clk = ~clk;

task reset_signal_task; begin
    // reset all signals
    rst_n = 1'b1;
    in_valid = 1'b0;
    direction = 1'bx;
    addr_dram = 1'bx;
    addr_sd = 1'bx;

    force clk = 0;
    #CYCLE; rst_n = 0;  // press reset after one cycle
    #CYCLE; rst_n = 1;  // let go reset after one cycle

    // SPEC MAIN-1: All output signals should be reset after the reset signal is asserted.
    if((out_valid !== 0) || (out_data !== 0) || (AW_ADDR !== 0) || (AW_VALID !== 0) || (W_VALID !== 0) || (W_DATA !== 0) 
        || (B_READY !== 0) || (AR_ADDR !== 0) || (AR_VALID !== 0) || (R_READY !== 0) || (MOSI !== 1)) begin
        $display("**************************************************************************");
        $display("*                            SPEC MAIN-1 FAIL                            *");    
        $display("* All output signals should be reset after the reset signal is asserted. *");
        $display("**************************************************************************");
        repeat(2) #CYCLE;   // repeat "wait one cycle" twice: wait 2 cycles 
        $finish;
    end
	#CYCLE; release clk;
end
endtask

// SPEC MAIN-2: The out_data should be reset when your out_valid is low.
always @(negedge clk) begin     // check at every negedge clock
    if((out_valid == 0) && (out_data !== 0)) begin
        $display("**************************************************************");
        $display("*                       SPEC MAIN-2 FAIL                     *");    
        $display("*  The out_data should be reset when your out_valid is low.  *");
        $display("**************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end
end

// read input data from input.txt
reg direction_i;
reg [12:0] addr_dram_i;
reg [15:0] addr_sd_i;
integer i;

task input_task; begin
    $fscanf(pat_read, "%d %d %d", direction_i, addr_dram_i, addr_sd_i);

    repeat($urandom_range(1, 4)) @(negedge clk);    // wait for a random number of clock edges
    in_valid = 1;
    direction = direction_i;    // send out all read from input.txt
    addr_dram = addr_dram_i;
    addr_sd = addr_sd_i;

    @(negedge clk);
    in_valid = 1'b0;    //	finish giving all output after negedge clock
	direction = 1'bx;
    addr_dram = 1'bx;
    addr_sd = 1'bx;

end 
endtask

// SPEC MAIN-3: The execution latency is limited in 10000 cycles.
task wait_out_valid_task; begin
    latency = 0;
    while(out_valid !== 1'b1) begin
        if(latency == 10000) begin
            $display("*************************************************************");     
            $display("*                      SPEC MAIN-3 FAIL                     *");
            $display("*     The execution latency is limited in 10000 cycles.     *");
            $display("*************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end
        latency = latency + 1;
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end 
endtask

task check_ans_task; begin
    latency = 0;
    while(out_valid === 1)begin
        latency = latency + 1;
        // SPEC MAIN-4: The out_valid and out_data must be asserted in 8 cycles.
        if(latency > 8) begin
            $display("************************************************************");     
            $display("*                     SPEC MAIN-4 FAIL                     *");
            $display("* The out_valid and out_data must be asserted in 8 cycles. *");
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end

        // SPEC MAIN-6: The data in the DRAM and SD card should be correct when out_valid is high.
        if(u_SD.SD[addr_sd_i] !== u_DRAM.DRAM[addr_dram_i])begin
            $display("************************************************************");     
            $display("*                     SPEC MAIN-6 FAIL                     *");
            $display("*  The data in the DRAM and SD card should be correct when *");
            $display("*                 out_valid is high.                       *");
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end

        // SPEC MAIN-5: The out_data should be correct when out_valid is high.
        case(latency)
            1: begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][63:56]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][63:56]) Spec_5_Fail;
                end
            end
            2:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][55:48]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][55:48]) Spec_5_Fail;
                end
            end
            3:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][47:40]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][47:40]) Spec_5_Fail;
                end
            end
            4:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][39:32]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][39:32]) Spec_5_Fail;
                end
            end
            5:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][31:24]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][31:24]) Spec_5_Fail;
                end
            end
            6:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][23:16]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][23:16]) Spec_5_Fail;
                end
            end
            7:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][15:8]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][15:8]) Spec_5_Fail;
                end
            end
            8:  begin  
                if(direction_i === 0)begin
                    if(out_data !== u_SD.SD[addr_sd_i][7:0]) Spec_5_Fail;
                end 
                else begin
                    if(out_data !== u_DRAM.DRAM[addr_dram_i][7:0]) Spec_5_Fail;
                end
            end
        endcase

        
        @(negedge clk);
    end

    // SPEC MAIN-4: The out_valid and out_data must be asserted in 8 cycles.
    if(latency !== 8) begin
            $display("************************************************************");     
            $display("*                     SPEC MAIN-4 FAIL                     *");
            $display("* The out_valid and out_data must be asserted in 8 cycles. *");
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
    end
end 
endtask

//////////////////////////////////////////////////////////////////////

task Spec_5_Fail; begin
    $display("************************************************************");     
    $display("*                     SPEC MAIN-5 FAIL                     *");
    $display("*         The out_data should be correct when              *");
    $display("*             out_valid is high.                           *");
    $display("************************************************************");
    repeat(2) #CYCLE;
    $finish;
end 
endtask

task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end 
endtask

//////////////////////////////////////////////////////////////////////

pseudo_DRAM u_DRAM (
    .clk(clk),
    .rst_n(rst_n),
    // write address channel
    .AW_ADDR(AW_ADDR),
    .AW_VALID(AW_VALID),
    .AW_READY(AW_READY),
    // write data channel
    .W_VALID(W_VALID),
    .W_DATA(W_DATA),
    .W_READY(W_READY),
    // write response channel
    .B_VALID(B_VALID),
    .B_RESP(B_RESP),
    .B_READY(B_READY),
    // read address channel
    .AR_ADDR(AR_ADDR),
    .AR_VALID(AR_VALID),
    .AR_READY(AR_READY),
    // read data channel
    .R_DATA(R_DATA),
    .R_VALID(R_VALID),
    .R_RESP(R_RESP),
    .R_READY(R_READY)
);

pseudo_SD u_SD (
    .clk(clk),
    .MOSI(MOSI),
    .MISO(MISO)
);

endmodule