# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


async def reset(dut):
    dut.rst_n.value = 0
    dut.ena.value   = 1
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_cache_basic(dut):
    """Test simple write and read operations in the tiny cache"""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset(dut)

    # Helper to build ui_in bus
    def make_ui(req_valid, req_rw, addr, data_in):
        val = 0
        val |= (req_valid & 1) << 0
        val |= (req_rw & 1) << 1
        val |= (addr & 0b11) << 2
        val |= (data_in & 0b11) << 4
        return val

    # --- Write test ---
    dut.ui_in.value = make_ui(1, 1, addr=0b01, data_in=0b10)  # write 2 at addr=1
    await RisingEdge(dut.clk)

    assert dut.uo_out.value.integer & 0x1 == 0, "First write should be miss (hit=0)"

    # --- Read test ---
    dut.ui_in.value = make_ui(1, 0, addr=0b01, data_in=0)
    await RisingEdge(dut.clk)

    hit = (dut.uo_out.value.integer >> 0) & 1
    data = (dut.uo_out.value.integer >> 1) & 0b11
    assert hit == 1, f"Expected hit when reading addr=1, got {hit}"
    assert data == 0b10, f"Expected data=2, got {data}"

    # --- Miss read test ---
    dut.ui_in.value = make_ui(1, 0, addr=0b10, data_in=0)
    await RisingEdge(dut.clk)

    hit = (dut.uo_out.value.integer >> 0) & 1
    assert hit == 0, "Expected miss for addr not written yet"

    # --- Overwrite test ---
    dut.ui_in.value = make_ui(1, 1, addr=0b01, data_in=0b11)  # overwrite with 3
    await RisingEdge(dut.clk)

    dut.ui_in.value = make_ui(1, 0, addr=0b01, data_in=0)
    await RisingEdge(dut.clk)
    hit = (dut.uo_out.value.integer >> 0) & 1
    data = (dut.uo_out.value.integer >> 1) & 0b11
    assert hit == 1
    assert data == 0b11, f"Expected data=3 after overwrite, got {data}"
