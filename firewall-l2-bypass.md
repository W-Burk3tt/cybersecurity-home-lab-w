# Incident Writeup: Firewall Rule Not Enforcing Between Same-Subnet Hosts

## Symptom
A pfSense rule was created to block Kali (`10.0.0.30`) from reaching the
Domain Controller (`10.0.0.10`) on TCP port 3389 (RDP). After confirming
RDP was actually listening on the DC, testing from Kali still showed the
connection succeeding:
```
nc -vz 10.0.0.10 3389
(UNKNOWN) [10.0.0.10] 3389 (ms-wbt-server) open
```

## Isolation
Worked through the rule configuration methodically rather than assuming
the rule engine itself was broken:
1. Confirmed the rule wasn't disabled (checkbox unchecked, as expected)
2. Confirmed rule order — the block rule sat above the default "allow LAN
   to any" rule, so ordering wasn't masking it
3. Found and fixed an actual typo — the Destination field originally read
   `10.0.0.0` instead of `10.0.0.10` — but the connection still succeeded
   after correcting it
4. Checked **Diagnostics → States** for a stale cached connection that
   might be bypassing rule re-evaluation — found nothing. An empty state
   table for this traffic turned out to be the actual clue, not a dead end.

## Root Cause
Kali and the DC are on the same subnet (`10.0.0.0/24`) and the same
VirtualBox Internal Network — the same Layer 2 broadcast domain. Traffic
between two hosts on the same subnet is **switched** via ARP, not
**routed**. It goes directly host-to-host and never actually transits
pfSense's LAN interface at all.

Firewall rules on an interface can only act on traffic that passes through
that interface. Since host-to-host traffic on a flat subnet never reaches
pfSense in the first place, the rule was — correctly, by design — never
being evaluated. This wasn't a misconfiguration; it's expected behavior
for any stateful firewall sitting at Layer 3 while the hosts it's meant to
separate remain adjacent at Layer 2.

## Why No Fix Was Applied
The lab's current design places every host on one flat `10.0.0.0/24`
subnet for simplicity. Actually enforcing this rule would require genuine
network segmentation — giving Kali its own subnet/VLAN on a separate
pfSense interface, so that traffic to the DC has to route through pfSense
rather than switch directly to it. That's a real, valuable follow-up
project, but a meaningfully larger change than a rule fix, and wasn't
necessary for the rest of the lab's goals — so it's documented here as a
finding rather than implemented.

## What Would Actually Fix It
- Add a second internal interface on pfSense (e.g., an "Attacker" VLAN or
  subnet, `10.0.1.0/24`)
- Move Kali onto that new subnet
- Traffic from Kali to the DC would then have no choice but to route
  through pfSense to cross subnets, making the block rule meaningful
- This is the same principle behind real-world network segmentation:
  VLANs exist specifically to force traffic between security zones
  through a filtering point, rather than allowing lateral movement across
  a flat network

## Lesson
A correctly written, correctly ordered, enabled firewall rule can still do
nothing at all if the traffic it's meant to control never physically
passes through the firewall. Rule syntax and network topology are two
separate layers of the same problem, and it's possible to get the first
one perfectly right while the second one silently defeats it. This is
also the practical argument for VLAN segmentation in real environments —
without it, a firewall between "trusted" and "untrusted" hosts on the same
flat subnet is largely decorative for host-to-host traffic.
