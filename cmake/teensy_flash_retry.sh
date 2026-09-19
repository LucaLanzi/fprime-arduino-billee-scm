#!/usr/bin/env bash
# teensy_loader_cli intermittently fails a device's first post-reboot write with
# "error writing to Teensy" (a known flakiness with this tool on some USB controllers/hubs).
# The device stays in HalfKay bootloader mode when this happens, so an immediate retry -
# without needing another soft-reboot or button press - reliably succeeds. Retry a few times
# before giving up for real.
set -u

max_attempts=3
attempt=1
while [ "$attempt" -le "$max_attempts" ]; do
    if "$@"; then
        exit 0
    fi
    echo "[teensy_flash_retry] attempt $attempt/$max_attempts failed, retrying..." >&2
    attempt=$((attempt + 1))
    sleep 1
done

echo "[teensy_flash_retry] giving up after $max_attempts attempts" >&2
exit 1
