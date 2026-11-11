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
│   ├── fprime-baremetal/         # no-OS scheduler / Os implementations (pinned — see below)
│   ├── fprime-billee-scm/        # this project's own components (Relay/Roboclaw/PCA9685/LoadCell/Stepper managers, BootReporter) + Types/
│   └── vendor-lib/               # vendored third-party Arduino libraries: RoboClaw, PCA9685 (tracked in this repo)
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

**A RAM fix:**
- `config/FpConstants.fpp`: overrides `FW_TLM_BUFFER_MAX_SIZE` (506→128).
  Every TlmChan bucket reserves one buffer of this size, two copies each, so
  at the default `tlmSend` alone took ~83 KB of RAM1 for values no bigger
  than 96 bytes. At 128 it's ~28 KB. It must stay ≥ the largest telemetry
  value in the deployment (see "Fixed-size tables" for the script that checks
  it). Everything else in the file is a verbatim copy of the framework's, so
  when updating F´, diff `lib/fprime/default/config/FpConstants.fpp` against
  it and carry over any new constants.

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
| `make setup-flash-tools` | Install `teensy_loader_cli` (via apt) for headless flashing — no GUI Teensy Loader needed. Used by `make flash`. |
| `make generate` | `fprime-util generate teensy41` (needs a deployment — already created, see below). |
| `make build` | `fprime-util build teensy41`. |
| `make flash` | `fprime-util build teensy41 --target flash-teensy41` — builds, then flashes the connected board via `teensy_loader_cli`. |
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
make setup             # fprime-venv + submodules + Python deps
make setup-arduino     # arduino-cli + teensy:avr core + Time library
make setup-flash-tools # teensy_loader_cli, for `make flash`
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
it doesn't appear, open it manually and point it at that file. With the GUI
loader, flashing needs a **physical press of the Program button** (the Teensy
4.1's only pushbutton). On a headless host such as the Jetson, use
`make flash` instead (next section), which needs no button while the board's
USB is alive.

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

### Headless flashing: `make flash`

`make flash` builds, then runs `teensy_loader_cli -s`
(`cmake/teensy_flash_target.cmake`): it soft-reboots the running board into
the bootloader, flashes the `.hex`, and boots it — no GUI and no button. The
first write after the reboot often fails with `error writing to Teensy`;
`cmake/teensy_flash_retry.sh` retries automatically, so that line in the log
is normal. The `(hint: press the reset button)` line it prints while waiting
for the bootloader is boilerplate, not a request.

It only works while the board's USB is answering (or the board is already in
the bootloader).

### If the board stops responding

- **A failed `FW_ASSERT` reboots the board into the Teensy bootloader.**
  `Main.cpp` registers an assert hook (`RebootToBootloaderAssertHook`) that
  calls `_reboot_Teensyduino_()`, so the board shows up as USB `16c0:0478`
  (HalfKay) and `make flash` reaches it without a button. Without the hook the
  default `abort()` is a silent `while (1)`. The passive rate group runs from
  the rate driver's timer interrupt, so an assert raised there hangs inside
  an interrupt, the USB core stops answering, the soft reboot times out and
  the host cannot even enumerate the board.
- **Find out where it asserted.** The same hook stores the assert's file,
  line and arguments in RAM2, which survives the reboot. After reflashing,
  `bootReporter` reports them: telemetry `bootReporter.lastAssertFile` /
  `lastAssertLine` from the first tick, and a `PreviousBootAsserted` event
  15 s after boot (or on `bootReporter.BOOT_REPORT`). Hard faults come out as
  `PreviousBootFaulted` (Teensy's CrashReport). The record is lost only if the
  board loses power before the next boot.
- **If it hangs some other way** (`make flash` prints
  `Unable to soft reboot ... Connection timed out`, or the kernel logs
  `device descriptor read/64, error -110`), only the **Program button** or
  unplugging and replugging the USB cable recovers it. Power-cycling the port
  from the host does not work on the Jetson's hub (it cannot switch VBUS).

---

## Commanding the Science Control Module

One component per kind of hardware in the Science Hardware Architecture 2027
diagram. Each component's `docs/sdd.md` (in `lib/fprime-billee-scm/Components/`)
has the details.

| Component | Hardware | Commands |
|---|---|---|
| `relayManager` | Relays: `PUMP1`-`PUMP4` (39/38/37/36), `UV_LIGHT` (40), `STIRRER` (34) | `SET relay ON\|OFF`, `ON_FOR relay ms`, `ALL_OFF` |
| `pca9685Manager` | Servos `S1`-`S16` on the PCA9685 (S1 cup tilt, S2 drape, S3 cache lid, S4 funnel flap) | `SERVO_SET servo dir speed%`, `SERVO_OFF servo`, `SERVO_PULSE servo counts`, `STOP_ALL`, `REINIT` |
| `roboclawManager` | Roboclaws `R1`-`R3`, motors `R1_M1`, `R1_M2`, `R2_M1`, `R2_M2` (drill), `R3_M1` (linear actuator), each with lower/upper limit switches | `MOVE motor dir speed%`, `RUN_FOR motor dir speed% ms`, `TO_LIMIT motor dir speed% timeoutMs`, `STOP motor`, `STOP_ALL`, `RESET_ENCODERS board` |
| `loadCellManager` | HX711 weight sensors `CELL1`, `CELL2` | `TARE cell n`, `CALIBRATE cell grams n`, `SET_SCALE cell countsPerGram`, `WAIT_MASS cell ABOVE\|BELOW grams timeoutMs` |
| `stepperManager` | Carousel stepper | `MOVE_STEPS dir steps speedHz`, `MOVE_TO position speedHz`, `STOP`, `HOLD ON\|OFF`, `ZERO` |
| `cmdSeq` | Sequencer | `CS_VALIDATE file`, `CS_RUN file BLOCK\|NO_BLOCK`, `CS_CANCEL`, ... |
| `fileManager` | SD card | `CreateDirectory`, `RemoveFile`, `FileSize`, `MoveFile`, ... (not `ListDirectory`, see below) |
| `bootReporter` | Boot diagnostics, SD mount | `BOOT_REPORT`, `SD_MOUNT` |

Conventions shared by all of them:

- **Direction** is `FORWARD` / `REVERSE` / `STOPPED`. For a Roboclaw motor
  `FORWARD` always moves toward its **upper** limit switch; a motor wired the
  other way is fixed with `roboclawManager.configureMotor(motor, true)` in
  `billee_deploymentTopology.cpp`.
- **Speed** is 0-100 (% duty for motors, % of calibrated travel/speed for
  servos). The stepper takes steps per second.
- **Commands that wait on hardware are answered when they finish**: `ON_FOR`
  when the relay switches off, `RUN_FOR` when the time is up, `TO_LIMIT` when
  the switch trips, `MOVE_STEPS`/`MOVE_TO` on arrival, `TARE`/`CALIBRATE` when
  averaged, `WAIT_MASS` when the threshold is met. A timeout, a limit switch
  stopping a timed run, or a newer command on the same device answers
  `EXECUTION_ERROR`, which stops a running sequence.
- **A motor moving toward a tripped limit switch is stopped within one tick**
  (20 ms, `roboclawManager` runs at 50 Hz), whatever command started it.
- **Stop everything**: `relayManager.ALL_OFF`, `roboclawManager.STOP_ALL`,
  `pca9685Manager.STOP_ALL`, `stepperManager.STOP`, and `cmdSeq.CS_CANCEL` for
  a running sequence.
- **Load-cell tare and scale live in RAM.** Tare from the GDS before a run;
  restore a recorded `CALIBRATE` factor with `SET_SCALE` (or at the top of a
  sequence).

### Sequences

The sequencer waits for each command's answer, then for the command's relative
time (`R hh:mm:ss`), then sends the next. Because hardware commands answer
when they finish, a sequence reads as a script:

```
; Lower the drill tube to its limit, dose 3 s of pump 1, wait for 50 g on cell 1
R00:00:00 billee_deployment.roboclawManager.TO_LIMIT R2_M1 REVERSE 30 20000
R00:00:00 billee_deployment.relayManager.ON_FOR PUMP1 3000
R00:00:00 billee_deployment.relayManager.SET PUMP2 ON
R00:00:00 billee_deployment.loadCellManager.WAIT_MASS CELL1 ABOVE 50 60000
R00:00:00 billee_deployment.relayManager.SET PUMP2 OFF
R00:00:02 billee_deployment.roboclawManager.TO_LIMIT R2_M1 FORWARD 30 20000
```

Workflow:

1. Once per SD card: `fileManager.CreateDirectory /seq`.
2. In the GDS **Sequence** tab, write the sequence and press **Uplink**: the
   GDS compiles it and uplinks `/seq/<name>.bin` (the service runs with
   `--remote-sequence-directory /seq`). Wait for `fileUplink.FileReceived`.
3. `cmdSeq.CS_VALIDATE /seq/<name>.bin`, then
   `cmdSeq.CS_RUN /seq/<name>.bin BLOCK` (`BLOCK` answers the run command when
   the sequence ends).
4. `fileManager.RemoveFile /seq/<name>.bin false` **before re-uploading a
   changed sequence under the same name**: the SD file layer opens for writing
   without truncating, so a shorter new file would keep the old file's tail and
   fail `CS_VALIDATE`.

Timing resolution is one 10 Hz tick (100 ms), e.g. two NO-OPs 3 s apart run
3.1 s apart. `cmdSeq` fails any single command that goes unanswered for 600 s;
the hardware commands' own limits (300 s) are shorter.

**Do not use `fileManager.ListDirectory`.** fprime-arduino's SD directory code
(`lib/fprime-arduino/Arduino/Os/Directory.cpp`, `read()`) never reports "no
more files", so the listing never ends and emits an empty
`DirectoryListingSubdir` event every tick until the board is rebooted. Use
`FileSize` to check a file exists. (A one-line fix in that upstream file;
deliberately not carried in this project for now.)

**SD card**: the Teensy 4.1's own microSD socket, mounted at boot
(`bootReporter.SdCardStatus`, telemetry `sdCardMounted`). Error code `0x17`
means the card never initialized, which is also what an empty or unseated
socket looks like; reseat it and run `bootReporter.SD_MOUNT`.

### FPP gotchas met while building this

- `state` is a reserved word in FPP (state machines): it cannot name a command
  argument, an event argument or a telemetry channel (`error: identifier
  expected` / `) expected`).
- After adding a type or constant to an **existing** `.fpp` file, regenerate
  (`fprime-util generate teensy41 -f`, or delete the build directory and run
  `make build`). The build alone keeps a stale symbol index (`locs.fpp`) and
  fails with `symbol ... is not defined`. Adding a new `.fpp` file to a
  `CMakeLists.txt` regenerates on its own.
- FPP constants are not C++ constants named the same way: in C++ use the size
  of a generated array (`billeeScm::RelayStates::SIZE`) rather than
  `RELAY_COUNT`.

---

## Runtime constraints (read before changing `instances.fpp` or the wiring)

**Task priorities must be non-increasing in alphabetical start order.**
Active components are started in alphabetical order (`cmdDisp`, `cmdSeq`,
`eventLogger`, `fileManager`, `fileUplink`, `loadCellManager`,
`pca9685Manager`, `relayManager`, `roboclawManager`, `stepperManager`,
`tlmSend`). `Os::Baremetal::TaskRunner::addTask()` in
`lib/fprime-baremetal` has a bug: a task started with a *higher* priority
than one started before it overwrites another task's table entry, and that
task is then never run. Its queue (depth 3) overflows after three rate-group
ticks (~300 ms), `FW_ASSERT(Os::Queue::FULL)` fires and, without the assert
hook, the board silently stops. This is exactly what happened when
`uvManager` was given priority 99 above `pumpManager` (96) and `tlmSend` (97).
On this cooperative scheduler priority only orders the round-robin, so equal
priorities are fine. The rule is repeated in a comment at the top of
`billee_deployment/Top/instances.fpp`.

**Queues and blocking.** The TaskRunner is cooperative: while one handler
runs, nothing else does, but the rate-group interrupt keeps queuing ticks. An
async port whose queue is full asserts unless its component declares it
`drop`. So:

- Every project component's rate-group port is `async input port run:
  Svc.Sched drop`. Do the same in any new component.
- Framework components whose rate-group port asserts (`tlmSend.Run`,
  `cmdSeq.schedIn`, `fileManager.schedIn`) get `Default.SCHED_QUEUE_SIZE`
  (40 = 4 s of 10 Hz ticks). The longest legitimate block is `SD.begin()` with
  no card (`bootReporter.SD_MOUNT`): SdFat's 2 s timeout. A new blocking call
  longer than that needs a deeper queue.
- `ComCcsds.comQueue` is 20 deep (`ComCcsdsConfig.fpp`): its `comStatusIn` port
  asserts when full, and at the old depth of 3 any burst of events rebooted
  the board.
- Keep handlers short. A Roboclaw that does not answer costs 30 ms per call,
  so `roboclawManager` makes at most one serial transaction per tick and
  probes an offline board every 2 s.

**Heap.** Plain `new` works: it is Teensy's `operator new`, which calls
`malloc` on the RAM2 heap (fprime-baremetal's `OverrideNewDelete` is not
linked into this build). Queues and the sequence buffer live there. The
vendored-driver objects still use placement new into static storage so their
memory is fixed at build time. (An earlier version of this README said the
first `new` halts the board; that applied to a configuration that linked
`OverrideNewDelete` without registering an allocator.)

**Fixed-size tables.** These limits in `billee_deployment/config/` are sized
by hand, and going over any of them is an `FW_ASSERT` on the board, not a
build error:

| Table | Setting | Must be |
|---|---|---|
| Command dispatch table | `CMD_DISPATCHER_DISPATCH_TABLE_SIZE` (`CommandDispatcherImplCfg.hpp`) | ≥ number of commands in the deployment (asserts inside `regCommands()` during `setupTopology()`) |
| TlmChan | `TLMCHAN_NUM_TLM_HASH_SLOTS` / `TLMCHAN_HASH_BUCKETS` (`TlmChanImplCfg.hpp`) | buckets ≥ number of telemetry channels (asserts on the first tick that writes one too many) |
| Telemetry value size | `FW_TLM_BUFFER_MAX_SIZE` (`FpConstants.fpp`, 128) | ≥ the largest serialized telemetry value (asserts when that channel is first written) |

Adding a component adds commands and channels, so re-check all three. The
script below reads them from the dictionary the build produces. Channel sizes
come from the dictionary's `typeDefinitions`: primitives by type, enums by
their representation type, strings as 2 + max length, arrays and structs
summed. It prints `-1` for a type it can't size, which you then check by hand.

```bash
python3 - build-artifacts/teensy41/*/dict/*.json <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
print("commands", len(d["commands"]), " telemetry channels", len(d["telemetryChannels"]))
types = {t["qualifiedName"]: t for t in d.get("typeDefinitions", [])}
prim = {"U8": 1, "I8": 1, "U16": 2, "I16": 2, "U32": 4, "I32": 4, "F32": 4,
        "U64": 8, "I64": 8, "F64": 8, "bool": 1}
def size(t):
    if t["kind"] in ("integer", "float", "bool"):
        return prim.get(t["name"])
    if t["kind"] == "string":
        return 2 + t.get("size", 80)
    q = types.get(t["name"])
    if q is None:
        return None
    if q["kind"] == "enum":
        return prim.get(q["representationType"]["name"])
    if q["kind"] == "alias":
        return size(q["underlyingType"])
    if q["kind"] == "array":
        s = size(q["elementType"])
        return s * q["size"] if s else None
    if q["kind"] == "struct":
        parts = [(size(m["type"]), m.get("size", 1)) for m in q["members"].values()]
        return None if any(s is None for s, _ in parts) else sum(s * n for s, n in parts)
    return None
sizes = sorted((size(c["type"]) or -1, c["name"]) for c in d["telemetryChannels"])
print("largest telemetry values (bytes):", sizes[-3:])
EOF
```

**Symptom if you get it wrong:** the build succeeds and `make flash` succeeds,
but the board never runs. The assert hook in `Main.cpp` reboots it straight
into the Teensy bootloader, so it enumerates as `16c0:0478` (HalfKay, a HID
device) instead of a serial port, `/dev/ttyBILLEE_SCM` never appears, and the
GDS service loops forever waiting for it. `make flash` still reaches the board
(no button needed), so fix the table and reflash. This happened when
PCA9685Manager took the command count from 23 to 29 against a table of 24.
Current values: 64 commands (50 used), 12 slots + 72 buckets (58 channels),
`FW_TLM_BUFFER_MAX_SIZE` 128 (largest channel: `roboclawManager.motorStates`,
65 bytes). Each TlmChan bucket holds one telemetry buffer of
`FW_TLM_BUFFER_MAX_SIZE` and TlmChan keeps two copies of every bucket, so
`tlmSend` is about 28 KB of RAM1. It was about 83 KB when the buffer was the
framework's default of 506 bytes. Check the `teensy_size` RAM1 line after
changing either setting (see "RAM1 budget" below).
Two port counts in `config/AcConstants.fpp` are also sized by hand (going over
either is an FPP error at `make generate`, not a boot assert):
`PassiveRateGroupOutputPorts` = 16 (`rateGroup1` uses up to index 12,
`rateGroup2` index 0) and `CmdDispatcherComponentCommandPorts` = 16 (12
components with commands).

**RAM1 budget.** Teensy 4.1 runs all code from RAM1 (ITCM), which the linker
hands out in **32 KB blocks**. Whatever RAM1 the code doesn't take holds the
global variables, and what's left after those is the **stack**. So adding
code can take a whole 32 KB from the stack at once, the moment the code
crosses a block boundary. The root `CMakeLists.txt` compiles with `-Os`
(Teensyduino's "Smallest Code") instead of the toolchain's `-O2` for this
reason. Adding the command sequencer and SD library at `-O2` pushed code over
the boundary and left the stack at −33 KB.

Check after every change that adds a component, a library or a channel:

```bash
~/.arduino15/packages/teensy/tools/teensy-tools/*/teensy_size \
  build-artifacts/teensy41/FprimeArduinoBilleeScm_billee_deployment/bin/FprimeArduinoBilleeScm_billee_deployment.elf
```

- Measure **that** `.elf`. The one under
  `build-fprime-automatic-teensy41/arduino-cli-sketch/` is a small stub, not
  the firmware, and its numbers look healthy no matter what.
- `RAM1 ... free for local variables` is the stack. Keep it at 16 KB or more.
  A small or negative number means the board faults during startup, before
  USB comes up.
- `code:` shows how close the next block boundary is (multiples of 32,768).
- To see what grew, list the biggest symbols (`B`/`D` are variables, `T` is
  code):
  `~/.arduino15/packages/teensy/tools/teensy-compile/11.3.1/arm/bin/arm-none-eabi-nm -C -S --size-sort <that .elf> | tail -20`
- `make build`/`make flash` do **not** stop when `teensy_size` prints
  `Error program exceeds memory space`. Read the output.
- The Jetson's build of the same commit comes out about 11 KB larger in code
  than a WSL build. Check the numbers from the machine that flashes.
- **Cold code runs from flash.** `cmake/teensy_flash_code.cmake` links with a
  copy of Teensy's linker script that puts the code and read-only data of the
  libraries in its `TEENSY_FLASH_LIBRARIES` list (sequencer, file manager,
  file uplink) in flash instead of RAM1. That took the Jetson build from 11
  code blocks back to 9. It is the first lever when RAM1 runs short again:
  add a library that is not timing critical to the list (`nm` then shows its
  functions at `0x6xxxxxxx`). Keep interrupt handlers and the comm path in
  RAM1.
- Current Jetson build: code 295 KB (10 blocks), **49 KB** stack free.

**Symptom if RAM1 overflows:** build and flash succeed, then nothing. The
kernel log on the host shows the flash (`16c0:0478`), a disconnect, and no
device after it (`dmesg | grep -i usb`). No serial port, no bootloader, no
reboot loop: the board faults during startup, before USB comes up, unlike an
`FW_ASSERT`, which leaves it in the bootloader.

**Pinout**: every pin is defined in `billee_deployment/Top/SciencePins.hpp`,
matching the Science Hardware Architecture 2027 block diagram. The diagram
does not assign the HX711 buses; they are on 24/25 and 26/27.

**Limit switches** must close to **GND** when tripped. `setupTopology()`
enables the Teensy's internal pull-up on each one, so an open switch reads
`HIGH`. One lower/upper pair per Roboclaw motor: R1_M1 23/22, R1_M2 21/15,
R2_M1 14/41, R3_M1 33/32 (R2_M2, the drill, has none).

**Roboclaw wiring**: R1 is address `0x80` on `Serial1` (pins 1 TX / 0 RX),
R2 is `0x81` on `Serial2` (pins 8 TX / 7 RX), R3 (linear actuator) is `0x82`
on `Serial4` (pins 17 TX / 16 RX), 38400 baud, all driven by the one
`roboclawManager`.

**PCA9685 servo board**: on the Teensy's `Wire` bus (SDA pin 18 / SCL pin 19),
board address pins A5..A0 = 0 (I2C address 0x40), at **100 kHz**. `Wire1` is
not usable because its pins (16/17) are `Serial4`'s. Power the breakout's
**logic VCC from the Teensy's 3.3 V**: Teensy 4.1 pins are not 5 V tolerant and
the breakout's pull-ups go to its logic VCC. Servo power is the separate V+
rail, with grounds tied. The bus pull-ups are the breakout's 10 kΩ in parallel
with the Teensy's internal ~22 kΩ, which is why the bus runs at 100 kHz. The
OE pin is not wired, so the only software stop is `pca9685Manager.STOP_ALL`.
Per-channel pulse limits (and a `reversed` flag) are a compile-time table in
`PCA9685Manager.cpp`.

**Carousel stepper**: NEMA 17 with an integrated driver: PU- on 2, DR- on 3,
MF- on 4 (5 spare), XCOM to +5 V. The pins are open-drain (`OUTPUT_OPENDRAIN`):
LOW turns an input on, high-impedance turns it off, so an "off" input does not
sit at the 1.7 V a 3.3 V HIGH would leave against 5 V. If the driver still
sees phantom pulses, add a level shifter.

**HX711 load cells**: DAT 24 / CLK 25 (CELL1) and DAT 26 / CLK 27 (CELL2).
Power the HX711 boards from 3.3 V.

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
