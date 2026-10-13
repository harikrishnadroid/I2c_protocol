# I2c_protocol
# I2C Master-Slave Protocol Design using Verilog

## 1. Project Overview

This project implements an I2C (Inter-Integrated Circuit) Master and Slave using Verilog HDL. The design demonstrates two-wire serial communication using the Serial Data (SDA) and Serial Clock (SCL) lines.

The I2C Master initiates communication, generates the clock, transmits the slave address and data, and receives data from the Slave. The I2C Slave detects bus conditions, checks the received address, acknowledges communication, and handles data reception and transmission.

The design uses Finite State Machines (FSMs) to control the communication sequence and open-drain-style bus signaling with pull-up elements.

## 2. Project Objectives

- Implement I2C Master and Slave modules using Verilog HDL.
- Generate SCL timing using a configurable clock divider.
- Implement slave address transmission and address detection.
- Support serial data transmission and reception.
- Implement START, STOP, and repeated START detection and generation logic.
- Handle acknowledgment (ACK) and non-acknowledgment (NACK) phases.
- Analyze communication behavior through simulation waveforms.

## 3. Architecture

The design consists of an I2C Master, an I2C Slave, and a top-level module connecting both devices.

<img width="2774" height="1580" alt="i2c_architecture" src="https://github.com/user-attachments/assets/32c474e6-6c76-4943-9fc5-40571bcc401f" />

### Module Description

| Module | Description |
|---|---|
| `master` | Controls I2C communication, generates SCL timing, transmits address and data, and receives serial data. |
| `slave` | Detects START/STOP conditions, compares the received address against its configured address, and handles data and acknowledgment phases. |
| `top` | Instantiates the Master and Slave, connects SDA/SCL, and adds pull-up elements to the shared bus. |

## 4. Interface Signals

### I2C Master

| Signal | Direction | Description |
|---|---|---|
| `aclk` | Input | Master control clock |
| `rst` | Input | Active-high asynchronous reset |
| `en` | Input | Enables the transaction |
| `d_in[7:0]` | Input | Parallel data to transmit |
| `d_out[7:0]` | Output | Received parallel data |
| `addr[6:0]` | Input | Seven-bit slave address |
| `div[6:0]` | Input | SCL clock-divider setting |
| `rw` | Input | Read/write selection: `0` for write, `1` for read |
| `sda` | Inout | Bidirectional serial data line |
| `scl` | Inout | Serial clock line |

### I2C Slave

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Slave control clock |
| `rst` | Input | Active-high asynchronous reset |
| `sda` | Inout | Shared serial data line |
| `scl` | Inout | Shared serial clock line |
| `slv_addr` | Parameter | Configurable seven-bit slave address; defaults to `7'd7` |

## 5. I2C Protocol Implementation

## 5.1 Frame size
<img width="1459" height="666" alt="Screenshot 2026-10-13 at 3 35 03 PM" src="https://github.com/user-attachments/assets/c9660b34-26d6-4892-a4c1-cd4df2eec36d" />
<img width="1376" height="768" alt="i2c_frame_format" src="https://github.com/user-attachments/assets/8cf78e43-2ba5-4808-a81f-481f34055b9e" />


### 5.2 START Condition

A START condition is detected when SDA transitions from HIGH to LOW while SCL is HIGH.

The Slave monitors SDA and SCL to detect this condition and begin receiving the address.

### 5.3 Address Transmission

The Master constructs an eight-bit address field:

`{addr[6:0], rw}`

The seven-bit slave address is followed by the R/W bit.

- `rw = 0`: Master write operation.
- `rw = 1`: Master read operation.

The Slave shifts in the received bits and compares the address field against its configured seven-bit address.

### 5.4 Write Operation

The intended write sequence is:

1. The Master initiates a START condition.
2. The Master transmits the slave address with `rw = 0`.
3. The Slave checks the address and acknowledges a match.
4. The Master transmits the eight-bit data from `d_in`.
5. The Slave receives the data and enters its acknowledgment state.
6. The transaction proceeds toward completion.

### 5.5 Read Operation

The intended read sequence is:

1. The Master initiates a START condition.
2. The Master transmits the slave address with `rw = 1`.
3. The Slave detects its address and acknowledges it.
4. The Slave shifts its stored data onto SDA.
5. The Master samples the serial data and shifts it into `rx_reg`.
6. The received byte is transferred to `d_out`.

The current RTL includes the main states for these operations. End-to-end read behavior and acknowledgment timing must be verified in simulation before claiming complete functionality.

### 5.6 Repeated START

The Master includes a `re_start` state and a second address-transmission state, `addr_tr2`.

These states are intended to support a repeated START followed by another address phase, allowing a combined write/read sequence without an intervening STOP condition.

The current implementation reloads the address and R/W bit from the Master inputs during the repeated-start sequence. Therefore, the R/W control timing must be coordinated and tested to ensure the second address indicates a read operation when required.

### 5.7 ACK and NACK Handling

The design includes separate FSM states for address and data acknowledgment phases.

- The receiver pulls SDA LOW during an ACK bit.
- SDA is released when the receiver is not driving the line.
- The Master samples SDA to determine the acknowledgment response.

The exact ACK/NACK behavior, especially after the final read byte, requires waveform verification.

### 5.8 STOP Condition

A STOP condition is detected when SDA transitions from LOW to HIGH while SCL is HIGH.

The Slave uses the detected STOP condition to return toward its idle state. The Master includes a `stop` state that releases SDA when the enable signal is deasserted and the clock is HIGH.

## 6. FSM Design

### Master FSM

The Master uses a four-bit state register, `pr_state`, to sequence the communication.

| State | Purpose |
|---|---|
| `idle` | Waits for transaction enable |
| `start` | Initiates communication |
| `addr_tr1` | Transmits the first address field |
| `ack_st` | Handles acknowledgment sampling |
| `pre_ack1` | Prepares for data transmission |
| `data_tr` | Transmits data bits |
| `pre_ack2` | Prepares for the repeated START |
| `re_start` | Controls the repeated-start sequence |
| `addr_tr2` | Transmits the second address field |
| `pre_ack3` | Prepares the receive phase |
| `master_rx` | Receives serial data |
| `rd_ack` | Controls the read acknowledgment phase |
| `stop` | Completes the transaction |

### Slave FSM

The Slave uses a four-bit state register to manage address reception, data reception, data transmission, and bus conditions.

| State | Purpose |
|---|---|
| `idle` | Waits for START |
| `addr_rx1` | Receives the first address field |
| `addr_ack1` | Generates address ACK |
| `wack` | Releases SDA after acknowledgment |
| `data_rx` | Receives write data |
| `addr_ack2` | Generates data ACK |
| `dack` | Releases SDA after data acknowledgment |
| `restart` | Waits for a repeated START |
| `addr_rx2` | Receives the second address field |
| `addr_ack3` | Generates acknowledgment for the second address |
| `rack` | Prepares for data transmission |
| `tr_data` | Transmits data serially |
| `ack` | Samples the master's acknowledgment |
| `stop_st` | Waits for STOP before returning to idle |

## 7. Clock Generation and Bus Signaling

The Master uses `clk_counter` and the configurable `div` input to toggle `scl_oe`. The SCL line is driven LOW or released, allowing the pull-up element to produce a HIGH level.

The intended divider behavior is:

\[
f_{\text{SCL}} \approx \frac{f_{\text{aclk}}}{2(\text{div}+1)}
\]

This expression assumes the clock toggles once per `div + 1` input-clock cycles and that the bus is not held LOW by another device. The actual SCL frequency and timing must be measured from the simulation waveform.

The design uses open-drain-style assignments:

```verilog
assign sda = sda_oe ? 1'b0 : 1'bz;
assign scl = scl_oe ? 1'b0 : 1'bz;
```

The top module adds pull-up elements to SDA and SCL. Devices can pull the lines LOW or release them to be pulled HIGH.

## 8. Design Decisions and Challenges

### Design Decisions

- Used separate Master and Slave FSMs to organize protocol operations.
- Used shift registers to serialize address and data fields.
- Used counters to track transmitted and received bits.
- Generated SCL from the Master control clock using a configurable divider.
- Used shared SDA/SCL lines with pull-up elements for bidirectional communication.
- Added separate states for address acknowledgment, data acknowledgment, repeated START, and data reception.

### Challenges to Investigate

- Coordinating SDA transitions with SCL edges.
- Ensuring address and R/W bits are sampled correctly.
- Correctly releasing SDA between transmission and acknowledgment phases.
- Coordinating the R/W input during a repeated START.
- Handling final-byte ACK/NACK behavior during reads.
- Preventing the FSM from becoming stuck when an address is not acknowledged.
- Ensuring the Master and Slave control clocks are appropriately synchronized.

## 9. Verification Plan

The following scenarios should be exercised in simulation.

- [ ] Reset and return to idle.
- [ ] START condition detection.
- [ ] Correct slave address matching.
- [ ] Address mismatch behavior.
- [ ] Master-to-Slave data transfer.
- [ ] Slave-to-Master data transfer.
- [ ] Address ACK and data ACK.
- [ ] Final-byte NACK handling.
- [ ] Repeated START followed by a read address.
- [ ] STOP condition detection.
- [ ] SCL divider and SDA/SCL timing.
- [ ] Reset during a transaction.

### Simulation Results


<img width="1459" height="666" alt="Screenshot 2026-10-13 at 3 35 03 PM" src="https://github.com/user-attachments/assets/ae9c79a7-9bfe-46e0-aa4d-d78862c393d3" />

<img width="1467" height="734" alt="Screenshot 2026-10-13 at 4 36 37 PM" src="https://github.com/user-attachments/assets/dbf84c6b-22ee-42b4-a25b-bf9a3007f859" />


## 10. Tools and Technologies

- **HDL:** Verilog / SystemVerilog-compatible RTL
- **Simulation environment:** EDA Playground
- **Simulator:** Riviera-PRO
- **Waveform analysis:** VCD waveform viewer
- **Version control:** Git and GitHub

## 11. Repository Structure

Update this example to match your actual file and folder names.

```text
I2C-Protocol/
├── i2c_master.sv
├── i2c_slave.sv
├── top.sv
├── testbench.sv
├── waveforms/
│   ├── write_transaction.png
│   ├── read_transaction.png
│   └── repeated_start.png
└── README.md
```

## 12. Key Learnings

- Understanding I2C serial communication at the RTL level.
- Designing FSM-based protocol controllers.
- Implementing serial-to-parallel and parallel-to-serial data handling.
- Understanding open-drain-style signaling and pull-up elements.
- Managing address detection, ACK/NACK phases, and repeated START logic.
- Debugging protocol behavior using simulation waveforms.

## 13. Future Improvements

- Complete end-to-end verification of write and read transactions.
- Improve handling of address mismatches and missing acknowledgments.
- Add a self-checking SystemVerilog testbench and scoreboard.
- Add protocol assertions and automated waveform checks.
- Verify clock-divider settings and protocol timing.
- Extend the design with additional test cases and error scenarios.

## 14. Author

**Hari Krishna Muraboina**

- GitHub: [harikrishnadroid](https://github.com/harikrishnadroid)
- LinkedIn: [Hari Krishna Muraboina](https://www.linkedin.com/in/hari-krishna-muraboina/)

**Focus Areas:** RTL Design | Verilog | SystemVerilog | Design Verification | Digital Design
