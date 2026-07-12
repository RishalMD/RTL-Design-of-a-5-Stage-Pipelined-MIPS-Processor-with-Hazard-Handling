# RTL Design of a 5-Stage Pipelined MIPS Processor with Hazard Handling

- 5-stage pipelined 32-bit MIPS32 processor, implemented as synthesizable RTL in Verilog (instruction memory preloading via `$readmemh` is simulation-only; the pipeline datapath and control logic are fully synthesizable)
- All hazard types handled:
  - Data hazards — operand forwarding, with stalling for load-use cases
  - Control hazards — pipeline flushing on taken branches
- Reduces net CPI compared to a stall-only design, by resolving most data hazards through forwarding instead of stalling
- Functionality verified through directed testing across five targeted testbenches

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Instruction Set](#instruction-set)
- [Instruction Encoding](#instruction-encoding)
- [Addressing Modes](#addressing-modes)
- [Pipeline Stages](#pipeline-stages)
- [Memory Subsystem](#memory-subsystem)
- [Hazard Handling](#hazard-handling)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run-vivado)
- [Testing and Verification](#testing-and-verification)
- [Design Decisions](#design-decisions)
- [Limitations / Future Work](#limitations--future-work)

---

## Overview

A classic 5-stage MIPS32 pipeline (IF → ID → EX → MEM → WB), described as synthesizable RTL: synchronous pipeline registers (`IF_ID`, `ID_EX`, `EX_MEM`, `MEM_WB`) clocked every cycle, with combinational logic between them (ALU, forwarding muxes, hazard detection, branch resolution) computing what each register captures next.

Supports R-R and R-I arithmetic/logical instructions, load/store, and conditional branches, with a dedicated hazard detection and forwarding unit and a branch resolution/flush unit.

---

## Architecture

```
                 ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
   PC ──────────▶│   IF   │──▶│   ID   │──▶│   EX   │──▶│  MEM   │──▶│   WB   │
                 └────────┘   └────────┘   └────────┘   └────────┘   └────────┘
                     │             │            │             │            │
              Instruction     Register     ALU / Branch   Data Mem     Register
                Memory          File        Target Calc    Access       Write
                     ▲             ▲            ▲             │
                     │             │            │             │
                     └─── branch_target (EX_MEM_ALUOUT) ───────┘
                     │             │
          HAZARD_UNIT: ForwardA/B, load_hazard
          (reads IF_ID_IR, ID_EX_IR, EX_MEM_IR, MEM_WB_IR)
                     │
          BRANCH_PREDICTION_UNIT: branch_flag
          (reads EX_MEM_IR, EX_MEM_COND)
```

Pipeline registers: `IF_ID`, `ID_EX`, `EX_MEM`, `MEM_WB`.
Two supporting combinational units sit alongside the datapath:
- **HAZARD_UNIT** — generates `ForwardA`, `ForwardB`, `load_hazard`
- **BRANCH_PREDICTION_UNIT** — generates `branch_flag` from the registered branch condition

---

## Instruction Set

| Category | Instructions |
|---|---|
| Arithmetic/Logical (R-R) | `ADD`, `SUB`, `AND`, `OR`, `SLT`, `MUL` |
| Arithmetic/Logical (R-I) | `ADDI`, `SUBI`, `SLTI` |
| Load/Store | `LW`, `SW` |
| Branch | `BEQZ`, `BNEQZ` |

### Opcode Table

| Mnemonic | Opcode (6-bit) | Type |
|---|---|---|
| ADD  | 000000 | R-R |
| SUB  | 000001 | R-R |
| AND  | 000010 | R-R |
| OR   | 000011 | R-R |
| SLT  | 000100 | R-R |
| MUL  | 000101 | R-R |
| LW   | 001000 | Load |
| SW   | 001001 | Store |
| ADDI | 001010 | R-I |
| SUBI | 001011 | R-I |
| SLTI | 001100 | R-I |
| BNEQZ| 001101 | Branch |
| BEQZ | 001110 | Branch |

---

## Instruction Encoding

### R-R Type (32 bits)

```
 31        26 25      21 20      16 15      11 10       6 5         0
┌────────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│   opcode   │    rs    │    rt    │    rd    │  shamt   │  funct   │
│   6 bits   │  5 bits  │  5 bits  │  5 bits  │  5 bits  │  6 bits  │
└────────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```
Destination register: **rd**. Example: `ADD R4, R1, R2` → `rs=R1, rt=R2, rd=R4`.

### R-I Type (32 bits)

```
 31        26 25      21 20      16 15                              0
┌────────────┬──────────┬──────────┬──────────────────────────────────┐
│   opcode   │    rs    │    rt    │         immediate (16 bits)       │
│   6 bits   │  5 bits  │  5 bits  │           sign-extended           │
└────────────┴──────────┴──────────┴──────────────────────────────────┘
```
Destination register: **rt**. Example: `ADDI R1, R0, 10` → `rs=R0, rt=R1, imm=10`.

### Load/Store (same layout as R-I)

- `LW  rt, imm(rs)` → address = `rs + imm`, loaded value written to `rt`
- `SW  rt, imm(rs)` → address = `rs + imm`, value stored is `rt`

### Branch (same layout as R-I)

- `BEQZ/BNEQZ rs, imm` → condition tested on `rs`; target = `NPC + imm`

---

## Addressing Modes

| Mode | Example | Description |
|---|---|---|
| Register | `ADD R1,R2,R3` | Operands taken directly from registers |
| Immediate | `ADDI R3,R1,50` | One operand is a sign-extended immediate |
| Base (displacement) | `LW R1,50(R2)` | Effective address = base register + offset |
| PC-relative | `BEQZ R3,label` | Branch target = NPC + offset |

---

## Pipeline Stages

**IF (Instruction Fetch)**
- Drives `PC` onto `instruction_address_bus`; reads `instruction_bus` from `INSTRUCTION_MEMORY` (asynchronous read)
- Computes `NPC = PC + 1` (word-addressed)
- On `branch_flag`: redirects `PC` to `branch_target`, flushes `IF_ID` to NOP
- On `load_hazard`: holds `PC` and `IF_ID` at their current values (stall)

**ID (Instruction Decode)**
- Reads `rs`/`rt` from the register file
- Internal same-cycle WB→ID forwarding bypass, so a register written back this cycle is read correctly by an instruction decoding in the same cycle
- Sign-extends the 16-bit immediate
- On `branch_flag` or `load_hazard`: inserts a NOP into `ID_EX`

**EX (Execute)**
- Selects ALU operands via `ForwardA`/`ForwardB` muxes (EX/MEM and MEM/WB forwarding)
- Performs ALU operation per opcode (R-R, R-I) or computes effective address (load/store) or branch target + condition (branch)
- On `branch_flag`: flushes `EX_MEM` to NOP (this is the 3rd flushed stage — see [Design Decisions](#design-decisions))

**MEM (Memory Access)**
- Drives `data_bus_address`, `read_enable`, `write_enable`, `data_write_data` to `DATA_MEMORY` (combinational, so the async read settles within the same cycle)
- Latches `data_bus` (loaded value) into `MEM_WB_LMD` on `LW`
- Passes `ALUOUT` and `IR` through to `MEM_WB` for non-memory instructions

**WB (Write Back)**
- Decodes destination register (`rd` for R-R, `rt` for R-I/LW) from `MEM_WB_IR`
- Selects data source: `MEM_WB_ALUOUT` (arithmetic) or `MEM_WB_LMD` (load)
- Drives `reg_update_flag`, `reg_update_address`, `reg_update_data` back to the register file in ID
- No write back for `SW`, `BEQZ`, `BNEQZ`, or bubbles

---

## Memory Subsystem

**Instruction Memory** — read-only, asynchronous:
- Input: `instruction_address_bus`
- Output: `instruction_bus` — combinationally reflects `memory[instruction_address_bus]`
- Loaded once at simulation start via `$readmemh`

**Data Memory** — asynchronous read, synchronous write:
- Inputs: `data_bus_address`, `read_enable`, `write_enable`, `data_write_data`
- Output: `data_bus`
- `read_enable` high → `data_bus` combinationally reflects `memory[data_bus_address]`
- `write_enable` high → `memory[data_bus_address]` updated on the next clock edge

Separate instruction/data memories eliminate structural hazards entirely — IF and MEM can access memory in the same cycle without contention.

---

## Hazard Handling

### Data Hazards — HAZARD_UNIT (combinational)

Inputs: `IF_ID_IR`, `ID_EX_IR`, `EX_MEM_IR`, `MEM_WB_IR`
Outputs: `ForwardA` (2-bit), `ForwardB` (2-bit), `load_hazard`

| ForwardA/B | Source |
|---|---|
| `00` | No forwarding — use `ID_EX_A`/`ID_EX_B` |
| `10` | Forward from `EX_MEM_ALUOUT` |
| `01` | Forward from `MEM_WB_ALUOUT` |
| `11` | Forward from `MEM_WB_LMD` (loaded value) |

Destination-register comparisons explicitly **exclude register `$0`**, since writes to `$0` are architecturally discarded and must never be forwarded as if they were real data (see [Test 4](#testing-and-verification)).

**Load-use hazard:** when the instruction in `ID_EX` is a `LW` and the instruction currently in `IF_ID` needs that same destination register, `load_hazard` asserts. This stalls `PC`/`IF_ID` for one cycle and inserts a bubble into `ID_EX`, so the loaded value has time to reach `MEM_WB_LMD` before being forwarded (`ForwardA/B = 11`).

### Control Hazards — BRANCH_PREDICTION_UNIT (combinational)

Inputs: `EX_MEM_IR`, `EX_MEM_COND`
Output: `branch_flag`

Since branch condition (`EX_MEM_COND`) is a **registered** output of the EX stage, it is only valid one cycle after the branch instruction's own EX stage — by which point three additional instructions have already been fetched down the wrong path. A taken branch therefore flushes **three** pipeline registers in the same cycle: `IF_ID`, `ID_EX`, and `EX_MEM` (see [Test 2](#testing-and-verification)).

### Structural Hazards

Avoided by construction: separate `INSTRUCTION_MEMORY` and `DATA_MEMORY` modules, and a register file with 2 combinational read ports + 1 clocked write port.

---

## Repository Structure

```
├── rtl/
│   ├── IF.v
│   ├── ID.v
│   ├── EX.v
│   ├── MEM.v
│   ├── WB.v
│   ├── HAZARD_UNIT.v
│   ├── BRANCH_PREDICTION_UNIT.v
│   ├── INSTRUCTION_MEMORY.v
│   ├── DATA_MEMORY.v
│   └── MIPS_TOP.v
├── testbench/
│   ├── tb_MIPS_TOP.v
│   ├── tb_MIPS_TOP_branch.v
│   ├── tb_MIPS_TOP_storeload.v
│   ├── tb_MIPS_TOP_zero_reg.v
│   └── tb_MIPS_TOP_loaduse.v
├── programs/
│   ├── program.hex
│   ├── program_branch.hex
│   ├── program_storeload.hex
│   ├── program_zero_reg.hex
│   └── program_loaduse.hex
├── docs/
│   └── architecture diagrams / waveform screenshots
├── README.md
└── LICENSE
```

---

## How to Run (Vivado)

1. Create a new Vivado project (RTL project, no board part required for simulation-only use).
2. Add all files under `rtl/` as **Design Sources**.
3. Add the desired testbench from `testbench/` as a **Simulation Source**, and set it as the simulation top (`Sources` pane → right-click → **Set as Top**).
4. In `INSTRUCTION_MEMORY.v`, set the `$readmemh` path to the matching `.hex` file from `programs/` for the test you're running.
5. Add that `.hex` file to the project (Add Sources → filter set to **All Files**, since `.hex` isn't auto-detected).
6. Run **Behavioral Simulation**.
7. Register values print via `$display` at the end of each testbench, along with a `TEST PASSED` / `TEST FAILED` summary.

---

## Testing and Verification

Five directed testbenches, each targeting one specific mechanism.

### Test 1 — Arithmetic + Forwarding
```
ADDI R1,R0,10
ADDI R2,R0,20
ADDI R3,R0,30
ADD  R4,R1,R2
ADD  R4,R4,R3
```
Expected: `R4 = 60`. Exercises EX/MEM forwarding (`ADD R4,R4,R3` depends on the immediately preceding instruction's result).

**Result: `R1=10, R2=20, R3=30, R4=60` — PASSED**

### Test 2 — Taken Branch + 3-Stage Flush
```
ADDI R1,R0,0
BEQZ R1,3          ; taken
ADDI R2,R0,111      ; wrong-path — must be flushed
ADDI R3,R0,222      ; wrong-path — must be flushed
ADDI R4,R0,333      ; wrong-path — must be flushed
ADDI R5,R0,99       ; branch target
ADD  R6,R5,R0
```
Expected: `R2=R3=R4=0` (never executed), `R5=R6=99`. Directly tests the 3-stage flush described above.

**Result: `R1=0, R2=0, R3=0, R4=0, R5=99, R6=99` — PASSED**

### Test 3 — Store/Load Round-Trip
```
ADDI R1,R0,77
ADDI R2,R0,4
SW   R1,0(R2)
ADDI R3,R0,55
LW   R4,0(R2)
ADDI R6,R0,1
ADD  R5,R4,R6
```
Expected: `R4 = 77` (correctly read back). Validates `DATA_MEMORY` write/read timing.

**Result: `R1=77, R2=4, R3=55, R4=77, R5=78, R6=1` — PASSED**

### Test 4 — `$0` Forwarding Exclusion
```
ADDI R1,R0,25
ADDI R2,R0,17
ADD  R0,R1,R2   ; writes 42 to R0 — architecturally discarded
ADD  R4,R0,R0   ; reads $0 twice
ADD  R5,R4,R1
```
Expected: `R4 = 0`. Without the `!= 5'd0` exclusion in `HAZARD_UNIT`, this would incorrectly forward the discarded ALU result (`R4 = 84`).

**Result: `R1=25, R2=17, R4=0, R5=25` — PASSED**

### Test 5 — Load-Use Hazard Stall
```
ADDI R1,R0,88
ADDI R2,R0,8
SW   R1,0(R2)
LW   R5,0(R2)
ADD  R6,R5,R0   ; uses R5 immediately after the load
ADDI R7,R0,5
ADD  R8,R6,R7
```
Expected: `R6 = 88`. `R5` cannot be forwarded from EX/MEM in time (its own load isn't resolved until MEM), so this only passes if `load_hazard` stalls the pipeline for exactly one cycle and then forwards via `MEM_WB_LMD`.

**Result: `R1=88, R2=8, R5=88, R6=88, R7=5, R8=93` — PASSED**

### Summary

| # | Test | Mechanism Verified | Result |
|---|---|---|---|
| 1 | Arithmetic + forwarding | Basic datapath, EX/MEM forwarding | PASSED |
| 2 | Taken branch | 3-stage flush on misprediction | PASSED |
| 3 | Store/load round-trip | Data memory timing | PASSED |
| 4 | `$0` forwarding exclusion | Hazard unit register-zero guard | PASSED |
| 5 | Load-use hazard | Stall + bubble + `2'b11` forward path | PASSED |

All five tests pass. Together, they form a complete verification pass covering every structural hazard-handling mechanism in the design — data forwarding at two distances, control hazard flush, structural memory separation, and the load-use stall — plus a subtle register-zero forwarding edge case that would otherwise fail silently.

---

## Design Decisions

- **Branch resolved at EX/MEM, not ID.** `EX_MEM_COND` is a registered signal, so branch resolution costs a 3-stage flush penalty rather than the 1-stage penalty of an ID-resolved design. This was a deliberate simplicity/performance tradeoff.
- **Word-addressed PC.** `PC` increments by 1 per instruction (not 4), and both memories index directly by `PC`/address rather than shifting by 2. Consistent throughout the design.
- **Asynchronous memory reads.** Both instruction and data memory produce combinational reads, matching the pipeline's one-cycle-per-stage timing assumption; synchronous reads would require additional stalling not currently implemented.
- **Same-cycle WB→ID register bypass.** The register file forwards `reg_update_data` internally when a write and a read to the same address occur in the same cycle, avoiding stale reads without needing a full pipeline stall for this case.
- **Opcode decode deferred to EX.** `ID` only reads registers and prepares `NPC`/immediate; full opcode decode (ALU control, destination register, control signals) happens in `EX`/`WB` directly from the propagated instruction register.

---

## Limitations / Future Work

- No exception/interrupt handling
- No `JAL`/`JR`/jump instructions — branches only
- No cache hierarchy — single-cycle asynchronous memory model assumed
- No functional coverage or randomized/constrained-random verification — all tests are directed
- No synthesis/timing closure performed — behavioral simulation only
