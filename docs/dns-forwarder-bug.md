# Incident Writeup: External DNS Resolution Failure

## Symptom
After migrating all lab VMs (Domain Controller, Windows 11 client, Kali,
Ubuntu) to route through a newly deployed pfSense router, external domain
resolution failed lab-wide. `ping 8.8.8.8` succeeded from every host —
confirming raw IP routing was healthy — but `ping google.com` and
`nslookup google.com` failed with timeouts on every machine.

## Isolation
Rather than assume the problem was local to the machine where it was first
noticed (Ubuntu), I tested from a second, independent host (the Windows 11
client) and got the same failure. That ruled out a per-host misconfiguration
and pointed at the shared dependency all hosts have in common: the Domain
Controller's DNS service at `10.0.0.10`.

Next, I separated **internal** zone resolution from **external**
resolution to narrow the failure further:

```
nslookup lab.local 10.0.0.10      # succeeded
nslookup google.com 10.0.0.10     # timed out
```

This confirmed the DNS *service* itself was healthy and correctly
authoritative for its own zone — the failure was specific to forwarding
queries it doesn't own, i.e., anything external.

Before concluding it was a forwarder problem, I ruled out the more common
causes first:
- `Get-Service -Name DNS` → Running
- Firewall rule for DNS (UDP, Incoming) → Enabled, all profiles
- `Get-NetConnectionProfile` → DomainAuthenticated (already covered by the
  firewall rule scope)

## Root Cause
```
Get-DnsServerForwarder
```
returned:
```
IPAddress : {fec0:0:0:ffff::1, fec0:0:0:ffff::2, fec0:0:0:ffff::3}
```

These are defunct IPv6 site-local placeholder addresses — legacy Windows
defaults that don't correspond to any real, reachable DNS server. The DC
had never been configured with a working forwarder, so every query it
couldn't answer itself (i.e., every external domain) was being sent into
the void and timing out. This had likely been broken since the DC was
first built, but was masked by the fact that most earlier testing focused
on internal AD name resolution, where it worked fine.

## Fix
```powershell
Set-DnsServerForwarder -IPAddress 8.8.8.8,1.1.1.1
```

## Verification
```
nslookup google.com 10.0.0.10   # resolved successfully (both A and AAAA records)
```
Confirmed the fix cascaded correctly to every dependent host (client, Kali,
Ubuntu) without any client-side changes, since they were all already
correctly pointed at `10.0.0.10` for DNS — the break was entirely upstream.

## Lesson
A DNS server can be fully "Running," fully authoritative for its own zone,
and completely unreachable-looking from a firewall/service-health
standpoint, while still being broken for the one thing most users actually
notice: resolving the outside world. Separating internal vs. external
resolution early — rather than treating "DNS is broken" as one
undifferentiated symptom — is what turned a lab-wide, seemingly random
failure into a two-command fix.
