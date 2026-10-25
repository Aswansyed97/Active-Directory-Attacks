# Windows Password Hashes — Notes

## Overview

To store credentials securely, Windows uses LM and NT hashes (NT hash is often casually called "NTLM," though that term technically refers to the authentication protocol — see the distinction below). Hashes of local user accounts are stored in the **SAM** (Security Account Manager) database; domain user hashes are stored in **NTDS.dit** on a Domain Controller.

Attackers target these hashes to recover credentials or to authenticate directly without ever knowing the plaintext password (Pass-the-Hash), and captured hashes can also be cracked offline via brute-force or dictionary attacks.

## LM Hash (LAN Manager)

The original Windows password hash, now considered obsolete and disabled by default since Windows Vista / Server 2008 — but still occasionally found on legacy systems.

How it's generated:
1. The password is converted to **uppercase**.
2. It's padded or truncated to exactly **14 characters**.
3. It's split into **two 7-character halves**.
4. Each 7-byte half is used as a DES encryption key to encrypt a fixed, publicly known constant string (`"KGS!@#$%"`).
5. The two resulting 8-byte DES outputs are concatenated into a 16-byte hash.

**Why it's weak:** splitting a 14-character password into two independent 7-character halves means each half can be brute-forced separately — a 14-character password is effectively only as strong as a 7-character one. Uppercasing also throws away all case information, cutting the keyspace further.

## NT Hash (NTHash)

The successor to the LM hash, and the one still in active use.

- Computed as the **MD4 hash of the password encoded in UTF-16LE**.
- No salt is used, which is part of why NT hashes are vulnerable to precomputed rainbow table attacks.
- Stored in the SAM (local accounts) or NTDS.dit (domain accounts).
- Held in memory by the **`lsass.exe`** process on a running system — which is why credential-dumping tools (e.g. Mimikatz) target that process directly.

## NT Hash vs. NTLM Authentication — an important distinction

"NTLM" gets used loosely to refer to two different things:

| Term | What it is |
|---|---|
| **NT hash** | The actual password hash itself (MD4 of the UTF-16LE password), stored at rest in SAM/NTDS.dit. |
| **NTLM authentication (Net-NTLMv1 / Net-NTLMv2)** | A challenge-response *protocol* used to authenticate over the network using the NT hash, without ever transmitting the password or the raw NT hash itself. |

This distinction matters for attack paths:
- A stolen **NT hash** can be used directly in a **Pass-the-Hash** attack — no cracking required.
- A captured **Net-NTLMv1/v2 response** (e.g. from an LLMNR/NBT-NS poisoning attack via Responder) cannot be replayed as-is. It must either be **cracked offline** (hashcat, as in the LLMNR lab) or **relayed** in real time (NTLM relay attacks) to be useful.

## Hash Evolution — Net-NTLM Authentication Protocols

These are the challenge-response protocols that *use* the NT hash to authenticate over the network. They are what Responder captures — not the NT hash at rest.

**Net-NTLMv1**
The server sends an **8-byte challenge**; the client encrypts it with DES, keyed by the user's NT hash (historically the LM hash too, now largely disabled), and returns the result as the response. Weak — the DES-based scheme is crackable quickly on modern hardware/rainbow tables, with no protection against relay.

**Net-NTLMv2**
The improved successor. Uses **HMAC-MD5** and adds a **client-side challenge** (timestamp + target info) on top of the server's challenge. Stronger hashing, larger effective keyspace, and per-session unique data make it far more resistant to cracking and replay than v1 — though still crackable offline against a weak password, and still relayable.

**NTLMv2-SSP**
"SSP" means the exchange went through the **Security Support Provider Interface (SSPI)**, Windows' pluggable auth-negotiation framework. Seeing `NTLMv2-SSP` (as Responder logs it) typically indicates authentication over **SMB**, or against a service **outside a domain trust** — consistent with a `MicrosoftAccount\<user>` (non-domain) capture.

## Mitigations

- Disable LM hash storage (default since Vista/Server 2008, but verify via Group Policy: *Network security: Do not store LAN Manager hash value on next password change*).
- Enforce strong, long passwords to resist offline cracking of captured NT or Net-NTLM hashes.
- Restrict and monitor `lsass.exe` access (e.g. via Credential Guard, LSA Protection) to prevent credential dumping.
- Disable NTLM where possible in favor of Kerberos, and enforce SMB signing to prevent NTLM relay attacks.
