# Password Spraying — Notes

## What it is

Password spraying flips the usual brute-force ratio: instead of trying **many
passwords against one account** (which trips lockout fast), you try **one
password against many accounts**, then move to the next password and repeat.
Each account only sees one or two login attempts per round, so the attack
stays under most lockout thresholds while still covering a large user base.

It works because, across any sizable org, some fraction of users pick the
same handful of weak, predictable passwords (`Summer2026!`, `CompanyName123`,
`Password1`, season/year combos, etc.) — spraying is a numbers game betting on
that overlap.

## Building the inputs

**Username list** — the real bottleneck. Sources:
- OSINT (LinkedIn, company site) fed into a name-permutation tool to generate
  `firstname.lastname`, `flastname`, etc. in the org's actual format.
- Unauthenticated enumeration against the DC itself, e.g. Kerberos
  pre-auth username validation:
  ```
  kerbrute userenum -d domain.local --dc 192.168.0.10 users.txt
  ```
  (valid usernames return `PREAUTH_FAILED` or success; invalid ones return
  `UNKNOWN_PRINCIPAL`, so the tool can tell them apart without ever supplying
  a password.)

**Password list** — kept deliberately *small* (3–10 candidates), not a huge
wordlist, because every password tried is another round that risks lockouts
org-wide. Favor likely-reused, policy-compliant guesses: current season +
year, company name + symbol, `Welcome1!`, previous breach-dump favorites.

## How it works

```
kerbrute passwordspray -d domain.local --dc 192.168.0.10 users.txt 'Summer2026!'
```

| Flag | What it does |
|---|---|
| `-d domain.local` | Target AD domain. |
| `--dc <ip>` | Domain controller to send Kerberos AS-REQs to. |
| `users.txt` | One username per line — the enumerated/generated list. |
| `'Summer2026!'` | The single password tried against every username in the list this round. |

Kerbrute uses Kerberos pre-authentication (AS-REQ/AS-REP) rather than NTLM, so
it's lighter-weight and doesn't generate the same SMB/NTLM auth logs — though
it still produces Kerberos auth failure events (see Detection below).

For spraying over SMB/WinRM/LDAP instead (e.g. once you already have a
foothold and want to hunt for password reuse laterally), **NetExec** (the
CrackMapExec successor) is the common tool:

```
netexec smb 192.168.0.0/24 -u users.txt -p 'Summer2026!' --continue-on-success
```

| Flag | What it does |
|---|---|
| `smb 192.168.0.0/24` | Protocol and target range — tries every live host on the subnet. |
| `-u users.txt -p '...'` | Username list against one password (the "spray" shape, not `-p passwords.txt` against one user). |
| `--continue-on-success` | Keep spraying remaining accounts after a hit instead of stopping. |

## Staying under the lockout threshold

### Recon the policy first — don't guess it

Before a single password gets tried, enumerate the domain's *actual* lockout
policy — don't assume defaults or pick a "safe-sounding" interval. This
matters regardless of whether you already hold one valid credential (as in
the [lab walkthrough](./password-spraying-lab-walkthrough.md)) or are going
in cold:

```
nxc smb 192.168.0.129 -u sservice -p Sy3d@001 --pass-pol
```

This returns the real lockout threshold, lockout duration, and observation
window straight from the DC — the numbers the math below depends on. In a
lab you can get away with spraying on a hunch since nothing is watching and
a lockout just means re-running a step; in a real environment, guessing
wrong locks out real users, generates a flood of alerts, and burns the
engagement's stealth in one round. Recon the policy, *then* spray — never
the other way around.

This is the part that makes spraying viable instead of just "slow brute
force." AD account lockout policy (`Default Domain Policy` or a fine-grained
PSO) defines:

- **Lockout threshold** — failed attempts allowed before lockout (e.g. 5).
- **Observation window** — the span those failures are counted over (e.g. 30
  minutes) — a failure outside this window doesn't count toward the total.
- **Lockout duration** — how long the account stays locked (or until an
  admin unlocks it).

The attacker's rule of thumb: never exceed `threshold − 1` attempts per
account within one observation window. Practically, that means **one
password per round, with a delay between rounds longer than the observation
window** (e.g. one password every 30–45 minutes against a 5-attempt/30-minute
policy) — slow by brute-force standards, but it never trips a single
lockout, which is the whole point.

## After a hit

A spray rarely stops at the first account it lands on. Check whether the
same password was reused elsewhere, and prioritize any hit that also shows
up as a (current or former) privileged account — e.g. an LDAP query for
accounts with `adminCount=1` set by AdminSDHolder. See the
[lab walkthrough](./password-spraying-lab-walkthrough.md#8-after-a-hit--find-whats-actually-worth-targeting)
for a worked example.

## Mitigations

- **Smart/graduated lockout** (e.g. Entra ID Smart Lockout) that recognizes
  spray patterns — same password, many accounts, many source IPs — rather
  than relying on a flat per-account threshold alone.
- **MFA** on all accounts, especially anything externally exposed (VPN,
  OWA/M365, VDI) — a correct sprayed password alone no longer suffices.
- **Long passphrases over complexity rules** — length resists the small,
  predictable guess lists spraying relies on better than forced special
  characters do.
- **Monitor Kerberos pre-auth failures (Event ID 4768/4771) and SMB/LDAP bind
  failures** aggregated by *password/time window across many accounts*, not
  just per-account thresholds — that pattern is the spray signature.
- **Honey/canary accounts** — a never-used account that alerts on any login
  attempt is a cheap, high-confidence tripwire for spraying tools sweeping a
  username list.
- **Disable legacy auth protocols** (basic auth, older NTLM) where spraying
  tools find it easiest to operate unnoticed.
