# Implementation of Burrows-Wheeler Transform on FPGA

This repository contains SystemVerilog implementations of the Burrows-Wheeler Transform (BWT) and reverse BWT targeting FPGA devices.

## Used Technologies

* **Language:** SystemVerilog
* **IDE:** Xilinx Vivado 2018.3

## Repository Structure

The project includes multiple design variants optimized for different constraints:
* `<implementation_name>.sv` – Main module implementation (Design Source)
* `<implementation_name>_tb.sv` – Testbench for functional verification (Simulation Source)
* `<implementation_name>_tb_behav.wcfg` – Waveform configuration file for Vivado simulator (Simulation Source)

## Getting Started

1. **Clone this repository**
```bash
git clone https://github.com/ER562/Burrows_Wheeler_transform_FPGA.git
```

2. **Set up Vivado project**

Create a new RTL project and add files from the desired implementation.