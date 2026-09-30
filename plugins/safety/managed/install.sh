#!/bin/bash
# install.sh: make this plugin's guards macOS managed settings, so no Claude Code session can
# switch them off, edit them, or steer their environment. Also check, or remove, an install.
#
#   ./install.sh --dry-run     build and test everything in a temp dir; no sudo, changes nothing
#   ./install.sh               install; asks for your password via /usr/bin/sudo
#   ./install.sh --verify      check what is installed against the plugin; no sudo
#   ./install.sh --uninstall   remove the managed settings and the root-owned copies; sudo
#
# Run it from your own terminal. A Claude session may not run sudo, so it refuses to run in one.
# Needs administrator rights: the install writes root-owned files under a system folder.
#
# Why managed settings: a plugin's hooks live in a settings file a session can bypass. A child
# `claude` started with --settings '{"disableAllHooks":true}', with a narrowed --setting-sources,
# or in a restricted mode, loads none of them. macOS managed settings apply on every launch and
# cannot be turned off from inside a session, so the guards still run. See README.md here.
#
# What gets installed, root-owned and not writable by you:
#   /Library/Application Support/ClaudeCode/managed-settings.json  the guard hooks, in exec form
#   /Library/Application Support/ClaudeCode/claude-safety/managed-guard     the launcher (from the template)
#   /Library/Application Support/ClaudeCode/claude-safety/guards/           a copy of the plugin's guards
#   /Library/Application Support/ClaudeCode/claude-safety/lib/              a copy of the plugin's lib
#   /Library/Application Support/ClaudeCode/claude-safety/config.json       the config baked at install time
# The plugin's own hooks keep running too. A call needs both copies to allow it, so tightening a
# guard in the plugin works at once and loosening one needs a re-install.

set -eo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin   # nothing here resolves from /usr/local or a package manager
umask 022

HERE="$(cd "$(dirname "$0")" && pwd -P)"
PLUGIN="$(cd "$HERE/.." && pwd -P)"
TARGET="/Library/Application Support/ClaudeCode"
HOOKS="$TARGET/claude-safety"   # its own folder, never a shared hooks/ another install may own
LOGDIR="$HOME/.local/state/claude-safety/managed"
PYDIR="/Library/Developer/CommandLineTools/usr/bin"
SUDO=/usr/bin/sudo
MARKER=".claude-safety-plugin"
# The config baked into the managed copy: your own if present, else the plugin's example.
CFG_SRC="$HOME/.config/claude-safety/config.json"
[ -f "$CFG_SRC" ] || CFG_SRC="$PLUGIN/config.example.json"

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
ask() { local a; read -r -p "$1 [y/N] " a || return 1; [ "$a" = y ] || [ "$a" = Y ]; }

[ "$(id -u)" != 0 ] || die "run this as yourself, not root; it calls /usr/bin/sudo for the steps that need it"
[ "$(uname -s)" = Darwin ] || die "managed settings are a macOS feature; this installer is macOS-only"
no_session() { [ -z "${CLAUDECODE:-}" ] || die "this is a Claude session. Run it from your own terminal."; }

# The guard names, taken from the settings file this package installs (one source of truth).
guards() {
  /usr/bin/python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
print("\n".join(sorted({h["args"][0] for e in d["hooks"].values() for g in e for h in g["hooks"]})))' \
    "$HERE/managed-settings.json"
}

# build OUT ROOT_DIR LOG_DIR: assemble a hooks dir and settings file in OUT, with the launcher
# rendered for ROOT_DIR. The same function builds the dry run and the real install. A guard named
# in the settings file but not yet present in the plugin is reported and skipped, so this works
# before every guard is written; the settings file still names it, so it takes effect once copied.
build() {
  local out="$1" rd="$2" ld="$3" g missing=""
  mkdir -p "$out/hooks/guards" "$out/hooks/lib"
  [ -f "$PLUGIN/guards/guard-run.sh" ] || die "missing $PLUGIN/guards/guard-run.sh (the wrapper)"
  cp "$PLUGIN/guards/guard-run.sh" "$out/hooks/guards/guard-run.sh"
  cp "$PLUGIN"/lib/*.py "$out/hooks/lib/" 2>/dev/null || die "missing $PLUGIN/lib (safety-config.py)"
  for g in $(guards); do
    if [ -f "$PLUGIN/guards/$g" ]; then
      cp "$PLUGIN/guards/$g" "$out/hooks/guards/$g"
    else
      missing="$missing $g"
    fi
  done
  chmod -R 755 "$out/hooks/guards" "$out/hooks/lib"
  cp "$CFG_SRC" "$out/hooks/config.json"; chmod 644 "$out/hooks/config.json"
  sed -e "s|@ROOT_DIR@|$rd|g" -e "s|@HOME@|$HOME|g" -e "s|@LOGDIR@|$ld|g" -e "s|@PYDIR@|$PYDIR|g" \
    "$HERE/managed-guard.template" > "$out/hooks/managed-guard"
  chmod 755 "$out/hooks/managed-guard"
  printf '%s\n' "installed by the claude-safety plugin; install.sh only replaces or removes a folder holding this file" > "$out/hooks/$MARKER"
  ! grep -q '@[A-Z_]*@' "$out/hooks/managed-guard" || die "managed-guard has an unrendered placeholder"
  cp "$HERE/managed-settings.json" "$out/managed-settings.json"; chmod 644 "$out/managed-settings.json"
  [ -z "$missing" ] || say "  NOTE: not yet in the plugin, skipped (named in the policy, will apply once present):$missing"
}

# smoke ROOT_DIR: every present guard answers 0 or 2 through the launcher without a Python error,
# and the command guard still blocks a delete of a protected path with a hostile environment and a
# hostile cwd. A guard that raises would fail open, so this catches one that stopped running.
smoke() {
  local rd="$1" g p rc err bad=0 fake
  fake="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$fake/python3"; chmod 755 "$fake/python3"
  : > "$fake/json.py"
  for g in $(guards); do
    [ -f "$rd/guards/$g" ] || continue
    case "$g" in
      config-guard.sh)  p='{"tool_name":"Write","tool_input":{"file_path":"'"$fake"'/x.txt","content":"x"},"cwd":"'"$HOME"'"}' ;;
      ingress-guard.sh) p='{"tool_name":"WebFetch","tool_input":{"url":"https://example.com"},"tool_response":"hello","cwd":"'"$HOME"'"}' ;;
      *)                p='{"tool_name":"Bash","tool_input":{"command":"ls"},"cwd":"'"$HOME"'"}' ;;
    esac
    err="$(printf '%s' "$p" | "$rd/managed-guard" "$g" 2>&1 >/dev/null)" && rc=0 || rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
      say "  FAIL $g: benign call returned rc=$rc ${err:+($(printf '%s' "$err" | tail -1 | cut -c1-150))}"; bad=1
    elif printf '%s' "$err" | grep -q -E 'Traceback|SyntaxError'; then
      say "  FAIL $g: raised a Python error ($(printf '%s' "$err" | tail -1 | cut -c1-150))"; bad=1
    fi
  done
  if [ -f "$rd/guards/command-guard.sh" ]; then
    p='{"tool_name":"Bash","tool_input":{"command":"rm -rf '"$HOME"'/.ssh"},"cwd":"'"$HOME"'"}'
    printf '%s' "$p" | "$rd/managed-guard" command-guard.sh >/dev/null 2>&1 && rc=0 || rc=$?
    [ "$rc" = 2 ] || { say "  FAIL command-guard did not block rm -rf a protected path (rc=$rc)"; bad=1; }
    printf '%s' "$p" | env PATH="$fake:$PATH" BASH_ENV="$fake/x.sh" PYTHONPATH="$fake" HOME="$fake" \
      "$rd/managed-guard" command-guard.sh >/dev/null 2>&1 && rc=0 || rc=$?
    [ "$rc" = 2 ] || { say "  FAIL with a hostile environment the block did not hold (rc=$rc)"; bad=1; }
    (cd "$fake" && printf '%s' "$p" | "$rd/managed-guard" command-guard.sh >/dev/null 2>&1) && rc=0 || rc=$?
    [ "$rc" = 2 ] || { say "  FAIL from a cwd holding json.py the block did not hold (rc=$rc)"; bad=1; }
  fi
  rm -rf "$fake"
  [ "$bad" = 0 ] && say "  smoke test: guards answer, and the delete block holds against a hostile environment and cwd"
  return "$bad"
}

# ours FILE: true if every hook in FILE runs this package's launcher and FILE sets nothing else.
ours() {
  /usr/bin/python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
hs = [h for e in d.get("hooks", {}).values() for g in e for h in g.get("hooks", [])]
sys.exit(0 if set(d) == {"hooks"} and hs and all(h.get("command") == sys.argv[2] + "/managed-guard" for h in hs) else 1)' \
    "$1" "$HOOKS" 2>/dev/null
}

verify() {
  local bad=0 p line owner mode g tmp
  [ -f "$TARGET/managed-settings.json" ] || { say "NOT INSTALLED: no $TARGET/managed-settings.json"; return 1; }
  say "Checking $TARGET"
  # 1. Root-owned and not group- or world-writable, from /Library down, with no ACLs.
  for p in /Library "/Library/Application Support" "$TARGET" "$TARGET/managed-settings.json" "$HOOKS" "$HOOKS/managed-guard"; do
    line="$(stat -f '%Su %Sp' "$p" 2>/dev/null)" || { say "  MISSING: $p"; bad=1; continue; }
    owner="${line%% *}"; mode="${line#* }"
    [ "$owner" = root ] || { say "  BAD owner $owner: $p"; bad=1; }
    [ "${mode:5:1}" != w ] && [ "${mode:8:1}" != w ] || { say "  BAD mode $mode: $p"; bad=1; }
    [ "$(ls -led "$p" | wc -l | tr -d ' ')" = 1 ] || { say "  BAD: $p carries an ACL"; bad=1; }
  done
  [ ! -d "$TARGET/managed-settings.d" ] || say "  NOTE: $TARGET/managed-settings.d exists; its files merge with this policy"
  # 2. The installed guard copies match the plugin (a guard changed since install = re-run install).
  for g in guard-run.sh $(guards); do
    [ -f "$PLUGIN/guards/$g" ] || continue
    cmp -s "$PLUGIN/guards/$g" "$HOOKS/guards/$g" || { say "  DRIFT: $g differs from the plugin (re-run install.sh)"; bad=1; }
  done
  # 3. The launcher and the settings file match this package.
  tmp="$(mktemp -d)"; build "$tmp" "$HOOKS" "$LOGDIR" >/dev/null
  cmp -s "$tmp/hooks/managed-guard" "$HOOKS/managed-guard" || { say "  DRIFT: managed-guard differs from the template"; bad=1; }
  cmp -s "$HERE/managed-settings.json" "$TARGET/managed-settings.json" || { say "  DRIFT: managed-settings.json differs from this package's"; bad=1; }
  rm -rf "$tmp"
  # 4. The interpreter the launcher pins, and the chain end to end.
  [ -x "$PYDIR/python3" ] || { say "  BAD: $PYDIR/python3 is missing (xcode-select --install)"; bad=1; }
  smoke "$HOOKS" || bad=1
  [ "$bad" = 0 ] && say "OK: installed, root-owned, current with the plugin."
  return "$bad"
}

dry_run() {
  local tmp rc=0; tmp="$(mktemp -d)"
  say "Dry run in $tmp (nothing outside it changes)"
  say "This would install, root-owned, into $TARGET:"
  say "  managed-settings.json   the guard hooks, in exec form"
  say "  claude-safety/managed-guard     the environment-rebuilding launcher"
  say "  claude-safety/guards/           guard-run.sh and: $(guards | tr '\n' ' ')"
  say "  claude-safety/lib/              safety-config.py"
  say "  claude-safety/config.json       from $CFG_SRC"
  build "$tmp" "$tmp/hooks" "$tmp/logs"; mkdir -p "$tmp/logs"
  say "  system Python: $([ -x "$PYDIR/python3" ] && "$PYDIR/python3" --version 2>&1 | cut -d' ' -f2 || echo 'MISSING (xcode-select --install)')"
  smoke "$tmp/hooks" || rc=1
  rm -rf "$tmp"
  [ "$rc" = 0 ] && say "Dry run OK. Nothing was changed. Run ./install.sh to install for real."
  return "$rc"
}

install_real() {
  local stage
  no_session
  [ -x "$PYDIR/python3" ] || die "$PYDIR/python3 is missing; install the Command Line Tools first (xcode-select --install)"
  if [ -f "$TARGET/managed-settings.json" ] && ! ours "$TARGET/managed-settings.json"; then
    die "$TARGET/managed-settings.json exists and is not this package's. Merge by hand; nothing changed."
  fi
  if [ -e "$HOOKS" ] && [ ! -f "$HOOKS/$MARKER" ]; then
    die "$HOOKS exists but was not installed by this package (no $MARKER). Nothing changed."
  fi
  dry_run || die "the dry run failed; nothing changed"
  say ""; ask "Install the managed guards into $TARGET? (needs your password)" || die "stopped; nothing changed"
  stage="$(mktemp -d)"; build "$stage" "$HOOKS" "$LOGDIR" >/dev/null
  mkdir -p "$LOGDIR"
  "$SUDO" /bin/mkdir -p "$TARGET"
  "$SUDO" /usr/sbin/chown root:wheel "$TARGET"; "$SUDO" /bin/chmod 755 "$TARGET"
  # Scripts first, then the settings that point at them, so no call ever sees a launcher that is
  # not there yet. On a reinstall the previous settings file stays live until the swap.
  "$SUDO" /bin/rm -rf "$HOOKS.new" "$HOOKS.old"
  "$SUDO" /bin/cp -R "$stage/hooks" "$HOOKS.new"
  "$SUDO" /usr/sbin/chown -R root:wheel "$HOOKS.new"
  "$SUDO" /bin/chmod -R 755 "$HOOKS.new"
  [ ! -d "$HOOKS" ] || "$SUDO" /bin/mv "$HOOKS" "$HOOKS.old"
  "$SUDO" /bin/mv "$HOOKS.new" "$HOOKS"
  if ! smoke "$HOOKS"; then
    "$SUDO" /bin/rm -rf "$HOOKS"
    if [ -d "$HOOKS.old" ]; then
      "$SUDO" /bin/mv "$HOOKS.old" "$HOOKS"
      die "the new hooks failed the smoke test; the previous install is back in place and unchanged."
    fi
    die "the installed hooks failed the smoke test, so the settings file was not installed and nothing is active."
  fi
  "$SUDO" /bin/rm -rf "$HOOKS.old"
  "$SUDO" /usr/bin/install -o root -g wheel -m 644 "$stage/managed-settings.json" "$TARGET/.managed-settings.json.new"
  "$SUDO" /bin/mv -f "$TARGET/.managed-settings.json.new" "$TARGET/managed-settings.json"
  rm -rf "$stage"
  say ""; verify && say "Next: ./canary.sh, the acceptance test (a few short headless runs)."
}

uninstall() {
  no_session
  [ -e "$TARGET/managed-settings.json" ] || [ -e "$HOOKS" ] || { say "Nothing installed."; return 0; }
  if [ -f "$TARGET/managed-settings.json" ] && ! ours "$TARGET/managed-settings.json"; then
    die "$TARGET/managed-settings.json is not this package's; not touching it"
  fi
  if [ -e "$HOOKS" ] && [ ! -f "$HOOKS/$MARKER" ]; then
    die "$HOOKS was not installed by this package (no $MARKER); not touching it"
  fi
  ask "Remove $TARGET/managed-settings.json and $HOOKS?" || die "stopped; nothing changed"
  [ ! -f "$TARGET/managed-settings.json" ] || "$SUDO" /bin/rm -f "$TARGET/managed-settings.json"
  "$SUDO" /bin/rm -rf "$HOOKS"
  say "Removed. The plugin's own hooks are unchanged and still run. Logs stay in $LOGDIR."
}

case "${1:-}" in
  --dry-run)   dry_run ;;
  --verify)    verify ;;
  --uninstall) uninstall ;;
  "")          install_real ;;
  *)           die "unknown option $1 (use --dry-run, --verify or --uninstall)" ;;
esac
