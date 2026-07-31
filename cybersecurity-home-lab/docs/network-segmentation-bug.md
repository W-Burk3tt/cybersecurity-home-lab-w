# Incident Writeup: Cross-VM Network Unreachability

## Symptom
Early in the lab build, the Ubuntu Server VM could not communicate with
the Domain Controller or Kali VMs at all — no ping response in either
direction, despite all three VMs being intended as part of the same lab
network.

## Isolation
Compared VirtualBox network adapter settings across all three VMs:
- Domain Controller: Adapter 1 → **Internal Network**
- Kali: Adapter 1 → **Internal Network**
- Ubuntu: Adapter 1 → **NAT**

## Root Cause
VirtualBox's NAT and Internal Network modes create two entirely separate,
isolated network segments — they do not bridge to each other under any
circumstance. Ubuntu, on NAT, had no path to reach either the DC or Kali,
both on Internal Network. This wasn't a firewall, IP addressing, or DNS
issue — the VMs were simply never on the same virtual wire.

## Fix
Rather than switch Ubuntu directly to Internal Network (which would have
cut off its internet access, needed for package installation during the
build), Ubuntu was given a second network adapter:
- **Adapter 1: NAT** — retained for internet access (`apt` installs, etc.)
- **Adapter 2: Internal Network** — matching the exact network name used
  by the DC and Kali, joining Ubuntu to the actual lab segment

A static IP was then assigned to the Internal Network adapter specifically,
consistent with the rest of the lab's `10.0.0.0/24` addressing scheme.

## Later Cleanup
Once pfSense was deployed as the lab's router and every VM's default
gateway was pointed at it, Ubuntu's NAT adapter became redundant — pfSense's
own WAN interface (also on NAT) now provided the whole segment's internet
access through a single choke point. The NAT adapter was then removed from
Ubuntu entirely, leaving only the Internal Network adapter, consistent with
every other VM in the lab.

## Lesson
Virtual networking modes that sound similar (NAT vs. Internal Network vs.
Bridged) are not interchangeable and don't degrade gracefully into each
other — they're fully separate broadcast domains by design. When multiple
VMs in a lab can't reach each other and IP addressing looks correct, the
adapter *mode* itself — not just the IP configuration — is worth checking
first.
