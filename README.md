# Atlas RISC-V Architecture

This repository contains the Verilog implementation of a **RISC-Vprocessor**, designed with a focus on **computer architecture and microarchitecture**.  
The core follows the RISC-V specification and implements a classical **5-stage pipeline**.

---

## 🔧 Architecture Overview

The processor is based on the **RV32I ISA** (32-bit integer instructions).  
It is structured as a modular design with the following main components:

- **Instruction Fetch (IF)**  
  - Program Counter (PC)  
  - Instruction Memory (IMEM)  
  - Next-PC logic  

- **Instruction Decode (ID)**  
  - Control Unit (instruction decoding)  
  - Register File (32 × 32-bit registers, `x0` hardwired to zero)  
  - Immediate Generator  

- **Execute (EX)**  
  - Arithmetic Logic Unit (ALU)  
  - Branch Comparator  
  - Forwarding Unit  

- **Memory (MEM)**  
  - Data Memory (DMEM)  
  - Load/Store Unit  

- **Write Back (WB)**  
  - Multiplexer to update the Register File  

---

## ⚙️ Pipeline and Hazards

- **Pipeline Depth**: 5 stages (IF → ID → EX → MEM → WB).  
- **Hazard Handling**:
  - **Data hazards**: solved with *forwarding* and *stalling*.  
  - **Control hazards**: handled by *flushing* instructions on taken branches.  

---
