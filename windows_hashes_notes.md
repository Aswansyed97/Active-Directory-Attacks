# Windows Password Hashes

How Windows stores credentials as LM and NT hashes, where those hashes live,
and the difference between the NT hash at rest and the NTLM authentication
protocols that use it over the network.

---

## Overview

To avoid storing passwords in plaintext, Windows keeps them as **LM** and
**NT** hashes. (The NT hash is often casually called "NTLM," though that term
really refers to the authentication *protocol* — see
[NT Hash vs NTLM Authentication](#nt-hash-vs-ntlm-authentication) below.)

Where they're stored:

| Account type | Location |
|---|---|
| Local user accounts | **SAM** (Security Account Manager) database |
| Domain user accounts | **NTDS.dit** on a Domain Controller |

Attackers go after these hashes to recover credentials, to authenticate
directly without ever knowing the plaintext (**Pass-the-Hash**), or to crack
them offline with brute-force or dictionary attacks.

---

## LM vs NT at a Glance

| | LM Hash | NT Hash |
|---|---|---|
| Status | Obsolete, disabled by default since Vista / Server 2008 | In active use today |
| Algorithm | DES (applied to a fixed constant) | MD4 of the password |
| Case-sensitive | No — password is uppercased | Yes |
| Salted | No | No |
| Main weakness | Split into two independently crackable 7-char halves | Unsalted → vulnerable to rainbow tables |

---

## LM Hash (LAN Manager)

The original Windows password hash — now obsolete and disabled by default
since Windows Vista / Server 2008, but still occasionally found on legacy
systems.

How it's generated:

1. The password is converted to **uppercase**.
2. It's padded or truncated to exactly **14 characters**.
3. It's split into **two 7-character halves**.
4. Each 7-byte half is used as a DES key to encrypt a fixed, publicly known
   constant string (`"KGS!@#$%"`).
5. The two resulting 8-byte DES outputs are concatenated into a 16-byte hash.

**Why it's weak:** splitting a 14-character password into two independent
7-character halves means each half can be brute-forced separately — a
14-character password is effectively only as strong as a 7-character one.
Uppercasing also discards all case information, shrinking the keyspace
further.

---

## NT Hash (NTHash)

The successor to the LM hash, and the one still in active use.

- Computed as the **MD4 hash of the password encoded in UTF-16LE**.
- **No salt** is used — part of why NT hashes are vulnerable to precomputed
  rainbow table attacks.
- Stored in the SAM (local accounts) or NTDS.dit (domain accounts).
- Held in memory by the **`lsass.exe`** process on a running system — which is
  why credential-dumping tools (e.g. Mimikatz) target that process directly.

---

## NT Hash vs NTLM Authentication

"NTLM" gets used loosely for two different things. Keeping them straight is
what makes the attack paths make sense:

| Term | What it actually is |
|---|---|
| **NT hash** | The password hash itself (MD4 of the UTF-16LE password), stored at rest in SAM / NTDS.dit. |
| **NTLM authentication** (Net-NTLMv1 / Net-NTLMv2) | A challenge-response *protocol* that authenticates over the network using the NT hash — without ever transmitting the password or the raw NT hash. |

Why the distinction drives the attack path:

- A stolen **NT hash** can be used directly in a **Pass-the-Hash** attack — no
  cracking required.
- A captured **Net-NTLMv1/v2 response** (e.g. from an LLMNR/NBT-NS poisoning
  attack via Responder) **cannot** be replayed as-is. It must either be
  **cracked offline** (hashcat — see the
  [Lab Walkthrough](./lab-walkthrough.md)) or **relayed** in real time (see
  [SMB Relay Attack](./smb-relay-attack.md)) to be useful.

---

## Net-NTLM Authentication Protocols

These are the challenge-response protocols that *use* the NT hash to
authenticate over the network — and they are what Responder captures, not the
NT hash at rest.

### Net-NTLMv1

The server sends an **8-byte challenge**; the client encrypts it with DES,
keyed by the user's NT hash (historically the LM hash too, now largely
disabled), and returns the result as its response. Weak — the DES-based scheme
cracks quickly on modern hardware and rainbow tables, with no protection
against relay.

### Net-NTLMv2

The improved successor. Uses **HMAC-MD5** and adds a **client-side challenge**
(timestamp + target info) on top of the server's challenge. Stronger hashing,
a larger effective keyspace, and per-session unique data make it far more
resistant to cracking and replay than v1 — though still crackable offline
against a weak password, and still relayable.

### NTLMv2-SSP

"SSP" means the exchange went through the **Security Support Provider
Interface (SSPI)**, Windows' pluggable auth-negotiation framework. Seeing
`NTLMv2-SSP` (as Responder logs it) typically indicates authentication over
**SMB**, or against a service **outside a domain trust** — consistent with a
`MicrosoftAccount\<user>` (non-domain) capture.

---

## Mitigations

- Disable LM hash storage (default since Vista / Server 2008, but verify via
  Group Policy: *Network security: Do not store LAN Manager hash value on next
  password change*).
- Enforce strong, long passwords so captured NT or Net-NTLM hashes are
  impractical to crack offline.
- Restrict and monitor `lsass.exe` access (Credential Guard, LSA Protection)
  to prevent credential dumping.
- Disable NTLM in favor of Kerberos where possible, and enforce SMB signing to
  block NTLM relay.

---

## Related Notes

- [LLMNR / NBT-NS Poisoning](./LLMNR-NBT-NS-Poisoning.md) — how the Net-NTLMv2
  response gets captured in the first place.
- [Lab Walkthrough](./lab-walkthrough.md) — capturing and cracking a real
  NTLMv2-SSP hash end-to-end.
- [SMB Relay Attack](./smb-relay-attack.md) — using a captured authentication
  without cracking it.
