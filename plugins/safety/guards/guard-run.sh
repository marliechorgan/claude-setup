#!/bin/bash
# guard-run.sh: run one guard and record what it decided.
#
#   settings.json hook command:  bash <plugin>/guards/guard-run.sh <plugin>/guards/<guard>.sh
#
# A guard reports a block by exit 2 and a reason on stderr. Claude reads that reason and
# nothing keeps it, so without this wrapper nobody can answer "has this guard blocked
# something it should not have?" or "has it quietly stopped working?".
#
# The wrapper is invisible: stdin, stdout, stderr and the exit code pass through unchanged.
#
# Verdicts:
#   allow   exit 0
#   block   exit 2, or exit 0 with a JSON permissionDecision "deny" on stdout
#   break   any other exit code. Claude Code treats that as non-blocking, so the guard
#           protected nothing. Treat a break as an incident.
#   absent  the guard is missing or damaged (see the integrity gate below)
#
# Logs (see CONTRACT.md): a daily activity-YYYY-MM-DD.tsv with one fixed-shape row per
# non-allow verdict, and ledger.jsonl with the reason and a redacted, shortened subject.

GUARD="${1:-}"
[ $# -gt 0 ] && shift

case "$GUARD" in "~/"*) GUARD="$HOME/${GUARD#\~/}" ;; esac
# The wrapper leaves the caller's directory below, so pin a relative guard path first.
case "$GUARD" in /*|"") ;; *) GUARD="$PWD/$GUARD" ;; esac

LOGDIR="${CLAUDE_SAFETY_LOG_DIR:-${CLAUDE_PLUGIN_DATA:-$HOME/.local/state/claude-safety}}"

# One private temp directory holds the payload, the guard's stdout and its stderr.
# mktemp with an explicit template behaves the same on macOS and Linux.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/guard-run.XXXXXX" 2>/dev/null)" \
  || WORK="$(mktemp -d "/tmp/guard-run.XXXXXX" 2>/dev/null)" || WORK=""
[ -n "$WORK" ] && trap 'rm -rf "$WORK"' EXIT

# Write the log rows for a non-allow verdict. Given the hint "allow", first decide
# whether the exit-0 guard in fact denied through JSON on stdout.
#   _record <allow|block|break|absent> <rc>
_record() {
  mkdir -p "$LOGDIR" 2>/dev/null
  GR_GUARD="$GUARD" GR_HINT="$1" GR_RC="$2" GR_WORK="$WORK" GR_LOGDIR="$LOGDIR" \
  python3 -I -S - <<'PY' 2>/dev/null
import json, os, re, time

work = os.environ.get("GR_WORK") or ""
def read(name):
    if not work:
        return ""
    try:
        with open(os.path.join(work, name), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""

verdict = os.environ.get("GR_HINT", "break")
reason = read("err").strip()

if verdict == "allow":
    # Exit 0 is a block when the guard denied through structured output instead.
    try:
        out = json.loads(read("out") or "{}")
    except ValueError:
        out = {}
    if isinstance(out, dict):
        hso = out.get("hookSpecificOutput") or {}
        if isinstance(hso, dict) and hso.get("permissionDecision") == "deny":
            verdict = "block"
            reason = str(hso.get("permissionDecisionReason") or reason)
        elif out.get("decision") == "block":
            verdict = "block"
            reason = str(out.get("reason") or reason)
if verdict == "allow":
    raise SystemExit(0)

SECRET_PATTERNS = [
    # Authorization-style header values
    (r"(?i)\b(bearer|basic|token)\s+[A-Za-z0-9._~+/=-]{8,}", r"\1 ***"),
    # key=value and key: value where the key names a secret
    (r"(?i)(\b[\w.-]*(?:passw(?:or)?d|passwd|pwd|secret|token|api[_-]?key|apikey|access[_-]?key"
     r"|private[_-]?key|credential|authorization)[\w.-]*[\"']?\s*[=:]\s*)"
     r"(\"[^\"]*\"|'[^']*'|[^\s\"',;&|]+)", r"\1***"),
    # a secret-named flag followed by its value: --password hunter2
    (r"(?i)(\s--?(?:password|passwd|pass|token|secret|api-?key)\s+)(\"[^\"]*\"|'[^']*'|\S+)", r"\1***"),
    # user:password given to -u / --user (curl and friends)
    (r"(?:^|(?<=\s))((?:-u|--user)[=\s]+[\"']?[^:\s\"']+:)[^\s\"']+", r"\1***"),
    # credentials inside a URL
    (r"(?i)(\b[a-z][a-z0-9+.-]*://[^/\s:@]+:)[^@\s/]+@", r"\1***@"),
    # well-known token shapes
    (r"\b(?:sk|pk|rk)-[A-Za-z0-9_-]{16,}", "***"),
    (r"\b(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}", "***"),
    (r"\bxox[abprs]-[A-Za-z0-9-]{10,}", "***"),
    (r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b", "***"),
    (r"\bAIza[0-9A-Za-z_-]{30,}", "***"),
    (r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}", "***"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)", "***"),
    # any long unbroken run of hex or base64 characters
    (r"\b[A-Fa-f0-9]{32,}\b", "***"),
    (r"[A-Za-z0-9+/_-]{40,}={0,2}", "***"),
]

def redact(text, limit):
    text = " ".join(str(text).split())
    for pat, rep in SECRET_PATTERNS:
        text = re.sub(pat, rep, text, flags=re.S)
    return text[:limit]

try:
    data = json.loads(read("in") or "{}")
except ValueError:
    data = {}
if not isinstance(data, dict):
    data = {}
ti = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
subject = ti.get("command") or ti.get("file_path") or ti.get("url") or ti.get("path") or ""

ts = time.strftime("%Y-%m-%dT%H:%M:%S%z")
unattended = "1" if os.environ.get("CLAUDE_SAFETY_UNATTENDED") == "1" else "0"
guard = os.path.basename(os.environ.get("GR_GUARD") or "?")
logdir = os.environ.get("GR_LOGDIR") or "."
row = {
    "ts": ts,
    "guard": guard,
    "verdict": verdict,
    "rc": int(os.environ.get("GR_RC") or 0),
    "tool": str(data.get("tool_name") or ""),
    "cwd": str(data.get("cwd") or ""),
    "unattended": unattended,
    "subject": redact(subject, 120),
    "reason": redact(reason, 400),
}
try:
    with open(os.path.join(logdir, "activity-%s.tsv" % ts[:10]), "a", encoding="utf-8") as fh:
        fh.write("\t".join([ts, guard, verdict, unattended]) + "\n")
    with open(os.path.join(logdir, "ledger.jsonl"), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
except OSError:
    pass
PY
}

# --- Integrity gate ----------------------------------------------------------------
# A guard caught mid-write does not fail closed on its own: an empty file exits 0, and a
# file cut off at a line boundary may still parse and allow. Both look like a normal
# allow. So the wrapper refuses to run a guard that is missing, not executable, empty or
# does not end on a known final line. This is the one place the plugin fails closed: a
# guard unsure about a command allows it, but absent enforcement is refused.
# The check reads only the last 200 bytes, so it costs almost nothing per tool call.
_guard_intact() {
  [ -f "$1" ] && [ -s "$1" ] || return 1
  local tail_bytes last
  tail_bytes="$(tail -c 200 "$1" 2>/dev/null)"   # $( ) drops trailing newlines
  last="${tail_bytes##*$'\n'}"
  case "$last" in
    PY|EOF|fi|esac|done|"}"|exit|"exit "*|"# guard-end"|"sys.exit("*|"raise SystemExit"*) return 0 ;;
  esac
  return 1
}

if [ -z "$GUARD" ] || [ ! -x "$GUARD" ] || ! _guard_intact "$GUARD"; then
  echo "BLOCKED by guard-run [guard-absent]: the guard '${GUARD##*/}' is missing, not" \
       "executable, empty or truncated, so this tool call is refused rather than waved" \
       "through unchecked." >&2
  echo "DO THIS INSTEAD: ask the user to restore or reinstall the safety plugin's guard" \
       "file (reinstalling the plugin restores it). When editing a guard, write it to a" \
       "temp file and mv it into place so no reader sees a partial file. A guard that is" \
       "intact must end on a line such as 'exit 0', 'fi', 'PY' or '# guard-end'." >&2
  [ -n "$WORK" ] && cat > "$WORK/in" 2>/dev/null
  _record absent 2
  exit 2
fi

# Guards run python with -I -S, but pin the rest too: run from / so nothing in the
# session's directory can shadow a module, keep the project dir for guards that need it,
# and ignore the user site-packages.
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
export PYTHONNOUSERSITE=1
cd / 2>/dev/null || true

if [ -z "$WORK" ]; then
  # No temp space: run the guard straight through and log the verdict without detail.
  "$GUARD" "$@"
  RC=$?
  case "$RC" in 0) ;; 2) _record block 2 ;; *) _record break "$RC" ;; esac
  exit $RC
fi

cat > "$WORK/in"
"$GUARD" "$@" < "$WORK/in" > "$WORK/out" 2> "$WORK/err"
RC=$?
[ -s "$WORK/out" ] && cat "$WORK/out"
[ -s "$WORK/err" ] && cat "$WORK/err" >&2

case "$RC" in
  0)
    # Only an exit-0 guard that printed a decision needs a closer look.
    if [ -s "$WORK/out" ]; then
      case "$(cat "$WORK/out")" in
        *'"permissionDecision"'*|*'"decision"'*) _record allow 0 ;;
      esac
    fi ;;
  2) _record block 2 ;;
  *) _record break "$RC" ;;
esac
exit $RC
