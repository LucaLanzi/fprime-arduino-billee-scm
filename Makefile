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

# Board / toolchain. `atmega2560` = cmake/toolchain/atmega2560.cmake.
TOOLCHAIN        ?= atmega2560
MEGACORE_URL     := https://mcudude.github.io/MegaCore/package_MCUdude_MegaCore_index.json

.DEFAULT_GOAL := help
.PHONY: help setup setup-arduino generate build clean print-banner

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
	@echo "[OK] make setup complete — next: make setup-arduino"
	@$(MAKE) --no-print-directory print-banner

setup-arduino: ## Install arduino-cli into the venv + MegaCore:avr core + Time library
	@test -x "$(VENV_PYTHON)" || { echo "[ERROR] run 'make setup' first"; exit 1; }
	@if [ ! -x "$(ARDUINO_CLI)" ]; then \
		echo "[INFO] Installing arduino-cli into $(VENV)/bin ..."; \
		curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
			| BINDIR="$(VENV)/bin" sh; \
	else \
		echo "[INFO] arduino-cli already present: $$($(ARDUINO_CLI) version)"; \
	fi
	@$(ARDUINO_CLI) config init 2>/dev/null || echo "[INFO] arduino-cli config already initialized"
	$(ARDUINO_CLI) config add board_manager.additional_urls $(MEGACORE_URL)
	$(ARDUINO_CLI) core update-index
	$(ARDUINO_CLI) core install MegaCore:avr
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
	@echo "        F´ on Arduino Mega 2560 (ATmega2560)"
	@echo "        Powered by F\` Flight Software (NASA/JPL)"
	@echo ""
