# Active Directory Attacks

Study notes and reference material on common Active Directory attack
techniques — how they work, how they chain together, and how to defend
against them. Each topic pairs the underlying theory with a hands-on lab
capture.

> **For authorized testing and educational use only** — labs and engagements
> you have explicit permission to test.

---

## Contents

- **[LLMNR / NBT-NS Poisoning](./LLMNR-NBT-NS-Poisoning.md)** — abusing Windows
  name-resolution fallback protocols to capture credentials on a local
  network.
- **[Lab Walkthrough](./lab-walkthrough.md)** — the LLMNR/NBT-NS attack
  captured end-to-end with screenshots, from poisoning to cracked password.
- **[Windows Password Hashes](./windows_hashes_notes.md)** — LM vs NT hashes,
  where they're stored, and the Net-NTLM authentication protocols (v1 / v2 /
  SSP).
- **[SMB Relay Attack](./smb-relay-attack.md)** — relaying captured
  authentication to another host instead of cracking it, with Responder +
  ntlmrelayx.

---

## How the Topics Fit Together

The notes follow a single attack chain and the theory that explains each step:

1. **Poison** name resolution with
   [LLMNR / NBT-NS poisoning](./LLMNR-NBT-NS-Poisoning.md) to make a victim
   authenticate to you — see it done in the
   [lab walkthrough](./lab-walkthrough.md).
2. That capture is a **Net-NTLMv2 response**, not a reusable password hash —
   the [hashes notes](./windows_hashes_notes.md) explain the difference and
   why it dictates what you can do next.
3. From there the hash goes one of two ways: **crack it offline**
   ([lab walkthrough](./lab-walkthrough.md)) or **relay it live** to another
   host when the password is too strong to crack
   ([SMB relay attack](./smb-relay-attack.md)).

Suggested reading order: LLMNR/NBT-NS Poisoning → Lab Walkthrough → Windows
Password Hashes → SMB Relay Attack.

---

## Defensive Summary

The same handful of controls breaks most of this chain:

- Disable **LLMNR** and **NBT-NS** so the poisoning step has nothing to answer.
- Enforce **SMB signing** to block NTLM relay.
- Require **long, strong passwords** so captured hashes resist offline
  cracking.
- Prefer **Kerberos over NTLM**, and limit local admin rights (LAPS) to
  contain anything that does get through.

Each document's own *Mitigations* section covers its technique in more detail.
