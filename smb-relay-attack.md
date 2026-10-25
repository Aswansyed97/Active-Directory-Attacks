# SMB Relay Attack — Notes

## When to use it

When a captured hash resists offline cracking (strong password, or you don't want to wait on a wordlist), you don't have to crack it at all. Instead of capturing a Net-NTLM response and cracking it, you **relay it live** to another machine: the victim authenticates, and you forward that authentication to a different target in real time — logging in *as* the victim without ever knowing the password.

## How it fits with Responder

For a relay, Responder only does the **name poisoning** — it must *not* grab the auth itself. So in `/etc/responder/Responder.conf`:

```
SMB  = Off
HTTP = Off
```

Keep `LLMNR`, `NBTNS`, and `MDNS` on. Responder poisons name resolution and leaves SMB/HTTP free; a separate tool — **`ntlmrelayx.py` (Impacket)** — listens on those ports and relays the authentication to a chosen target.

```
ntlmrelayx.py -tf targets.txt -smb2support
```

| Flag | What it does |
|---|---|
| `-tf targets.txt` | Target **file** — list of hosts to relay to (one per line). Use `-t <host>` for a single target. |
| `-smb2support` | Enables SMB2/3 support so the relay works against modern Windows (SMB1 is disabled by default on current systems). |

## Requirements / catches

1. **SMB signing must be disabled on the target.** SMB signing cryptographically ties each message to the session, which breaks a relayed authentication. If the target enforces signing, the relay fails. (This is why "enforce SMB signing" is the real fix, not just generic hardening.)
2. **The relayed account needs local admin on the target.** Relaying a low-priv user just gets a low-priv session; admin is what enables dumping SAM, command execution (psexec-style), or dumping LSASS.
3. **You can't relay credentials back to the machine they came from.** This is NTLM reflection, patched in MS08-068 — source and target of the relay must be different hosts.
4. **Generally one-shot per captured auth.** Once relayed and used (or expired), that authentication is spent; you need a fresh capture to relay again, unless relaying to multiple targets at once.

## Finding targets first

Before setting a target list, enumerate live hosts on the subnet:

```
nmap -sn 192.168.0.0/24
```

| Flag | What it does |
|---|---|
| `-sn` | Host-discovery only (ping scan) — no port scan, just finds which IPs are up. |
| `192.168.0.0/24` | The subnet range (all 256 addresses). Confirm your actual subnet with `ip a` first. |

From the live hosts, pick machines **without SMB signing enforced** as relay targets.

## Mitigations

- **Enforce SMB signing** (required/always) — this alone breaks the relay.
- Disable NTLM in favor of Kerberos where possible.
- Disable LLMNR / NBT-NS so the poisoning that feeds the relay never happens.
- Restrict local admin rights and use unique local admin passwords (LAPS) to limit blast radius.
