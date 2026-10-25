# Active Directory Attacks

Study notes and reference material on common Active Directory attack techniques,
how they work, and how to defend against them.

> For authorized testing and educational use only — labs and engagements you
> have explicit permission to test.

## Contents

- [LLMNR / NBT-NS Poisoning](./LLMNR-NBT-NS-Poisoning.md) — abusing Windows
  name-resolution fallback protocols to capture credentials on a local network.
- [Windows Password Hashes](./windows_hashes_notes.md) — LM vs NT hashes, where
  they're stored, and the Net-NTLM authentication protocols (v1/v2/SSP).
- [SMB Relay Attack](./smb-relay-attack.md) — relaying captured authentication to
  another host instead of cracking it, with Responder + ntlmrelayx.
