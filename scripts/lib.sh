#!/usr/bin/env bash
# Shared helpers for the lab scripts. Not meant to be run directly.
#
# These scripts reproduce the workflows documented in the Markdown notes against
# a lab you own. They are thin wrappers: every command they run is spelled out
# in the matching .md page. Nothing here scans or targets anything you do not
# pass in explicitly.

set -euo pipefail

# ----- output helpers --------------------------------------------------------
if [[ -t 1 ]]; then
  _c_red=$'\033[31m'; _c_grn=$'\033[32m'; _c_ylw=$'\033[33m'
  _c_blu=$'\033[34m'; _c_dim=$'\033[2m'; _c_rst=$'\033[0m'
else
  _c_red=''; _c_grn=''; _c_ylw=''; _c_blu=''; _c_dim=''; _c_rst=''
fi

info()  { printf '%s[*]%s %s\n' "$_c_blu" "$_c_rst" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$_c_grn" "$_c_rst" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$_c_ylw" "$_c_rst" "$*" >&2; }
die()   { printf '%s[x]%s %s\n' "$_c_red" "$_c_rst" "$*" >&2; exit 1; }

# Show the exact command, then run it. Keeps the scripts honest: what you see is
# what runs, same as the notes.
run() {
  printf '%s$ %s%s\n' "$_c_dim" "$*" "$_c_rst"
  "$@"
}

# ----- preflight -------------------------------------------------------------
need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' not found on PATH. Install it first (see README)."
}

# Authorization gate. These are offensive tools; only run them against systems
# you own or are explicitly authorized to test. Set LAB_AUTHORIZED=1 to skip the
# prompt in a trusted lab (e.g. from another script).
authorize() {
  local scope="${1:-the target you are about to specify}"
  if [[ "${LAB_AUTHORIZED:-0}" == "1" ]]; then
    return 0
  fi
  warn "You are about to run an offensive technique against: ${scope}"
  warn "Only do this on systems you own or are explicitly authorized to test."
  if [[ ! -t 0 ]]; then
    die "Not an interactive shell and LAB_AUTHORIZED!=1 — refusing to continue."
  fi
  read -r -p "Type 'yes' to confirm you are authorized: " _ans
  [[ "$_ans" == "yes" ]] || die "Not confirmed — aborting."
}

usage_and_exit() {  # usage_and_exit "<usage string>"
  printf 'Usage: %s\n' "$1" >&2
  exit 2
}
