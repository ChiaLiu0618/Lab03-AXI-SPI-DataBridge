# IC Lab – Lab03: AXI-SPI DataBridge

**NCTU-EE IC LAB**  
**Fall 2023**

## Introduction
In this lab, you will implement a hardware bridge (`BRIDGE.v`) that transfers data between a DRAM using an AXI4-lite interface and a pseudo-SD card using a simplified SPI protocol. You will also complete a testbench (`PATTERN.v`) and a simulation module for the SD card (`pseudo_SD.v`) to verify the functionality of the system.

## Project Description
- **Transfer Direction**: Either from DRAM to SD or from SD to DRAM.
- **Transfer Size**: Always 64 bits (8 bytes) per operation.
- **Transfer Count**: Two transfers per pattern.
- **Communication**: Fully simulate protocol behavior (AXI and SPI).
- **Verification**: Match expected output at the SD/DRAM target after transfer.

## Input Format (Input.txt)
Each pattern includes:
```
<direction> <dram address> <sd address>
```
- `direction = 0`: DRAM → SD
- `direction = 1`: SD → DRAM
- DRAM address: 0–8191
- SD address: 0–65535

## I/O Specification
### Inputs
| Signal       | Width | Description                         |
|--------------|-------|-------------------------------------|
| clk          | 1     | Clock signal                        |
| rst_n        | 1     | Asynchronous active-low reset       |
| in_valid     | 1     | High when inputs are valid          |
| direction    | 1     | 0 = DRAM→SD, 1 = SD→DRAM             |
| addr_dram    | 13    | 13-bit DRAM address (byte address)  |
| addr_sd      | 16    | 16-bit SD address                   |

### Outputs
| Signal       | Width | Description                        |
|--------------|-------|------------------------------------|
| out_valid    | 1     | High when output is valid          |
| out_data     | 8     | Output data (one byte per cycle)   |

## AXI4-Lite Interface
Your bridge must interface with a DRAM module using AXI4-lite protocol, following:
- Separate read/write address and data channels
- Handshake signals for VALID/READY
- Response handling via `B_VALID` and `R_VALID`

## SPI Protocol (Simplified)
Implements command-based SPI communication with the SD card:
- Commands: CMD17 (read) and CMD24 (write)
- Use 8-bit CRC7/CRC16 verification (must be implemented in Verilog)
- Simulate token delays and transaction length

## Specifications
1. **Top Module**: `BRIDGE.v`
2. **Clock Period**: 40 ns
3. **Reset**: One-time asynchronous reset at simulation start
4. **in_valid** is high for one cycle per command
5. **out_valid** must be high for exactly 8 cycles (one per byte)
6. **Input delay**: 0.5 × clock period
7. **Output delay**: 0.5 × clock period
8. **Latency Limit**: Execution must complete within 10,000 cycles
9. **Synthesis Constraints:**
   - Must have "MET" slack at end of timing report.
   - No latches allowed.
10. **Reset Behavior**:
    - All outputs reset to 0
    - out_data must remain 0 when out_valid is low

## Simulation and Testing
The project includes multiple verification steps:
- **RTL Simulation**: The RTL simulation is performed using Synopsys VCS.
- **Synthesis**: The design is synthesized using Synopsys Design Compiler with TSMC 40nm technology.
- **Gate-Level Simulation**: The synthesized design is simulated using Synopsys VCS.
- **Waveform Debugging**: Synopsys Verdi is used to inspect signals and debug the design.

## Hints
- Reuse modules where appropriate (e.g., shift registers).
- AXI protocol handshakes must be followed exactly.
- Implement custom CRC-7 and CRC-16 from scratch.
- Use waveform tools to debug timing interactions.

---
