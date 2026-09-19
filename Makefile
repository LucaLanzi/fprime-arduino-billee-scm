PROJECT_ROOT     := $(CURDIR)
PYTHON           ?= python3
VENV             := $(PROJECT_ROOT)/fprime-venv
VENV_PYTHON      := $(VENV)/bin/python
VENV_PIP         := $(VENV)/bin/pip
VENV_FPRIME_UTIL := $(VENV)/bin/fprime-util
ARDUINO_CLI      := $(VENV)/bin/arduino-cli

# fprime-util reads framework_path from settings.ini, but exporting it keeps
# direct fprime-util invocations working too.
export FPRIME_FRAMEWORK_PATH := $(PROJECT_ROOT)/lib/fprime
export PATH := $(VENV)/bin:$(PATH)

# Board / toolchain. `teensy41` = lib/fprime-arduino/cmake/toolchain/teensy41.cmake.
TOOLCHAIN     ?= teensy41
TEENSY_URL    := https://www.pjrc.com/teensy/package_teensy_index.json

# GDS. MAC_UART_DEVICE is this board's path on the maintainer's Mac - it varies
# per machine/USB port, override with `make gds mac UART_DEVICE=/dev/cu.usbmodemXXXXXXX`
# if yours differs (see README's "Finding the device" instructions).
MAC_UART_DEVICE ?= /dev/cu.usbmodem141478301
GDS_SERVICE      := billee-scm-lan-gds

.DEFAULT_GOAL := help
.PHONY: help setup setup-arduino setup-udev generate build clean print-banner \
        gds install-gds-service uninstall-gds-service gds-service-status gds-attach mac

help: ## Show available commands
	@$(MAKE) --no-print-directory print-banner
	@echo "Available commands:"
	@grep -E '^[A-Za-z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"} {printf "  %-16s %s\n", $$1, $$2}'
	@echo
	@echo "Typical first run:  make setup && make setup-arduino"
	@echo "Then (once a deployment exists):  make generate && make build"

setup: ## Create fprime-venv, init submodules, install Python deps into the venv
	$(PYTHON) -m venv fprime-venv
	git submodule update --init --recursive
	$(VENV_PIP) install --upgrade pip setuptools wheel
	$(VENV_PIP) install -r requirements.txt
	# fprime-arduino deps as a second pass: lib/fprime pins cmake==3.26.0 and
	# lib/fprime-arduino needs cmake>=3.26.4, which one pip resolve pass rejects.
	$(VENV_PIP) install -r lib/fprime-arduino/requirements.txt
	-@$(MAKE) --no-print-directory setup-udev || echo "[WARN] udev symlink rule not installed — GDS will fall back to raw /dev/ttyACMx paths, see README"
	@echo "[OK] make setup complete — next: make setup-arduino"
	@$(MAKE) --no-print-directory print-banner

setup-udev: ## Install the udev rule giving this board a stable /dev/ttyBILLEE_SCM symlink
	@sudo cp udev/99-billee-scm.rules /etc/udev/rules.d/99-billee-scm.rules
	@sudo udevadm control --reload-rules 2>/dev/null && sudo udevadm trigger 2>/dev/null || true
	@echo "[INFO] Installed udev rule -> /dev/ttyBILLEE_SCM (replug the board if it's already connected)"

setup-arduino: ## Install arduino-cli into the venv + Teensy board package + Time library
	@test -x "$(VENV_PYTHON)" || { echo "[ERROR] run 'make setup' first"; exit 1; }
	@if [ ! -x "$(ARDUINO_CLI)" ]; then \
		echo "[INFO] Installing arduino-cli into $(VENV)/bin ..."; \
		curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
			| BINDIR="$(VENV)/bin" sh; \
	else \
		echo "[INFO] arduino-cli already present: $$($(ARDUINO_CLI) version)"; \
	fi
	@$(ARDUINO_CLI) config init 2>/dev/null || echo "[INFO] arduino-cli config already initialized"
	$(ARDUINO_CLI) config add board_manager.additional_urls $(TEENSY_URL)
	$(ARDUINO_CLI) core update-index
	$(ARDUINO_CLI) core install teensy:avr@1.59.0
	$(ARDUINO_CLI) lib install Time
	@echo "[OK] make setup-arduino complete"
	@$(MAKE) --no-print-directory print-banner

generate: ## Run fprime-util generate for the Arduino target (needs a deployment)
	$(VENV_FPRIME_UTIL) generate $(TOOLCHAIN)

build: ## Build the Arduino target (needs a deployment)
	$(VENV_FPRIME_UTIL) build $(TOOLCHAIN)

clean: ## Purge F´ build caches and build artifacts
	-$(VENV_FPRIME_UTIL) purge --force
	rm -rf build-fprime-automatic-* build-artifacts
	@echo "[OK] make clean complete"

gds: ## Start GDS against the board (make gds mac to use MAC_UART_DEVICE)
	@if [ "$(filter mac,$(MAKECMDGOALS))" = "mac" ]; then \
		UART_DEVICE="$(MAC_UART_DEVICE)" ./uart_gds.sh; \
	else \
		./uart_gds.sh; \
	fi

install-gds-service: ## Install+enable a systemd service: lan_uart_gds.sh in a detached screen, auto-retry every 10s
	sudo ./install-lan-gds-service.sh

uninstall-gds-service: ## Stop and remove the billee-scm-lan-gds systemd service
	-sudo systemctl disable --now $(GDS_SERVICE).service
	sudo rm -f /etc/systemd/system/$(GDS_SERVICE).service
	sudo systemctl daemon-reload
	@echo "[INFO] $(GDS_SERVICE) removed"

gds-service-status: ## Show billee-scm-lan-gds service status and recent logs
	@systemctl status $(GDS_SERVICE).service --no-pager || true
	@echo
	@journalctl -u $(GDS_SERVICE).service -n 30 --no-pager || true

gds-attach: ## Attach to the running GDS screen session (Ctrl-A then D to detach)
	screen -r $(GDS_SERVICE)

# Dummy target used only as a command-line keyword (make gds mac)
mac:
	@:

print-banner: ## Print the project splash screen
	@echo ""
	@echo "██████╗  ██╗██╗     ██╗     ███████╗███████╗"
	@echo "██╔══██╗ ██║██║     ██║     ██╔════╝██╔════╝"
	@echo "██████╔╝ ██║██║     ██║     █████╗  █████╗  "
	@echo "██╔══██╗ ██║██║     ██║     ██╔══╝  ██╔══╝  "
	@echo "██████╔╝ ██║███████╗███████╗███████╗███████╗"
	@echo "╚═════╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝"
	@echo ""
	@echo "        Science Control Module"
	@echo "        F´ on Teensy 4.1 (iMXRT1062)"
	@echo "        Powered by F\` Flight Software (NASA/JPL)"
	@echo ""
