#!/usr/bin/env bash
#
# Diffwarden installer.
#
# Places the Diffwarden skill and its optional /dw and /diffwarden command files
# into the right directories for the coding agents you choose (Claude Code,
# Cursor, Codex, and/or Pi Agent), at project scope (current folder) and/or
# global scope (home). Codex reads skills from .agents/skills (invoke with
# $diffwarden or /skills); it does not support custom /dw or /diffwarden slash
# commands. Pi Agent uses skills under .pi/skills/ or ~/.pi/agent/skills/ and
# optional prompt templates under .pi/prompts/ or ~/.pi/agent/prompts/.
#
# It only ever writes under .claude/ , ~/.claude/ , .cursor/ , ~/.cursor/ ,
# .agents/ , ~/.agents/ , .pi/skills/ , .pi/prompts/ , ~/.pi/agent/skills/ ,
# ~/.pi/agent/prompts/ , and ~/.config/diffwarden/ . It never uses sudo, never
# touches anything else, never overwrites a changed file without asking, and
# skips files that are already up to date.
#
# SECURITY: read this script before running it. The recommended way to install
# is download-then-inspect-then-run, not pipe-to-shell. See the README.
#
#   curl -fsSLO https://raw.githubusercontent.com/jperocho/diffwarden/v0.27.0/install.sh
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
#   --codex             Install for Codex only.
#   --pi                Install for Pi Agent only (skill + prompt templates).
#                       (default: every agent whose config dir is detected)
#   --pi-root <path>    Pi Agent root (default: .pi for project,
#                       ~/.pi/agent for global). Writes only under
#                       <pi-root>/skills/ and <pi-root>/prompts/.
#   --project           Install at project scope only (current directory).
#   --global            Install at global scope only ($HOME).
#                       (default: interactive — global recommended)
#   -y, --yes           Non-interactive; global=yes, project=no, config=no
#                       unless DW_INSTALL_GLOBAL, DW_INSTALL_PROJECT, or
#                       DW_INSTALL_CONFIG override.
#   -f, --force         Overwrite files that differ, without prompting.
#   --dry-run           Print the plan and exit; write nothing.
#   --ref <ref>         Git ref/tag to fetch from when run outside the repo
#                       (default: v0.27.0). Ignored when run inside a clone.
#   -h, --help          Show this help and exit.

set -euo pipefail

# --- constants ---------------------------------------------------------------

SKILL_NAME="diffwarden"
DEFAULT_REF="v0.27.0"
RAW_BASE="https://raw.githubusercontent.com/jperocho/diffwarden"
COMMAND_FILES=("dw.md" "diffwarden.md")
PI_PROMPT_FILES=("dw.md" "diffwarden.md")
CONFIG_DIR="$HOME/.config/diffwarden"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CONFIG_CONTENT='orchestration:
  review_model: gpt5.5-xhigh
  fix_code_model: deepseek
  fix_text_model: gpt5.5-low
'

# --- options -----------------------------------------------------------------

WANT_CLAUDE=""
WANT_CURSOR=""
WANT_CODEX=""
WANT_PI=""
PI_ROOT=""
WANT_CONFIG=0
SCOPE_PROJECT=""
SCOPE_GLOBAL=""
ASSUME_YES=0
FORCE=0
DRY_RUN=0
REF="${DW_REF:-$DEFAULT_REF}"

usage() { sed -n '3,50p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)    WANT_CLAUDE=1 ;;
    --cursor)    WANT_CURSOR=1 ;;
    --codex)     WANT_CODEX=1 ;;
    --pi)        WANT_PI=1 ;;
    --pi-root)   PI_ROOT="${2:?--pi-root needs a value}"; shift ;;
    --pi-root=*) PI_ROOT="${1#--pi-root=}" ;;
    --project)   SCOPE_PROJECT=1 ;;
    --global)    SCOPE_GLOBAL=1 ;;
    -y|--yes)    ASSUME_YES=1 ;;
    -f|--force)  FORCE=1 ;;
    --dry-run)   DRY_RUN=1 ;;
    --ref)       REF="${2:?--ref needs a value}"; shift ;;
    --ref=*)     REF="${1#--ref=}" ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; echo "Run with --help." >&2; exit 2 ;;
  esac
  shift
done

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

# shellcheck disable=SC2317 # Called by EXIT trap.
cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
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
  mkdir -p "$TMP_DIR/prompts"
  for f in "${PI_PROMPT_FILES[@]}"; do
    fetch "$base/prompts/$f" "$TMP_DIR/prompts/$f"
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

# --- scope and config prompts ------------------------------------------------

PROJECT_ROOT="$PWD"
GLOBAL_ROOT="$HOME"

tty_readable() { [[ -r /dev/tty ]]; }

ask_yes_no() {
  local prompt="$1" reply
  [[ $ASSUME_YES -eq 1 ]] && return 1
  [[ $DRY_RUN -eq 1 ]] && return 1
  tty_readable || return 1
  read -r -p "$prompt [y/N] " reply </dev/tty 2>/dev/null || return 1
  [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

ask_yes_no_default_yes() {
  local prompt="$1" reply
  [[ $ASSUME_YES -eq 1 ]] && return 0
  [[ $DRY_RUN -eq 1 ]] && return 0
  tty_readable || return 0
  read -r -p "$prompt [Y/n] " reply </dev/tty 2>/dev/null || return 0
  [[ -z "$reply" || "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

env_truthy() {
  local val="${1:-}"
  [[ "$val" == [1yYtT]* || "$val" == [yY][eE][sS] ]]
}

choose_scope() {
  if [[ -n "$SCOPE_PROJECT$SCOPE_GLOBAL" ]]; then return; fi

  if [[ $ASSUME_YES -eq 1 ]]; then
    if [[ -n "${DW_INSTALL_GLOBAL:-}" ]]; then
      env_truthy "$DW_INSTALL_GLOBAL" && SCOPE_GLOBAL=1
    else
      SCOPE_GLOBAL=1
    fi
    if [[ -n "${DW_INSTALL_PROJECT:-}" ]]; then
      env_truthy "$DW_INSTALL_PROJECT" && SCOPE_PROJECT=1
    fi
    return
  fi

  if ask_yes_no_default_yes "Install Diffwarden globally so /dw works in all projects?"; then
    SCOPE_GLOBAL=1
  fi
  if ask_yes_no "Install into current project too?"; then
    SCOPE_PROJECT=1
  fi
  [[ -n "$SCOPE_PROJECT$SCOPE_GLOBAL" ]] || die "No install scope selected."
}

choose_orchestration_config() {
  if [[ $ASSUME_YES -eq 1 ]]; then
    if [[ -n "${DW_INSTALL_CONFIG:-}" ]]; then
      env_truthy "$DW_INSTALL_CONFIG" && WANT_CONFIG=1
    fi
  else
    if ask_yes_no "Configure orchestration model defaults?"; then
      WANT_CONFIG=1
    fi
  fi
}

# --- detect agents -----------------------------------------------------------

has_dir() { [[ -d "$1" ]]; }

detect_summary() {
  local c_proj="no" c_glob="no" u_proj="no" u_glob="no" x_proj="no" x_glob="no"
  local p_proj="no" p_glob="no"
  has_dir "$PROJECT_ROOT/.claude" && c_proj="yes"
  has_dir "$GLOBAL_ROOT/.claude"  && c_glob="yes"
  has_dir "$PROJECT_ROOT/.cursor" && u_proj="yes"
  has_dir "$GLOBAL_ROOT/.cursor"  && u_glob="yes"
  { has_dir "$PROJECT_ROOT/.codex" || has_dir "$PROJECT_ROOT/.agents"; } && x_proj="yes"
  { has_dir "$GLOBAL_ROOT/.codex"  || has_dir "$GLOBAL_ROOT/.agents"; }  && x_glob="yes"
  { has_dir "$PROJECT_ROOT/.pi" || has_dir "$PROJECT_ROOT/.pi/skills"; } && p_proj="yes"
  { has_dir "$GLOBAL_ROOT/.pi/agent" || has_dir "$GLOBAL_ROOT/.pi"; } && p_glob="yes"
  info "Detected config dirs:"
  info "  Claude Code  project(.claude): $c_proj   global(~/.claude): $c_glob"
  info "  Cursor       project(.cursor): $u_proj   global(~/.cursor): $u_glob"
  info "  Codex        project(.agents/.codex): $x_proj   global(~/.agents/~/.codex): $x_glob"
  info "  Pi Agent     project(.pi): $p_proj   global(~/.pi/agent): $p_glob"
}

# Decide default agent set: if user forced neither, pick agents that have a dir
# at the chosen scope; if none detected, ask (or, with -y, default to Claude).
choose_agents() {
  if [[ -n "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX$WANT_PI" ]]; then return; fi
  local claude_seen=0 cursor_seen=0 codex_seen=0 pi_seen=0
  [[ -n "$SCOPE_PROJECT" ]] && {
    has_dir "$PROJECT_ROOT/.claude" && claude_seen=1
    has_dir "$PROJECT_ROOT/.cursor" && cursor_seen=1
    { has_dir "$PROJECT_ROOT/.codex" || has_dir "$PROJECT_ROOT/.agents"; } && codex_seen=1
    { has_dir "$PROJECT_ROOT/.pi" || has_dir "$PROJECT_ROOT/.pi/skills"; } && pi_seen=1
  }
  [[ -n "$SCOPE_GLOBAL" ]] && {
    has_dir "$GLOBAL_ROOT/.claude"  && claude_seen=1
    has_dir "$GLOBAL_ROOT/.cursor"  && cursor_seen=1
    { has_dir "$GLOBAL_ROOT/.codex" || has_dir "$GLOBAL_ROOT/.agents"; } && codex_seen=1
    { has_dir "$GLOBAL_ROOT/.pi/agent" || has_dir "$GLOBAL_ROOT/.pi"; } && pi_seen=1
  }
  if [[ $claude_seen -eq 0 && $cursor_seen -eq 0 && $codex_seen -eq 0 && $pi_seen -eq 0 ]]; then
    if [[ $ASSUME_YES -eq 1 ]]; then
      WANT_CLAUDE=1
      warn "No agent dirs detected; defaulting to Claude Code (--yes)."
    else
      info "No Claude Code, Cursor, Codex, or Pi config dir detected at the chosen scope."
      if ask_yes_no "Install for Claude Code anyway?"; then WANT_CLAUDE=1; fi
      if ask_yes_no "Install for Cursor anyway?"; then WANT_CURSOR=1; fi
      if ask_yes_no "Install for Codex anyway?"; then WANT_CODEX=1; fi
      if ask_yes_no "Install for Pi Agent anyway?"; then WANT_PI=1; fi
    fi
  else
    [[ $claude_seen -eq 1 ]] && WANT_CLAUDE=1
    [[ $cursor_seen -eq 1 ]] && WANT_CURSOR=1
    [[ $codex_seen -eq 1 ]] && WANT_CODEX=1
    [[ $pi_seen -eq 1 ]] && WANT_PI=1
  fi
  [[ -n "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX$WANT_PI" ]] || die "No agents selected; nothing to do."
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
    "$PROJECT_ROOT"/.claude/*|"$PROJECT_ROOT"/.cursor/*|"$PROJECT_ROOT"/.agents/*|"$GLOBAL_ROOT"/.claude/*|"$GLOBAL_ROOT"/.cursor/*|"$GLOBAL_ROOT"/.agents/*) ;;
    *) die "Refusing to write outside known config dirs: $dest" ;;
  esac

  _install_copy "$src" "$dest"
}

# install_pi_file <src> <dest> <pi-root>
install_pi_file() {
  local src="$1" dest="$2" pi_root="$3"
  [[ -f "$src" ]] || die "Missing source file: $src"

  case "$dest" in
    "$pi_root"/skills/*|"$pi_root"/prompts/*) ;;
    *) die "Refusing to write outside Pi skills/prompts dirs: $dest" ;;
  esac

  _install_copy "$src" "$dest"
}

# install_config_file <dest>
install_config_file() {
  local dest="$1"
  case "$dest" in
    "$CONFIG_DIR"/*) ;;
    *) die "Refusing to write outside ~/.config/diffwarden/: $dest" ;;
  esac
  _install_copy_from_string "$CONFIG_CONTENT" "$dest"
}

# _install_copy <src> <dest>
_install_copy() {
  local src="$1" dest="$2"

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

# _install_copy_from_string <content> <dest>
_install_copy_from_string() {
  local content="$1" dest="$2" tmp
  tmp="$(mktemp)"
  printf '%s' "$content" > "$tmp"
  _install_copy "$tmp" "$dest"
  rm -f "$tmp"
}

# resolve_pi_root <scope-root> <default-relative>
resolve_pi_root() {
  local scope_root="$1" default_rel="$2" resolved
  if [[ -n "$PI_ROOT" ]]; then
    resolved="$PI_ROOT"
    if [[ "$resolved" == "~"* ]]; then
      resolved="${resolved/#\~/$HOME}"
    fi
    if [[ "$resolved" != /* ]]; then
      resolved="$scope_root/$resolved"
    fi
  else
    resolved="$scope_root/$default_rel"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -d "$resolved" ]]; then
      (cd "$resolved" && pwd)
    else
      local parent="${resolved%/*}" name="${resolved##*/}"
      if [[ -d "$parent" ]]; then
        printf '%s/%s\n' "$(cd "$parent" && pwd)" "$name"
      else
        printf '%s\n' "$resolved"
      fi
    fi
    return
  fi
  mkdir -p "$resolved"
  (cd "$resolved" && pwd)
}

install_orchestration_config() {
  info "Orchestration config (global):"
  install_config_file "$CONFIG_FILE"
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
  if [[ -n "$WANT_CODEX" ]]; then
    info "Codex ($label):"
    install_file "$SRC_DIR/SKILL.md" "$root/.agents/skills/$SKILL_NAME/SKILL.md"
    info "  → invoke in Codex CLI with \$diffwarden <args> or /skills (not /dw or /diffwarden)."
  fi
  if [[ -n "$WANT_PI" ]]; then
    local pi_root
    if [[ "$label" == "project" ]]; then
      pi_root="$(resolve_pi_root "$root" ".pi")"
    else
      pi_root="$(resolve_pi_root "$root" ".pi/agent")"
    fi
    info "Pi Agent ($label, root=$pi_root):"
    install_pi_file "$SRC_DIR/SKILL.md" "$pi_root/skills/$SKILL_NAME/SKILL.md" "$pi_root"
    for f in "${PI_PROMPT_FILES[@]}"; do
      install_pi_file "$SRC_DIR/prompts/$f" "$pi_root/prompts/$f" "$pi_root"
    done
    info "  → restart Pi Agent or run /reload after installing."
  fi
}

# --- run ---------------------------------------------------------------------

info "Diffwarden installer"
info "===================="
resolve_source
choose_scope
choose_orchestration_config

if [[ -z "$WANT_PI" || -n "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX" ]]; then
  detect_summary
  choose_agents
elif [[ -z "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX" ]]; then
  WANT_PI=1
fi

info ""
info "Plan:"
if [[ -n "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX$WANT_PI" ]]; then
  info "  agents : ${WANT_CLAUDE:+Claude }${WANT_CURSOR:+Cursor }${WANT_CODEX:+Codex }${WANT_PI:+Pi }"
else
  info "  agents : (none)"
fi
info "  scope  : ${SCOPE_PROJECT:+project($PROJECT_ROOT) }${SCOPE_GLOBAL:+global($GLOBAL_ROOT)}"
[[ -n "$PI_ROOT" ]] && info "  pi-root: $PI_ROOT"
[[ $WANT_CONFIG -eq 1 ]] && info "  config : $CONFIG_FILE"
[[ $DRY_RUN -eq 1 ]] && info "  (dry run — no files will be written)"
info ""

if [[ $DRY_RUN -ne 1 && $ASSUME_YES -ne 1 ]]; then
  ask_yes_no "Proceed?" || { info "Aborted."; exit 0; }
fi

if [[ $WANT_CONFIG -eq 1 ]]; then
  install_orchestration_config
fi

if [[ -n "$SCOPE_PROJECT" ]]; then
  install_target "$PROJECT_ROOT" "project"
fi
if [[ -n "$SCOPE_GLOBAL" ]]; then
  install_target "$GLOBAL_ROOT" "global"
fi

info ""
info "Done. installed=$INSTALLED  up-to-date=$SKIPPED  kept-existing=$KEPT"
if [[ $DRY_RUN -ne 1 && $INSTALLED -gt 0 ]]; then
  if [[ -n "$WANT_CLAUDE$WANT_CURSOR$WANT_CODEX$WANT_PI" ]]; then
    info "Restart your agent session (or /clear in Codex, /reload in Pi) to pick up new skills/commands."
  fi
fi
exit 0
