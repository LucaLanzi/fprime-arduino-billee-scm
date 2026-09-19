#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UART_DEVICE="${UART_DEVICE:-/dev/ttyACM0}"
DICTIONARY_PATH="${DICTIONARY_PATH:-${PROJECT_ROOT}/build-artifacts/teensy41/FprimeArduinoBilleeScm_billee_deployment/dict/billee_deploymentTopologyDictionary.json}"
GDS_BIN="${PROJECT_ROOT}/fprime-venv/bin/fprime-gds"
# 5001, not fprime-gds's own default of 5000 - this project runs alongside
# fprime-billee-rcm (which owns 5000) on the same Jetson, and each
# deployment's GDS dashboard needs its own port to avoid colliding.
GDS_FLASK_PORT="${GDS_FLASK_PORT:-5001}"

# Killing a previous `make gds` session by its top-level PID alone (rather than its whole
# process group -- e.g. a plain `kill -9 <pid>` instead of Ctrl+C in the owning terminal)
# orphans its Flask dashboard worker and comm/CustomDataHandlers children to PID 1. They
# keep running indefinitely, and the *oldest* surviving one wins the bind on the dashboard
# port. A later session then serves a dictionary frozen at whatever build existed when that
# zombie started, with no live telemetry -- while looking, from the browser, like GDS itself
# is broken. Clear out anything like that before starting so this can't happen silently.
if command -v lsof >/dev/null 2>&1; then
    stale_pids="$(lsof -t -nP -iTCP:"${GDS_FLASK_PORT}" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "${stale_pids}" ]]; then
        echo "[INFO] Killing stale process(es) holding dashboard port ${GDS_FLASK_PORT}: ${stale_pids}" >&2
        # shellcheck disable=SC2086
        kill -9 ${stale_pids} 2>/dev/null || true
    fi
fi
if command -v pkill >/dev/null 2>&1; then
    pkill -9 -f "flask run --host .* --port ${GDS_FLASK_PORT}" 2>/dev/null || true
    pkill -9 -f "fprime_gds.executables.comm" 2>/dev/null || true
    pkill -9 -f "fprime_gds.executables.apps.CustomDataHandlers" 2>/dev/null || true
    pkill -9 -f "${GDS_BIN}" 2>/dev/null || true
fi
rm -f /tmp/fprime-server-in /tmp/fprime-server-out

if [[ ! -x "${GDS_BIN}" ]]; then
    echo "F Prime GDS was not found at ${GDS_BIN}. Run 'make setup' first." >&2
    exit 1
fi

if [[ ! -f "${DICTIONARY_PATH}" ]]; then
    echo "The Teensy 4.1 dictionary was not found. Run 'make generate && make build' first." >&2
    exit 1
fi

if [[ ! -c "${UART_DEVICE}" ]]; then
    echo "Serial device ${UART_DEVICE} is not available." >&2
    echo "check 'ls -l /dev/ttyACM*' (Linux) or 'ls -l /dev/cu.usbmodem*' (macOS)." >&2
    exit 1
fi

exec "${GDS_BIN}" \
  --no-app \
  --dictionary "${DICTIONARY_PATH}" \
  --communication-selection uart \
  --uart-device "${UART_DEVICE}" \
  --uart-skip-port-check \
  --uart-baud 115200 \
  --gui-port "${GDS_FLASK_PORT}" \
  "$@"
