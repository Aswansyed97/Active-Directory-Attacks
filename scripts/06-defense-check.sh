#!/usr/bin/env bash
# Defensive counterpart: check whether a host resists the attacks in these notes.
# Mirrors the "Defending against this" sections across the notes.
#
# Read-only. Verifies the two controls that break most of the chain:
#   - SMB signing required  -> kills SMB relay (smb-relay-attack.md)
#   - account lockout policy -> blunts password spraying (password-spraying.md)
# LLMNR/NBT-NS are disabled by Group Policy on the endpoints, not probed here;
# use ./01-responder-poison.sh -A to confirm nothing answers broadcasts.

cd "$(dirname "$0")"
source ./lib.sh

HOST="" USER="" PASS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -H|--host) HOST="${2:-}"; shift 2 ;;
    -u|--user) USER="${2:-}"; shift 2 ;;
    -p|--pass) PASS="${2:-}"; shift 2 ;;
    -h|--help) usage_and_exit "$0 -H <host> [-u <user> -p <pass>]" ;;
    *)         shift ;;
  esac
done

[[ -n "$HOST" ]] || usage_and_exit "$0 -H <host> [-u <user> -p <pass>]"

info "SMB signing (relay resistance) on $HOST:"
if command -v nmap >/dev/null 2>&1; then
  run nmap --script smb2-security-mode -p445 "$HOST" || warn "nmap probe failed"
  info "Look for 'Message signing enabled and required' — that host cannot be relayed to."
else
  warn "nmap not installed; skipping signing probe."
fi

if [[ -n "$USER" && -n "$PASS" ]]; then
  need nxc
  echo
  info "Account lockout policy (spray resistance) on $HOST:"
  run nxc smb "$HOST" -u "$USER" -p "$PASS" --pass-pol || warn "pass-pol query failed"
  info "A non-zero lockout threshold with a sane window is what makes spraying costly."
fi

echo
ok  "Reminder — the controls that break the chain in these notes:"
echo "    - Disable LLMNR and NBT-NS via Group Policy"
echo "    - Require SMB signing"
echo "    - Long passphrases + MFA + smart lockout"
echo "    - Prefer Kerberos over NTLM; scope local admin (LAPS)"
