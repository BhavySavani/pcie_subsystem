# ==========================================
# Universal PCIe Subsystem Verification
# ==========================================

# Auto-detect OS to fix macOS Apple Silicon/Intel archiver clashes
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    AR_OVERRIDE = AR=/usr/bin/ar RANLIB=/usr/bin/ranlib CXX=clang++ LINK=clang++
else
    AR_OVERRIDE = 
endif

# Common Verilator Configuration
V_FLAGS = --cc --exe --main --timing --trace -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT

# Common Packages
PKG_BASE = ../rtl/pcie_subsystem/packages/pcie_pkg.sv

.PHONY: all clean test_cq test_rc

all: test_cq test_rc test_cc

test_cq:
	@echo ">>> Building and Running CQ Parser Testbench..."
	verilator $(V_FLAGS) --top-module tb_cq_parser \
		$(PKG_BASE) ../rtl/pcie_subsystem/packages/pcie_cq_pkg.sv \
		../rtl/pcie_subsystem/internal/register/cq_parser_non_straddle.sv \
		tb_cq_parser.sv
	make -C obj_dir -j -f Vtb_cq_parser.mk $(AR_OVERRIDE)
	./obj_dir/Vtb_cq_parser
	
test_rc:
	@echo ">>> Building and Running RC Parser Testbench..."
	verilator $(V_FLAGS) --top-module tb_rc_parser \
		$(PKG_BASE) ../rtl/pcie_subsystem/packages/pcie_rc_pkg.sv \
		../rtl/pcie_subsystem/internal/dma_reader/rc_parser.sv \
		tb_rc_parser.sv
	make -C obj_dir -j -f Vtb_rc_parser.mk $(AR_OVERRIDE)
	./obj_dir/Vtb_rc_parser

test_router:
	@echo ">>> Building and Running Register Router Testbench..."
	verilator $(V_FLAGS) --top-module tb_register_router \
		../rtl/pcie_subsystem/packages/pcie_pkg.sv \
		../rtl/pcie_subsystem/packages/register_controller_pkg.sv \
		../rtl/pcie_subsystem/common/register/register_router.sv \
		tb_register_router.sv
	make -C obj_dir -j -f Vtb_register_router.mk $(AR_OVERRIDE)
	./obj_dir/Vtb_register_router

	
clean:
	@echo ">>> Cleaning build artifacts..."
	rm -rf obj_dir
	rm -f *.vcd