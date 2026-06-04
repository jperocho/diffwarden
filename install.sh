#!/usr/bin/env bash
#
# Diffwarden installer.
#
# Places the Diffwarden skill and its optional /dw and /diffwarden slash-command
# files into the right directories for the coding agents you choose (Claude Code
# and/or Cursor), at project scope (current folder) and/or global scope (home).
#
# It only ever writes under .claude/ , ~/.claude/ , .cursor/ , and ~/.cursor/ .
# It never uses sudo, never touches anything else, never overwrites a changed
# file without asking, and skips files that are already up to date.
#
# SECURITY: read this script before running it. The recommended way to install
# is download-then-inspect-then-run, not pipe-to-shell. See the README.
#
#   curl -fsSLO https://raw.githubusercontent.com/jperocho/diffwarden/v0.10.2/install.sh
#   less install.sh        # read it
#   bash install.sh        # then run it
#
# Or just clone the repo and run ./install.sh from inside it (no network needed).
#
# Usage:
#   install.sh [options]
#
# Options:
#   --claude            Install for Claude Code only.
#   --cursor            Install for Cursor only.
#                       (default: every agent whose config dir is detected)
#   --project           Install at project scope only (current directory).
#   --global            Install at global scope only ($HOME).
#                       (default: project scope)
#   -y, --yes           Non-interactive; accept detected agents and defaults.
#   -f, --force         Overwrite files that differ, without prompting.
#   --dry-run           Print the plan and exit; write nothing.
#   --ref <ref>         Git ref/tag to fetch from when run outside the repo
#                       (default: v0.10.2). Ignored when run inside a clone.
#   -h, --help          Show this help and exit.

set -euo pipefail

# --- constants ---------------------------------------------------------------

SKILL_NAME="diffwarden"
DEFAULT_REF="v0.10.2"
RAW_BASE="https://raw.githubusercontent.com/jperocho/diffwarden"
COMMAND_FILES=("dw.md" "diffwarden.md")

# --- options -----------------------------------------------------------------

WANT_CLAUDE=""
WANT_CURSOR=""
SCOPE_PROJECT=""
SCOPE_GLOBAL=""
ASSUME_YES=0
FORCE=0
DRY_RUN=0
REF="${DW_REF:-$DEFAULT_REF}"

usage() { sed -n '3,55p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)  WANT_CLAUDE=1 ;;
    --cursor)  WANT_CURSOR=1 ;;
    --project) SCOPE_PROJECT=1 ;;
    --global)  SCOPE_GLOBAL=1 ;;
    -y|--yes)  ASSUME_YES=1 ;;
    -f|--force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --ref)     REF="${2:?--ref needs a value}"; shift ;;
    --ref=*)   REF="${1#--ref=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; echo "Run with --help." >&2; exit 2 ;;
  esac
  shift
done

# Default agent selection: decide after detection if none forced.
# Default scope: project, unless --global given.
if [[ -z "$SCOPE_PROJECT$SCOPE_GLOBAL" ]]; then SCOPE_PROJECT=1; fi

info()  { printf '%s\n' "$*"; }
warn()  { printf 'WARN: %s\n' "$*" >&2; }
die()   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- locate the source files (local clone preferred, else fetch) -------------

SELF="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$SELF" && -f "$SELF" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
fi

SRC_DIR=""        # directory containing SKILL.md and commands/
TMP_DIR=""

cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

resolve_source() {
  local local_skill="$SCRIPT_DIR/skills/$SKILL_NAME/SKILL.md"
  if [[ -n "$SCRIPT_DIR" && -f "$local_skill" ]]; then
    SRC_DIR="$SCRIPT_DIR/skills/$SKILL_NAME"
    info "Source: local clone ($SRC_DIR)"
    return
  fi

  # Not in a clone — fetch the needed files from the pinned ref.
  command -v curl >/dev/null 2>&1 || die "curl not found and not running inside a repo clone."
  info "Source: fetching ref '$REF' from github (raw)"
  TMP_DIR="$(mktemp -d)"
  mkdir -p "$TMP_DIR/commands"
  local base="$RAW_BASE/$REF/skills/$SKILL_NAME"
  fetch "$base/SKILL.md" "$TMP_DIR/SKILL.md"
  local f
  for f in "${COMMAND_FILES[@]}"; do
    fetch "$base/commands/$f" "$TMP_DIR/commands/$f"
  done
  # sanity: SKILL.md must look like a skill (YAML frontmatter)
  IFS= read -r firstline < "$TMP_DIR/SKILL.md" || true
  [[ "$firstline" == "---" ]] || die "Fetched SKILL.md does not start with '---'; refusing to install."
  SRC_DIR="$TMP_DIR"
}

fetch() {
  local url="$1" out="$2"
  curl -fsSL --proto '=https' --tlsv1.2 "$url" -o "$out" \
    || die "Download failed: $url"
  [[ -s "$out" ]] || die "Downloaded empty file: $url"
}

# --- detect agents -----------------------------------------------------------

PROJECT_ROOT="$PWD"
GLOBAL_ROOT="$HOME"

has_dir() { [[ -d "$1" ]]; }

detect_summary() {
  local c_proj="no" c_glob="no" u_proj="no" u_glob="no"
  has_dir "$PROJECT_ROOT/.claude" && c_proj="yes"
  has_dir "$GLOBAL_ROOT/.claude"  && c_glob="yes"
  has_dir "$PROJECT_ROOT/.cursor" && u_proj="yes"
  has_dir "$GLOBAL_ROOT/.cursor"  && u_glob="yes"
  info "Detected config dirs:"
  info "  Claude Code  project(.claude): $c_proj   global(~/.claude): $c_glob"
  info "  Cursor       project(.cursor): $u_proj   global(~/.cursor): $u_glob"
}

# Decide default agent set: if user forced neither, pick agents that have a dir
# at the chosen scope; if none detected, ask (or, with -y, default to Claude).
choose_agents() {
  if [[ -n "$WANT_CLAUDE$WANT_CURSOR" ]]; then return; fi
  local claude_seen=0 cursor_seen=0
  [[ -n "$SCOPE_PROJECT" ]] && { has_dir "$PROJECT_ROOT/.claude" && claude_seen=1; has_dir "$PROJECT_ROOT/.cursor" && cursor_seen=1; }
  [[ -n "$SCOPE_GLOBAL"  ]] && { has_dir "$GLOBAL_ROOT/.claude"  && claude_seen=1; has_dir "$GLOBAL_ROOT/.cursor"  && cursor_seen=1; }
  if [[ $claude_seen -eq 0 && $cursor_seen -eq 0 ]]; then
    if [[ $ASSUME_YES -eq 1 ]]; then
      WANT_CLAUDE=1
      warn "No agent dirs detected; defaulting to Claude Code (--yes)."
    else
      info "No Claude Code or Cursor config dir detected at the chosen scope."
      ask_yes_no "Install for Claude Code anyway?" && WANT_CLAUDE=1
      ask_yes_no "Install for Cursor anyway?"      && WANT_CURSOR=1
    fi
  else
    [[ $claude_seen -eq 1 ]] && WANT_CLAUDE=1
    [[ $cursor_seen -eq 1 ]] && WANT_CURSOR=1
  fi
  [[ -n "$WANT_CLAUDE$WANT_CURSOR" ]] || die "No agents selected; nothing to do."
}

ask_yes_no() {
  local prompt="$1" reply
  [[ $ASSUME_YES -eq 1 ]] && return 0
  read -r -p "$prompt [y/N] " reply </dev/tty || return 1
  [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

# --- install one file --------------------------------------------------------

INSTALLED=0
SKIPPED=0
KEPT=0

# install_file <src> <dest>
install_file() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || die "Missing source file: $src"

  # Defense in depth: dest must live under a known root.
  case "$dest" in
    "$PROJECT_ROOT"/.claude/*|"$PROJECT_ROOT"/.cursor/*|"$GLOBAL_ROOT"/.claude/*|"$GLOBAL_ROOT"/.cursor/*) ;;
    *) die "Refusing to write outside known config dirs: $dest" ;;
  esac

  if [[ -f "$dest" ]]; then
    if cmp -s "$src" "$dest"; then
      info "  = up to date   $dest"
      SKIPPED=$((SKIPPED+1)); return
    fi
    info "  ~ differs       $dest"
    if [[ $FORCE -ne 1 ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then KEPT=$((KEPT+1)); return; fi
      if command -v diff >/dev/null 2>&1; then
        diff -u "$dest" "$src" | sed 's/^/      /' || true
      fi
      if ! ask_yes_no "    Overwrite this file?"; then
        info "  - kept existing $dest"
        KEPT=$((KEPT+1)); return
      fi
    fi
  else
    info "  + new           $dest"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then INSTALLED=$((INSTALLED+1)); return; fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  INSTALLED=$((INSTALLED+1))
}

# install_target <root> <scope-label>
install_target() {
  local root="$1" label="$2" f
  if [[ -n "$WANT_CLAUDE" ]]; then
    info "Claude Code ($label):"
    install_file "$SRC_DIR/SKILL.md" "$root/.claude/skills/$SKILL_NAME/SKILL.md"
    for f in "${COMMAND_FILES[@]}"; do
      install_file "$SRC_DIR/commands/$f" "$root/.claude/commands/$f"
    done
  fi
  if [[ -n "$WANT_CURSOR" ]]; then
    info "Cursor ($label):"
    install_file "$SRC_DIR/SKILL.md" "$root/.cursor/skills/$SKILL_NAME/SKILL.md"
    for f in "${COMMAND_FILES[@]}"; do
      install_file "$SRC_DIR/commands/$f" "$root/.cursor/commands/$f"
    done
  fi
}

# --- run ---------------------------------------------------------------------

info "Diffwarden installer"
info "===================="
resolve_source
detect_summary
choose_agents

info ""
info "Plan:"
info "  agents : ${WANT_CLAUDE:+Claude }${WANT_CURSOR:+Cursor}"
info "  scope  : ${SCOPE_PROJECT:+project($PROJECT_ROOT) }${SCOPE_GLOBAL:+global($GLOBAL_ROOT)}"
[[ $DRY_RUN -eq 1 ]] && info "  (dry run — no files will be written)"
info ""

if [[ $DRY_RUN -ne 1 && $ASSUME_YES -ne 1 ]]; then
  ask_yes_no "Proceed?" || { info "Aborted."; exit 0; }
fi

[[ -n "$SCOPE_PROJECT" ]] && install_target "$PROJECT_ROOT" "project"
[[ -n "$SCOPE_GLOBAL"  ]] && install_target "$GLOBAL_ROOT"  "global"

info ""
info "Done. installed=$INSTALLED  up-to-date=$SKIPPED  kept-existing=$KEPT"
if [[ $DRY_RUN -ne 1 && $INSTALLED -gt 0 && -n "$WANT_CLAUDE" ]]; then
  info "Claude Code loads skills/commands at session start — restart or /clear to pick them up."
fi
