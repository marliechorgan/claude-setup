#!/bin/bash
# Stable entrypoint. Python's standard library supplies structured Git parsing.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${VIRTUAL_ENV:-}" ]; then
  FANOUT_ACTIVE=""
  if [ -n "${FANOUT_VENV:-}" ]; then
    . "$FANOUT_VENV/bin/activate"
    FANOUT_ACTIVE=1
  else
    for FANOUT_CANDIDATE in "${1:-.}/.venv" "${1:-.}/venv" "$HOME/.venv" "$HOME/venv"; do
      if [ -f "$FANOUT_CANDIDATE/bin/activate" ]; then
        . "$FANOUT_CANDIDATE/bin/activate"
        FANOUT_ACTIVE=1
        break
      fi
    done
  fi
  # No virtual environment: the checks use only the standard library, so the system python3 is fine.
  if [ -z "$FANOUT_ACTIVE" ] && ! command -v python3 >/dev/null 2>&1; then
    echo "UNKNOWN runtime: python3 not found; install Python 3 or set FANOUT_VENV." >&2
    exit 2
  fi
fi
exec python3 "$SCRIPT_DIR/fanout_preflight.py" "$@"
