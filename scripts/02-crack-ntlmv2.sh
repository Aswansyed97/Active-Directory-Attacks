#!/usr/bin/env bash
# Crack a captured Net-NTLMv2 hash offline with hashcat.
# Mirrors: lab-walkthrough.md ("hashcat -m 5600 ...") and windows_hashes_notes.md
#
# Mode 5600 is Net-NTLMv2 (what Responder captures). Pass the file Responder
# wrote and, optionally, a wordlist (defaults to rockyou).

cd "$(dirname "$0")"
source ./lib.sh

HASHFILE=""
WORDLIST="/usr/share/wordlists/rockyou.txt"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wordlist) WORDLIST="${2:-}"; shift 2 ;;
    -h|--help)     usage_and_exit "$0 <ntlmv2-hash-file> [-w <wordlist>]" ;;
    *)             HASHFILE="$1"; shift ;;
  esac
done

[[ -n "$HASHFILE" ]] || usage_and_exit "$0 <ntlmv2-hash-file> [-w <wordlist>]"
[[ -f "$HASHFILE" ]] || die "Hash file not found: $HASHFILE"
[[ -f "$WORDLIST" ]] || die "Wordlist not found: $WORDLIST (point -w at one, or gunzip rockyou)"
need hashcat

info "Cracking Net-NTLMv2 (mode 5600) in '$HASHFILE' against '$WORDLIST'."
run hashcat -m 5600 "$HASHFILE" "$WORDLIST"
info "Re-run with --show to reprint cracked results:  hashcat -m 5600 '$HASHFILE' --show"
