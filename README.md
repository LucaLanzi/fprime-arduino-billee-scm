# FprimeArduinoBilleeScm

F´ (F Prime) firmware project for the **BILLEE Science Control Module (SCM)**,
cross-compiled for an **Arduino Mega 2560** (Microchip **ATmega2560**, 8-bit AVR,
256 KB flash / **8 KB SRAM**, 16 MHz) through NASA JPL's
[fprime-arduino](https://github.com/fprime-community/fprime-arduino) `ArduinoFw`
platform.

> The 8 KB SRAM ceiling forces a **baremetal (no-OS)** build and a deliberately
> small topology. This is not a full CDH deployment target.

---

## Repository layout

```
fprime-arduino-billee-scm/
├── CMakeLists.txt                 # project build entry — pulls in F´ core, then this project
├── settings.ini                  # F´ project settings (paths, libraries, default toolchain)
├── requirements.txt              # Python deps installed INTO fprime-venv (never system-wide)
├── Makefile                      # bootstrap + build wrappers (see "Make targets")
├── CMakePresets.json             # IDE/CMake presets that point at ./fprime-venv
├── .clang-format                 # Chromium-based, 4-space, 120 col
├── cmake/
│   └── toolchain/
│       └── atmega2560.cmake      # the board toolchain (this file makes "atmega2560" a target)
├── FprimeArduinoBilleeScm/
│   ├── CMakeLists.txt            # registers project-wide dirs
│   └── Components/
│       └── CMakeLists.txt        # list SCM components here; register the deployment here too
├── lib/                          # git submodules (populated by `make setup`)
│   ├── fprime/                   # the F´ framework            (v4.3.0)
│   ├── fprime-arduino/           # the ArduinoFw platform + arduino-cli glue + ATmega drivers
│   └── fprime-baremetal/         # no-OS scheduler / Os / base config to reduce RAM
└── fprime-venv/                  # Python venv + arduino-cli  (GIT-IGNORED, regenerated locally)
```

### Why `fprime-venv/` is not in git

It never is, and never should be. A virtualenv bakes absolute paths into
`bin/activate`, `pyvenv.cfg`, and every script shebang, so it cannot be moved
between machines. It is **regenerated per machine** by `make setup`
(`/fprime-venv/` is listed in `.gitignore`). If you cloned this repo and there is
no `fprime-venv/`, that is expected — run `make setup`.

---

## Submodules — what each one provides

| Submodule | Role |
|---|---|
| `lib/fprime` (`v4.3.0`) | The framework: `Fw/`, `Svc/`, `Drv/`, `Os/`, the FPP autocoder, and the `cmake/` build system (`FPrime.cmake`) that `fprime-util` drives. |
| `lib/fprime-arduino` | The **`ArduinoFw` platform** (`cmake/platform/ArduinoFw.cmake`), the per-board toolchains under `cmake/toolchain/`, the shared `cmake/toolchain/support/arduino-support.cmake` that runs `arduino-cli` to detect AVR-GCC and build the Arduino core, plus ATmega components/OS shims (`ATmegaOs`, `ATmegaTypes`, `ATmegaGpioDriver`, `ATmegaI2cDriver`, `ATmegaSerialDriver`, `ATmegaSpiDriver`, `ATmegaAdcDriver`, `ATmegaTime`, …). Its own `requirements.txt` pins `arduino-cli-cmake-wrapper`. |
| `lib/fprime-baremetal` | No-OS building blocks to shrink RAM: the baremetal scheduler (selected by the toolchain), baremetal `Os` implementations, optional `new`/`delete` accounting, the `baremetal-size` utility, and a `BASE_CONFIG` module (`MicroFsCfg.hpp`) that is auto-registered because the folder is on `library_locations`. |

`git submodule update --init --recursive` (run for you by `make setup`) also pulls
`lib/fprime`'s own nested submodules.

---

## `settings.ini`

```ini
[fprime]
project_root: .
framework_path: ./lib/fprime
library_locations: ./lib/fprime-arduino:./lib/fprime-baremetal
default_toolchain: atmega2560
deployment_cookiecutter: https://github.com/fprime-community/fprime-arduino-deployment-cookiecutter.git
default_cmake_options:  FPRIME_ENABLE_FRAMEWORK_UTS=OFF
                        FPRIME_ENABLE_AUTOCODER_UTS=OFF
```

| Key | Meaning |
|---|---|
| `project_root` | Root all other relative paths resolve against (`.` = this dir). |
| `framework_path` | Where the F´ framework lives — the `lib/fprime` submodule. |
| `library_locations` | Colon-separated roots F´ scans for `library.cmake` and `cmake/toolchain/`. This is what makes fprime-arduino and fprime-baremetal visible to the build. |
| `default_toolchain` | Toolchain used when `fprime-util generate`/`build` is run with no name — `atmega2560` → `cmake/toolchain/atmega2560.cmake`. |
| `deployment_cookiecutter` | Template `fprime-util new --deployment` uses — the fprime-arduino deployment cookiecutter, which generates a `Top/` topology, `Main.cpp`, **and the deployment's own `config/`** (`FpConfig.h`, `AcConstants.fpp`, …). Config is per-deployment here, not set globally via `config_directory`. |
| `default_cmake_options` | Disable framework + autocoder unit tests (not built for a cross target). |

> This mirrors the [fprime-arduino LedBlinker tutorial](https://github.com/fprime-community/fprime-tutorial-arduino-blinker)'s `settings.ini` (which also omits `config_directory`), with `atmega2560` swapped in for its `teensy41`.

---

## The toolchain — how a build reaches AVR-GCC

`cmake/toolchain/atmega2560.cmake` is the pivot. `fprime-util generate atmega2560`
finds it (a project-local toolchain wins over the copies in the libraries),
passes it to CMake as `CMAKE_TOOLCHAIN_FILE`, and it:

1. sets `CMAKE_SYSTEM_NAME=Generic`, `CMAKE_SYSTEM_PROCESSOR=avr`,
   `FPRIME_PLATFORM=ArduinoFw`, `FPRIME_USE_BAREMETAL_SCHEDULER=ON`;
2. sets `ARDUINO_FQBN=MegaCore:avr:2560`,
   `ARDUINO_BOARD_OPTIONS=clock=16MHz_external`, `-DATMEGA`,
   and LTO build flags;
3. `include()`s `lib/fprime-arduino/cmake/toolchain/support/arduino-support.cmake`,
   which shells out through **`arduino-cli-cmake-wrapper` → `arduino-cli`** to
   (a) detect the AVR toolchain binaries, flags, and include paths and give them
   to CMake, and (b) compile the Arduino core + any requested `arduino-cli`
   libraries and link them into the final `.elf`.

`ArduinoFw.cmake` then adds the platform `StandardTypes`. So three things must be
in place before `make build`:

- **`fprime-venv`** — provides `fprime-util`, `cmake`, and `arduino-cli-cmake-wrapper`
  (`make setup`);
- **`arduino-cli` on `PATH`** — installed into `fprime-venv/bin` (`make setup-arduino`);
- **the `MegaCore:avr` core + the `Time` library** — installed via `arduino-cli`
  (`make setup-arduino`).

> Keep the `../../lib/fprime-arduino` path inside `atmega2560.cmake` in sync with
> the `lib/fprime-arduino` submodule path in `.gitmodules`.
>
> Stock-core alternative to MegaCore: set `ARDUINO_FQBN "arduino:avr:mega"`, drop
> `ARDUINO_BOARD_OPTIONS`, and `arduino-cli core install arduino:avr` instead.

---

## Library / deployment CMake

The include chain is:

```
CMakeLists.txt
  include(lib/fprime/cmake/FPrime.cmake)     # F´ core + build system
  fprime_setup_included_code()
  add_fprime_subdirectory(FprimeArduinoBilleeScm)
      └── FprimeArduinoBilleeScm/CMakeLists.txt
            add_fprime_subdirectory(Components)
                └── Components/CMakeLists.txt   # <-- add components + the deployment here
```

- Each **component** is a directory with a `.fpp` model + `.cpp`, listed here with
  `add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/<Name>")` and registered
  inside its own `CMakeLists.txt` via `register_fprime_module`.
- The **deployment** (the thing that actually links to an `.elf`) is a directory
  with a `Top/` topology and `Main.cpp`, registered with
  `register_fprime_executable` (or `register_fprime_deployment`), and added from
  `Components/CMakeLists.txt` or `FprimeArduinoBilleeScm/CMakeLists.txt`.

There is **no deployment yet** — see next section.

---

## `requirements.txt`

`make setup` installs the Python deps **into `fprime-venv`** in two passes (after
`git submodule update --init --recursive` has populated `lib/`):

1. `pip install -r requirements.txt` → `-r ./lib/fprime/requirements.txt`
   (fprime-tools, fpp, fprime-gds, `cmake==3.26.0`, ninja, …).
2. `pip install -r lib/fprime-arduino/requirements.txt`
   (`arduino-cli-cmake-wrapper==0.2.0a1`, `cmake>=3.26.4`).

Two passes because a single resolve of both files fails: `lib/fprime` pins
`cmake==3.26.0` while `lib/fprime-arduino` requires `cmake>=3.26.4`. Installed in
sequence the newer `cmake` wins and `pip check` stays clean. (If a CMake 4.x
regression bites, pin `cmake~=3.31` in a `constraints.txt` and
`pip install -c constraints.txt ...`.)

---

## Make targets

| Target | What it does |
|---|---|
| `make help` | List targets (default). |
| `make setup` | `python3 -m venv fprime-venv`, `git submodule update --init --recursive`, then `pip install` the framework then fprime-arduino requirements into the venv (two passes — see below). |
| `make setup-arduino` | Download `arduino-cli` into `fprime-venv/bin`, `arduino-cli config init`, add the MegaCore board-manager URL, `core install MegaCore:avr`, `lib install Time`. |
| `make generate` | `fprime-util generate atmega2560` (needs a deployment). |
| `make build` | `fprime-util build atmega2560` (needs a deployment). |
| `make clean` | `fprime-util purge --force` + remove `build-*` / `build-artifacts`. |

Override the target board with `make build TOOLCHAIN=<name>`.

---

## First-time setup

Prerequisites: Python 3.9+, `git`, `curl`, and internet access. On WSL, uploading
to the board later also needs `usbipd` (see fprime-arduino's
[`docs/arduino-cli-install.md`](https://github.com/fprime-community/fprime-arduino/blob/main/docs/arduino-cli-install.md)).

```bash
make setup           # fprime-venv + submodules + Python deps
make setup-arduino   # arduino-cli + MegaCore:avr core + Time library
```

---

## Next steps — getting the framework to run

1. **Create a deployment.** From inside `FprimeArduinoBilleeScm/`:
   ```bash
   ../fprime-venv/bin/fprime-util new --deployment
   ```
   This pulls the `deployment_cookiecutter` from `settings.ini` and generates a
   `Top/` topology, `Main.cpp`, and the deployment's own `config/`. Keep it
   minimal — on 8 KB SRAM, start from fprime-arduino's `LedBlinker` topology,
   **not** the full CDH stack.
2. **Register it** in CMake (see "Library / deployment CMake").
3. **Wire `Main.cpp`** to the baremetal main loop: build the topology in `setup()`,
   then cycle the baremetal scheduler + hardware rate driver in `loop()` / a bare
   `while (true)`. Use fprime-arduino's `ATmegaSerialDriver` for the ground link
   and `ATmegaTime` for the time base.
4. **Build:**
   ```bash
   make generate
   make build
   ```
   Output lands in `build-fprime-automatic-atmega2560/` and
   `build-artifacts/atmega2560/` (`.elf`, plus a MegaCore `.hex`).
5. **Check RAM fits:**
   ```bash
   fprime-venv/bin/baremetal-size atmega2560
   ```
   Trim the deployment's `config/` values and component queue/buffer depths until
   `.bss` fits in 8 KB.
6. **Upload + GDS** (not handled by this repo — pointers only): `arduino-cli
   upload` with FQBN `MegaCore:avr:2560` and the board's serial port, then run
   `fprime-gds` against that same serial port. See fprime-arduino's
   [`docs/arduino-cli-install.md`](https://github.com/fprime-community/fprime-arduino/blob/main/docs/arduino-cli-install.md)
   and [`docs/board-list.md`](https://github.com/fprime-community/fprime-arduino/blob/main/docs/board-list.md).

---

**F´ website:** https://fprime.jpl.nasa.gov &nbsp;·&nbsp;
**fprime-arduino:** https://github.com/fprime-community/fprime-arduino
