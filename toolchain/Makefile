# Run from the toolchain directory in Windows Command Prompt.
SHELL := cmd.exe
.SHELLFLAGS := /C
.DEFAULT_GOAL := build

VITIS_SETTINGS ?= C:\Xilinx\2025.1\Vitis\settings64.bat
BUILD_SCRIPT := $(subst /,\,$(abspath scripts/build.py))
WORKSPACE := C:\Xilinx\vitis_workspace

.PHONY: build clean

build:
	@call "$(VITIS_SETTINGS)" && call vitis -s "$(BUILD_SCRIPT)"

clean:
	@if exist "$(WORKSPACE)" rmdir /s /q "$(WORKSPACE)"
	@if exist "dfx_runtime.txt" del /f /q "dfx_runtime.txt"
	@echo Clean complete.