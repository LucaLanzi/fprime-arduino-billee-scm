# FprimeArduinoBilleeScm

F´ (F Prime) firmware project for the **BILLEE Science Control Module (SCM)**,
cross-compiled for a **Teensy 4.1** (NXP **iMXRT1062**, ARM Cortex-M7,
600 MHz, 1024 KB RAM, 8 MB flash) through NASA JPL's
[fprime-arduino](https://github.com/fprime-community/fprime-arduino) `ArduinoFw`
platform.

> This project previously targeted an Arduino Mega 2560 (ATmega2560, AVR).
> That path required hand-writing a full C++ standard library (no AVR
> toolchain ships `avr-libstdc++`) and manually shrinking F´'s default
> buffer/table sizes to fit 8 KB of SRAM — and even then, some F´ core
> content (`Svc::FpySequencer`) turned out to assume more RAM than an 8-bit
> AVR has at all. Teensy 4.1 is in fprime-arduino's own
> [tested board list](https://github.com/fprime-community/fprime-arduino/blob/main/docs/board-list.md),
> uses a real hosted-class `arm-none-eabi-gcc` toolchain with full
> `libstdc++`, and has roughly 128,000× the RAM — none of the AVR-era
> workarounds apply here.

---

## Repository layout

```
fprime-arduino-billee-scm/
├── CMakeLists.txt                 # project build entry — pulls in F´ core, then this project
├── settings.ini                  # F´ project settings (paths, libraries, default toolchain)
├── requirements.txt               # Python deps installed INTO fprime-venv (never system-wide)
├── Makefile                      # bootstrap + build wrappers (see "Make targets")
├── CMakePresets.json             # IDE/CMake presets that point at ./fprime-venv
├── .clang-format                 # Chromium-based, 4-space, 120 col
├── uart_gds.sh                   # local GDS launcher, port 5001 (see "Running fprime-gds")
├── lan_uart_gds.sh               # same, web UI bound to 0.0.0.0 for LAN access
├── gds-run-loop.sh               # runs lan_uart_gds.sh forever, retrying on exit
├── install-lan-gds-service.sh    # installs the billee-scm-lan-gds systemd service
├── FprimeArduinoBilleeScm/
│   ├── CMakeLists.txt            # registers project-wide dirs + the deployment
│   ├── Components/               # project-wide components, shared across deployments
│   └── billee_deployment/        # the deployment (Top/ topology, Main.cpp, config/)
├── lib/                          # git submodules (populated by `make setup`)
│   ├── fprime/                   # the F´ framework            (pinned to v4.1.1 — see below)
│   ├── fprime-arduino/           # the ArduinoFw platform + arduino-cli glue + Teensy support
│   └── fprime-baremetal/         # no-OS scheduler / Os implementations (pinned — see below)
└── fprime-venv/                  # Python venv + arduino-cli  (GIT-IGNORED, regenerated locally)
```
---

## Submodules — what each one provides, and why the versions are pinned where they are

| Submodule | Pinned at | Role |
|---|---|---|
| `lib/fprime` | **`v4.1.1`** | The framework: `Fw/`, `Svc/`, `Drv/`, `Os/`, the FPP autocoder, and the `cmake/` build system. |
| `lib/fprime-arduino` | current HEAD | The **`ArduinoFw` platform** (`cmake/platform/ArduinoFw.cmake`), the per-board toolchains under `cmake/toolchain/` (including `teensy41.cmake`), the shared `cmake/toolchain/support/arduino-support.cmake` that runs `arduino-cli` to detect `arm-none-eabi-gcc` and build the Teensy core, plus the board-generic `Arduino/` components/drivers. |
| `lib/fprime-baremetal` | a commit pinned just before [`Make Task compatible with 4.2.0` (#33)](https://github.com/fprime-community/fprime-baremetal) | No-OS building blocks: the baremetal scheduler, baremetal `Os` implementations, `new`/`delete` accounting, a `BASE_CONFIG` module auto-registered via `library_locations`. |

**Why `lib/fprime` is pinned to v4.1.1, not the latest tag.** `lib/fprime-arduino`'s
current submodule HEAD is a commit literally titled *"Upgrade to support
fprime v4.1.1 (#54)"* — it was authored and tested against that exact F´
version. This project originally pinned `lib/fprime` to a much newer tag
(v4.3.0, ~8 months later), and every non-cookiecutter compile error hit while
porting to AVR turned out to be pure version skew between the two, not a
board problem:

| Symptom | Root cause |
|---|---|
| `Os::RawTimeInterface::getDelegate` signature mismatch (fprime-arduino provides 2 params, F´ core wants 3) | F´ core added the 3rd param in a commit that only exists in v4.3.0+, not v4.1.1 |
| `Fw::StringScan`/`Os::CountingSemaphore` implementations never selected | Neither interface exists yet at v4.1.1 — nothing to select |
| `Os::TaskInterface::_delay` override mismatch (value vs. const-reference) | `fprime-baremetal`'s HEAD was updated for F´ 4.2.0's interface change; pinned back one commit, it matches v4.1.1's by-value signature exactly |

Pinning both submodules to the versions they were actually built against
eliminated all three outright — **zero patches to either submodule are
needed**; `git -C lib/fprime-arduino status` and `git -C lib/fprime-baremetal
status` both stay clean. If you ever bump `lib/fprime` forward, expect these
exact classes of error to resurface and re-check both submodules' own commit
history for a matching "upgrade to fprime vX.Y" commit before patching
anything by hand.

`git submodule update --init --recursive` (run for you by `make setup`) also
pulls `lib/fprime`'s own nested submodules.

---

## `settings.ini`

```ini
[fprime]
project_root: .
framework_path: ./lib/fprime

library_locations: ./lib/fprime-arduino:./lib/fprime-baremetal

default_toolchain: teensy41

deployment_cookiecutter: https://github.com/LucaLanzi/fprime-arduino-deployment-cookiecutter.git

default_cmake_options:  FPRIME_ENABLE_FRAMEWORK_UTS=OFF
                        FPRIME_ENABLE_AUTOCODER_UTS=OFF
```

| Key | Meaning |
|---|---|
| `project_root` | Root all other relative paths resolve against (`.` = this dir). |
| `framework_path` | Where the F´ framework lives — the `lib/fprime` submodule. |
| `library_locations` | Colon-separated roots F´ scans for `library.cmake` and `cmake/toolchain/`. This is what makes fprime-arduino and fprime-baremetal visible to the build. |
| `default_toolchain` | Toolchain used when `fprime-util generate`/`build` is run with no name — `teensy41` → `lib/fprime-arduino/cmake/toolchain/teensy41.cmake`. There is no project-local toolchain override file; fprime-arduino's own file handles this board correctly as-is (see below). |
| `deployment_cookiecutter` | Template `fprime-util new --deployment` uses — a fork of the upstream community template with two config-generation bugs fixed. See "Deployment config overrides" below for why. |
| `default_cmake_options` | Disable framework + autocoder unit tests (not built for a cross target). |

---

## The toolchain — how a build reaches `arm-none-eabi-gcc`

Unlike the old AVR path, there is **no project-local `cmake/toolchain/`
file** for this board. `lib/fprime-arduino/cmake/toolchain/teensy41.cmake`
handles everything correctly on its own:

1. sets `CMAKE_SYSTEM_NAME=Generic`, `CMAKE_SYSTEM_PROCESSOR=arm`,
   `FPRIME_PLATFORM=ArduinoFw`, `FPRIME_USE_BAREMETAL_SCHEDULER=ON`;
2. sets `ARDUINO_FQBN=teensy:avr:teensy41` (no configurable board options —
   Teensy 4.1's clock/etc. are fixed by the core, unlike AVR's
   `clock=16MHz_external`);
3. `include()`s the same shared `arduino-support.cmake` every board in this
   repo uses, which shells out through `arduino-cli-cmake-wrapper` →
   `arduino-cli` to detect the toolchain and build the Teensy core.

`ArduinoFw.cmake` then adds the platform types from
`cmake/platform/arm/Platform/`, which — checked directly — registers **zero**
C++ standard-library shim headers, unlike the AVR-facing
`cmake/platform/basic/Platform/`'s twelve. `arm-none-eabi-gcc` ships real
`libstdc++`; F´ core's `#include <cstddef>`, `<type_traits>`, `<atomic>`, etc.
all resolve normally. There is no `avr-cxx-shim/` directory in this project
anymore, and no compiler-routing/STDC-macro/`-mdouble=64` block in a
project-local toolchain file, because none of it is needed.

Three things must be in place before `make build`:

- **`fprime-venv`** — provides `fprime-util`, `cmake`, and `arduino-cli-cmake-wrapper`
  (`make setup`);
- **`arduino-cli` on `PATH`** — installed into `fprime-venv/bin` (`make setup-arduino`);
- **the `teensy:avr` board package** — installed via `arduino-cli`
  (`make setup-arduino`), from PJRC's own board-manager index
  (`https://www.pjrc.com/teensy/package_teensy_index.json` — Teensy isn't in
  arduino-cli's default index).

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
            add_fprime_subdirectory(billee_deployment)
                └── billee_deployment/CMakeLists.txt   # the deployment itself
```

- Each **component** is a directory with a `.fpp` model + `.cpp`, added under
  `FprimeArduinoBilleeScm/Components/` and registered via
  `register_fprime_module` in its own `CMakeLists.txt`.
- **`billee_deployment`** (the thing that actually links to an `.elf`) has a
  `Top/` topology and `Main.cpp`, registered with `register_fprime_deployment`.

### Three things `billee_deployment/CMakeLists.txt` does that aren't obvious from the cookiecutter output

1. **A sub-build guard fix.** `arduino-support.cmake`'s
   `finalize_arduino_executable()` calls `setup_arduino_libraries()` before
   checking whether this is F´'s lightweight sub-build info-cache pass — and
   even that check is broken (it tests a misspelled variable name that never
   matches F´ core's real one), so it can never fire on any board or F´
   version. `billee_deployment/CMakeLists.txt` does the correct check itself,
   first, plus defines a placeholder `__fprime_config` target so
   `setup_arduino_libraries()`'s `add_dependencies()` call has something real
   to point at (the actual config content still comes from F´'s real
   `default_config` target). This is project-level CMake, not a submodule
   edit — independent of board and F´ version.
2. **Extra include roots for the nested deployment path.** The
   `fprime-arduino-deployment-cookiecutter` template writes `#include
   "billee_deployment/Top/X.hpp"`-style paths, assuming — as F´ deployments
   normally do — that the deployment sits directly under `project_root`. This
   repo's layout nests it one level deeper
   (`FprimeArduinoBilleeScm/billee_deployment/`), so
   `include_directories("${CMAKE_CURRENT_LIST_DIR}/.."
   "${CMAKE_CURRENT_BINARY_DIR}/..")` is added explicitly rather than
   restructuring the project to match the cookiecutter's assumption.
3. **`CONFIGURATION_OVERRIDES`** in `billee_deployment/config/CMakeLists.txt`
   fix a handful of bugs in the cookiecutter's generated `config/` files —
   see the next section.

---

## Deployment config overrides — what's real, and what's cookiecutter noise

`billee_deployment/config/CMakeLists.txt` registers several
`CONFIGURATION_OVERRIDES`. Two categories, worth telling apart:

**Three upstream cookiecutter bugs — fixed at the template level, in a fork
we control, not re-fixed by hand in this project's files:**

`settings.ini`'s `deployment_cookiecutter` points at
[`LucaLanzi/fprime-arduino-deployment-cookiecutter`](https://github.com/LucaLanzi/fprime-arduino-deployment-cookiecutter),
a fork of the upstream community template
(`fprime-community/fprime-arduino-deployment-cookiecutter`), not the upstream
repo itself. The fork's `main` branch has commits on top of upstream that fix
three bugs, all confirmed independent of F´ version (checked against v4.1.1
and v4.3.0) and of target board — I checked upstream's entire commit history
and live tip directly and none has ever been fixed there, and its only tag
(`v3.5.1`) predates the `config/` folder existing at all, so there was no
existing version to pin to instead of forking:

- `config/FpConfig.h`: the cookiecutter's generated file `#define`s ~36
  constants (buffer sizes, OS handle sizes, `FW_CONTEXT_DONT_CARE`, etc.)
  that are *also* declared as FPP `constant`s in F´ core
  (`lib/fprime/default/config/{FpConstants,PlatformCfg}.fpp`), autocoded into
  a real `enum`. Defining the same name both ways makes the preprocessor
  blindly substitute the macro's value into the enum's own initializer
  wherever both headers land in one translation unit (e.g. `enum {
  FW_COM_BUFFER_MAX_SIZE = 512 }` becomes `enum { 128 = 512 }`) — a hard
  syntax error, not a value conflict an `#ifndef` guard can resolve (an
  enumerator isn't a macro, so it's invisible to `#ifndef` regardless of
  include order). All ~36 are simply removed in the fork; the framework's
  own default sizes provide them.
- `config/ComCcsdsConfig/ComCcsdsConfig.fpp`: the cookiecutter's version
  omits `QueueSizes.aggregator`/`StackSizes.aggregator`, which
  `Svc/Subtopologies/ComCcsds/ComCcsds.fpp` requires unconditionally. Added
  in the fork.
- `config/ComCcsdsConfig/ComCcsdsConfig.fpp`: `BuffMgr.commsBuffSize` was set
  to `140`, far smaller than F´ core's own default of `2048`
  (`Svc/Subtopologies/ComCcsds/ComCcsdsConfig/ComCcsdsConfig.fpp`).
  `Svc::Ccsds::SpacePacketFramer::dataIn_handler` allocates exactly
  `SpacePacketHeader::SERIALIZED_SIZE + data.getSize()` bytes from this
  buffer bin per outgoing frame — at 140 bytes, any single frame larger than
  that (even a small burst of boot-time diagnostic events) overruns the
  buffer and hits `FW_ASSERT(status == Fw::FW_SERIALIZE_OK, status)` with
  `FW_SERIALIZE_NO_ROOM_LEFT`. **This one doesn't just fail to build — it
  builds and flashes fine, then crashes and reboots the board in a loop the
  moment it tries to downlink its first real frame**, which looks exactly
  like a ground-station/comm-channel connection problem (`fprime-gds` opens
  the serial port fine but can never hold a stable connection) rather than
  what it actually is: confirmed by capturing the board's own crash output
  directly over its serial port mid-loop. Restored to match F´ core's own
  default value in the fork.

Because `fprime-tools`' cookiecutter integration (`fprime.util.cookiecutter_wrapper`)
never passes cookiecutter a `checkout` ref — it always clones/reuses whatever
sits on `deployment_cookiecutter`'s URL's default branch — there's no way to
pin a specific tag/commit through `settings.ini` alone. The fork's `main`
branch stands in for that pin instead: nobody else pushes to it, so it only
changes when this project deliberately changes it. Regenerating
`billee_deployment/` from scratch today would come out with all three fixes
already applied, no hand-editing needed.

**A genuine, non-cookiecutter, non-RAM fix:**
- `config/PlatformCfg.fpp`: overrides `FW_FILE_HANDLE_MAX_SIZE` (16→32) and
  `FW_DIRECTORY_HANDLE_MAX_SIZE` (16→48). This isn't about RAM — Teensy 4.1
  has plenty. `Os::Arduino::ArduinoFile`/`ArduinoDirectory` (the SD-card-backed
  `Os::File`/`Os::Directory` implementation fprime-arduino provides, compiled
  here regardless of this deployment's own "no filesystem" choice — F´
  compiles every registered `Os` implementation as its own library whether
  it's linked into the final executable or not) hold a real Arduino SD-library
  `File` object, which doesn't fit in the framework default's 16 bytes
  (`Os::Delegate`'s `"Handle size not large enough"` static_assert fires
  otherwise). This applies to any Arduino-family board using the SD-backed
  file implementation, not just Teensy.

If you ever regenerate `billee_deployment/` from the cookiecutter again, the
fork's two fixes come along automatically — but still verify the
`PlatformCfg.fpp` handle-size override below, since that one is deliberately
*not* part of the fork (it's a fix specific to using the SD-backed file
implementation, not something every user of the template needs).

---

## Working with the IO pins — GPIO, I2C, SPI, analog, PWM

`lib/fprime-arduino/Arduino/Drv/` ships board-generic driver components —
they use plain Arduino-core calls (`pinMode`, `TwoWire`, `SPIClass`,
`analogRead`/`analogWrite`) that compile against whatever `Arduino.h`/
`Wire.h`/`SPI.h` the board package provides, so they work unmodified on
Teensy 4.1. Instantiate one in a component's topology, then configure it by
calling `open()` (or the port-specific setup call) once, typically from your
topology's config phase or the component's own `init()`.

- **`Arduino::GpioDriver`** — `open(FwIndexType pin, GpioDirection direction)`,
  where `direction` is `Arduino::GpioDriver::IN` or `::OUT` and `pin` is a
  plain Teensy pin number (e.g. `2`). Exposes `gpioWrite`/`gpioRead` sync
  ports (`Drv.GpioWrite`/`Drv.GpioRead`).
- **`Arduino::I2cDriver`** — `open(TwoWire* wire)`. Teensy 4.1 has **three**
  hardware I2C buses: pass `&Wire`, `&Wire1`, or `&Wire2`. Exposes a
  `Drv.I2c` port.
- **`Arduino::SpiDriver`** — `open(SPIClass* spi, SpiFrequency clock,
  FwIndexType ss_pin, SpiMode spiMode = ..., SpiBitOrder bitOrder = ...)`.
  Teensy 4.1 has **three** hardware SPI buses: pass `&SPI`, `&SPI1`, or
  `&SPI2`. Chip-select is bit-banged via `digitalWrite` on `ss_pin`, not a
  hardware CS line. Exposes a `Drv.Spi` port.
- **`Arduino::AnalogDriver`** — `open(FwIndexType pin, GpioDirection
  direction)`, ports `setAnalog`/`readAnalog` (write 0–255 scaled internally;
  read range depends on ADC resolution — 10-bit by default unless
  `analogReadResolution()` is called elsewhere).
- **`Arduino::PwmDriver`** — `open(FwIndexType gpio)`, port `setDutyCycle`
  (U8 0–100%, scaled to `analogWrite(pin, 255 * pct / 100)` internally).

**One thing that's automatic, not something you configure**:
`Arduino::HardwareRateDriver` auto-selects `HardwareRateDriverTeensy.cpp`
(driving the base rate group off a hardware timer ISR via Teensyduino's
`IntervalTimer`) based on `ARDUINO_FQBN` starting with `teensy` — no
deployment-level change needed, just be aware the rate-group clock source is
a real hardware timer on this board, not the software-loop timing a
`basic`/AVR-class board would use.

---

## Make targets

| Target | What it does |
|---|---|
| `make help` | List targets (default). |
| `make setup` | `python3 -m venv fprime-venv`, `git submodule update --init --recursive`, then `pip install` the framework then fprime-arduino requirements into the venv (two passes — see below). |
| `make setup-arduino` | Install `arduino-cli` into `fprime-venv/bin`, add PJRC's board-manager URL, `core install teensy:avr@1.59.0`, `lib install Time`. |
| `make generate` | `fprime-util generate teensy41` (needs a deployment — already created, see below). |
| `make build` | `fprime-util build teensy41`. |
| `make clean` | `fprime-util purge --force` + remove `build-*` / `build-artifacts`. |
| `make gds` | Start GDS locally against the board (`uart_gds.sh`, port 5001). `make gds mac` uses `MAC_UART_DEVICE`. |
| `make install-gds-service` | Install the `billee-scm-lan-gds` systemd service (headless Jetson, LAN-reachable, auto-retry). |
| `make uninstall-gds-service` | Disable and remove that service. |
| `make gds-service-status` | `systemctl status` + recent logs for the service. |
| `make gds-attach` | Attach to the service's detached `screen` session. |

Override the target board with `make build TOOLCHAIN=<name>`.

---

## First-time setup

Prerequisites: Python 3.9+, `git`, `curl`, and internet access. On WSL, uploading
to the board later also needs `usbipd` (see fprime-arduino's
[`docs/arduino-cli-install.md`](https://github.com/fprime-community/fprime-arduino/blob/main/docs/arduino-cli-install.md)).

```bash
make setup           # fprime-venv + submodules + Python deps
make setup-arduino   # arduino-cli + teensy:avr core + Time library
```

### If `pip install -r requirements.txt` fails on `pyzmq`

`lib/fprime`'s `requirements.txt` pins an exact `pyzmq` version that may
predate prebuilt wheels for very new Python releases, and building it from
source can fail against a modern `scikit-build-core`. If you hit this,
install the three F´ tool packages directly with `--no-deps` (they don't
need `pyzmq`'s functionality for `fprime-util generate`/`build`, only its own
transitive pin was blocking the install) and, separately, make sure
`setuptools<81` is installed (very recent `setuptools` dropped bundling
`pkg_resources`, which the pinned `fprime-tools` still imports):

```bash
pip install "setuptools<81"
pip install --no-deps fprime-tools==4.1.0 fprime-gds==4.1.0 fprime-fpp==3.1.0
```

Because this installs `fprime-gds` with `--no-deps`, its own dependencies
(beyond the three pinned tool packages themselves) aren't pulled in either.
`pyserial` happens to already be present transitively, but `crc` (used by
`fprime-gds`'s default CCSDS space-packet framer) is not — without it,
`fprime-gds` fails immediately with `ModuleNotFoundError: No module named
'crc'`. Install it once, separately:

```bash
pip install crc
```

---

## Building the deployment

The deployment already exists at `FprimeArduinoBilleeScm/billee_deployment/`.
To build:

```bash
make generate
make build
```

Output lands in `build-fprime-automatic-teensy41/` and
`build-artifacts/teensy41/` (`.elf`, plus the Teensy `.hex`). The build's own
post-link step prints a memory summary — expect flash usage in the low
hundreds of KB (of 8 MB) and RAM usage well under 1 MB; there is no
meaningful size pressure on this target the way there was on AVR.

To regenerate the deployment from scratch (e.g. to change the communication
driver, filesystem, or framing protocol choice):

```bash
cd FprimeArduinoBilleeScm
../fprime-venv/bin/fprime-util new --deployment
```

then re-check the config overrides described above against the fresh output.

---

## Upload + flashing

There is no `arduino-cli upload` step — flashing is folded into the build's
own post-link hook, which runs the Teensy board package's bundled
`teensy_post_compile`/`teensy_reboot` tools. After `make build`, the
**Teensyduino Loader** GUI application should auto-launch, pre-loaded with
the just-built `.hex` from
`build-artifacts/teensy41/FprimeArduinoBilleeScm_billee_deployment/bin/`. If
it doesn't appear, open it manually and point it at that file. Flashing
itself requires a **physical press of the reset button on the board** —
Teensy 4.1 doesn't reboot into the bootloader from software alone.

**Linux only**: copy fprime-arduino's udev rule so your user can access the
board without root:

```bash
sudo cp lib/fprime-arduino/docs/rules/00-teensy.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

**macOS**: no extra driver needed — Teensy 4.x uses native USB CDC/HID.

See fprime-arduino's
[`docs/uploading/teensy.md`](https://github.com/fprime-community/fprime-arduino/blob/main/docs/uploading/teensy.md)
for the canonical version of the flashing instructions above.

---

## Running `fprime-gds` against the board

`billee_deployment/Top/billee_deploymentTopology.cpp` wires `comDriver`
(`Arduino.StreamDriver`) to `&Serial` — Teensy 4.1's native USB serial port —
so the same USB cable used to flash the board also carries F´'s CCSDS comm
traffic once it's running. There's no separate radio/UART cable needed on
the bench: GDS talks to the board over USB directly.

Four scripts handle this, mirrored from the same pattern
[`fprime-billee-rcm`](../fprime-billee-rcm) uses — the two projects are meant
to run side by side on the same Jetson, each with its own GDS dashboard:

| Script | Purpose |
|---|---|
| [`uart_gds.sh`](uart_gds.sh) | Local launcher — verifies the venv has `fprime-gds`, the dictionary exists, and the serial device is a character device, then starts GDS with no local deployment executable, UART comm, and CCSDS framing. |
| [`lan_uart_gds.sh`](lan_uart_gds.sh) | Same launcher, web UI bound to `0.0.0.0` for LAN access (headless Jetson you reach from another machine). |
| [`gds-run-loop.sh`](gds-run-loop.sh) | Runs `lan_uart_gds.sh` forever, retrying 10s after any exit. |
| [`install-lan-gds-service.sh`](install-lan-gds-service.sh) | Installs `screen` + the `billee-scm-lan-gds` systemd service (`make install-gds-service`). |

**Port 5001, not `fprime-gds`'s own default of 5000** — both scripts pass
`--gui-port 5001` explicitly (override with `GDS_FLASK_PORT=<port>`).
`fprime-billee-rcm`'s equivalent scripts default to port 5000, and since both
deployments run on the same Jetson, they'd otherwise collide on the same
dashboard port. With this split, both are reachable side by side from one
browser: `http://<jetson-ip>:5000` for the rover (fprime-billee-rcm) and
`http://<jetson-ip>:5001` for this Science Control Module deployment.

### Quick start — local (Mac or native Linux)

```bash
make gds            # Linux: defaults UART_DEVICE to /dev/ttyACM0
make gds mac         # macOS: uses MAC_UART_DEVICE (see Makefile, override if yours differs)
```

`uart_gds.sh` verifies the venv has `fprime-gds`, the generated dictionary
exists, and the serial device is a character device, then starts GDS with no
local deployment executable, the generated dictionary, UART communication,
and `space-packet-space-data-link` CCSDS framing — opening its dashboard at
`http://127.0.0.1:5001`.

To find the device path first, see [Running fprime-gds against the
board](#running-fprime-gds-against-the-board) below, or just:
```bash
ls /dev/cu.usbmodem*        # macOS
ls /dev/ttyACM*             # Linux
```

### Run GDS as a service (headless Jetson)

`make install-gds-service` installs a systemd service that runs
`lan_uart_gds.sh` at every boot inside a **detached `screen` session**, so the
GDS comes up unattended and you can attach to it live over SSH — same
mechanism `fprime-billee-rcm` uses, distinct service name
(`billee-scm-lan-gds` vs. `billee-lan-gds`) so both can run at once.

```bash
make install-gds-service     # sudo; run from your normal account (needs $SUDO_USER)
```

What it does ([`install-lan-gds-service.sh`](install-lan-gds-service.sh)):

- `apt-get install screen` if it isn't already present.
- Writes `/etc/systemd/system/billee-scm-lan-gds.service`, running
  `screen -DmS billee-scm-lan-gds gds-run-loop.sh` as your user, in the
  `dialout` group, after `network-online.target`, then
  `systemctl enable --now`.
- [`gds-run-loop.sh`](gds-run-loop.sh) runs `lan_uart_gds.sh` in a loop: on
  any exit — board unplugged, missing build, crash — it waits **10 s**
  (`GDS_RETRY_SECONDS`) and starts it again. `Restart=always` /
  `RestartSec=10` in the unit is a backstop if `screen` itself dies.

Managing it:

| Command | Purpose |
| --- | --- |
| `make gds-attach` | Attach to the live `screen` session (`Ctrl-A` then `D` to detach) |
| `make gds-service-status` | `systemctl status` + recent `journalctl` lines |
| `sudo systemctl stop billee-scm-lan-gds` | Stop it (stays enabled for next boot) |
| `make uninstall-gds-service` | Disable and remove the unit |

Run `screen -r billee-scm-lan-gds` as the same user the service runs as.

### Manual invocation (what the scripts do, unwrapped)

1. Find the device path (after the board is flashed and running):
   ```bash
   ls /dev/cu.usbmodem*        # macOS
   ls /dev/ttyACM*             # Linux
   ```
2. Launch GDS, pointed at the build's generated dictionary, with `-n` so it
   doesn't try to launch a native binary (there isn't one to run — the
   deployment is already running on the board), and `--communication-selection
   uart` since GDS defaults to its `ip` adapter otherwise:
   ```bash
   fprime-gds -n \
       --dictionary build-artifacts/teensy41/FprimeArduinoBilleeScm_billee_deployment/dict/billee_deploymentTopologyDictionary.json \
       --communication-selection uart \
       --uart-device /dev/cu.usbmodem123456701 \
       --uart-baud 115200 \
       --gui-port 5001
   ```
   Replace `--uart-device` with whatever step 1 printed. `115200` matches
   `Main.cpp`'s `Serial.begin(115200)` — Teensy's port is native USB CDC, so
   the OS mostly ignores the actual baud value, but `fprime-gds` still
   requires one be passed.
3. GDS opens its web GUI at `http://127.0.0.1:5001` once connected, showing
   live telemetry/events and letting you dispatch commands to the running
   deployment. Add `--gui-addr 0.0.0.0` (what `lan_uart_gds.sh` does) to make
   it reachable from another machine on the LAN instead.

### Board unreachable or "connects but no traffic" on a shared Jetson

This project and [`fprime-billee-rcm`](../fprime-billee-rcm) normally run
side by side on the same Jetson. Two distinct problems can both produce
"GDS looks connected but there's no telemetry" — see
[`fprime-billee-rcm`'s equivalent troubleshooting
section](../fprime-billee-rcm/README.md#board-unreachable-or-connects-but-no-traffic-on-a-shared-jetson)
for the full write-up and the live evidence that led to both fixes; summary:

**1. `/dev/ttyACMx` numbering isn't stable across a reboot.** Which raw
device node each board gets is assigned by USB enumeration order, not
device identity. Fixed by a project-owned udev rule
(`udev/99-billee-scm.rules`, installed automatically by `make setup` via
`make setup-udev`) that creates a persistent `/dev/ttyBILLEE_SCM` symlink
keyed on this board's USB identity (`16C0:04xx`), always pointing at the
Teensy regardless of which `ttyACMx` node the kernel assigns it.
`uart_gds.sh`/`lan_uart_gds.sh` and the systemd service now default to this
symlink instead of a hardcoded `ttyACM1` guess.

**2. Starting one deployment's GDS could silently kill the other's.**
`uart_gds.sh`/`lan_uart_gds.sh` clean up stale processes on every startup
with `pkill -9 -f "fprime_gds.executables.comm"` — a pattern that matched by
bare module name, not by which repo/venv launched it, so starting this
project's GDS while `fprime-billee-rcm`'s was already running could kill
its comm subprocess as collateral damage (and vice versa). Fixed by scoping
the cleanup patterns to this repo's own `fprime-venv` path, and by giving
each deployment its own explicit `--zmq-transport` IPC socket pair
(`/tmp/fprime-server-{in,out}-scm` here, `...-rcm` on the RCM side) instead
of relying on `fprime-gds` version-dependent defaults.

macOS device paths (`/dev/cu.usbmodem*`) aren't affected by either issue —
this is Jetson/Linux-specific.

---

**F´ website:** https://fprime.jpl.nasa.gov &nbsp;·&nbsp;
**fprime-arduino:** https://github.com/fprime-community/fprime-arduino
