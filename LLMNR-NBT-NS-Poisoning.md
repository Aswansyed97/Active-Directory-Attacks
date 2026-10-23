# LLMNR / NBT-NS Poisoning

How Windows name-resolution fallback protocols (LLMNR and NBT-NS) can be abused
on a local network to capture credentials.

---

## Broadcasting: DNS Lookup Order

When a Windows client resolves a name, it works through the following order.
The last two steps (LLMNR and NBT-NS) are the fallback protocols that make this
attack possible.

1. **Local DNS Cache**
   A client searches for a domain on the network, such as `www.hackeru.com`. It
   first looks for the IP address in its local DNS cache.

2. **Root DNS Query**
   If the local cache has no record, the client's configured DNS server queries
   the root DNS servers for the location of the `.com` TLD servers.

3. **TLD DNS Query**
   After receiving the location of the `.com` DNS servers, the DNS server queries
   them for the authoritative name server of `hackeru.com`, then queries that
   server for the IP address of `www.hackeru.com`.

4. **LLMNR**
   If DNS cannot resolve the name, the computer checks its LLMNR cache. If no
   match is found there, it sends a multicast query (LLMNR) across the local
   subnet.

5. **NBT-NS**
   If LLMNR cannot resolve the name, the computer falls back to NetBIOS Name
   Service (NBT-NS), broadcasting a request to find the destination computer's
   NetBIOS name.

---

## The Protocols

### NBT-NS
NetBIOS Name Service (NBT-NS) predates LLMNR and is used to resolve names when
DNS fails. A computer broadcasts a query across the local network asking which
host owns a given NetBIOS name. Attackers can exploit this by responding to the
broadcast and impersonating the requested name, tricking the victim into
connecting to the attacker's machine instead.

### LLMNR
Link-Local Multicast Name Resolution (LLMNR) is the successor to NBT-NS, serving
the same fallback role — resolving a name locally via multicast when DNS
resolution fails. Like NBT-NS, its mechanism lets an attacker on the same
network segment respond to the multicast query and impersonate the target host,
capturing credentials or redirecting traffic.

---

## How LLMNR Poisoning Works

LLMNR poisoning (also called LLMNR/NBT-NS spoofing) abuses the fact that these
fallback protocols trust *any* response on the local network — there is no
authentication, and the first reply wins.

| Step | What happens |
|------|--------------|
| 1. Trigger | A client tries to resolve a name and DNS fails (mistyped hostname, a share that no longer exists, an auto-lookup, etc.). Windows falls back to LLMNR, then NBT-NS, broadcasting the request to the local subnet. |
| 2. Attacker responds | An attacker on the same segment (e.g. using **Responder**) listens for these queries. Because nothing verifies who may answer, the attacker replies "that's me" — claiming to be whatever name the victim was looking for. |
| 3. Victim connects | The victim's machine trusts the spoofed response and tries to authenticate to the attacker's machine, commonly over SMB. |
| 4. Credential capture | During authentication the victim sends an **NTLMv2 hash** (challenge/response), which the attacker captures. |

The captured hash can then be:

- **Cracked offline** with hashcat or John the Ripper to recover the plaintext
  password, or
- **Relayed in real time** to another machine (NTLM relay, e.g. via
  **ntlmrelayx**) to authenticate as the victim elsewhere — which can lead to
  code execution if relayed to a host where that user has admin rights.

**Why it works:** LLMNR and NBT-NS have no authentication for who is allowed to
answer a name query — a trust-everyone-on-the-LAN design, which is exactly what
makes them exploitable.

---

## Mitigations

- Disable LLMNR via Group Policy
  (`Computer Configuration → Administrative Templates → Network → DNS Client →
  Turn off multicast name resolution`).
- Disable NBT-NS on each adapter (or via DHCP option 001 / a startup script).
- Enforce **SMB signing** to block NTLM relay.
- Use long, strong passwords so captured NTLMv2 hashes are impractical to crack.

---

> **For authorized testing only.** These techniques are documented for learning
> and for use in labs or engagements you have explicit permission to test.
