# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_cache_basic(dut):
    dut._log.info("Start cache test")

    # Clock: 100 kHz (10 us period)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # ---------------------------
    # Write data = 2 at addr = 1
    # ---------------------------
    dut.ui_in.value = 0b000111  # req_valid=1, rw=1(write), addr=01, data=10
    await ClockCycles(dut.clk, 1)

    assert dut.uo_out.value.integer == 0, "Hit should be 0 on first write"

    # ---------------------------
    # Read back addr = 1
    # ---------------------------
    dut.ui_in.value = 0b000101  # req_valid=1, rw=0(read), addr=01
    await ClockCycles(dut.clk, 1)

    hit = int(dut.uo_out.value & 0b1)
    data = int((dut.uo_out.value >> 1) & 0b11)

    assert hit == 1, f"Expected hit=1, got {hit}"
    assert data == 2, f"Expected data=2, got {data}"
