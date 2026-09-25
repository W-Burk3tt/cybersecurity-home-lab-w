# Implementation Notes: SSH Key-Based Authentication and Hardening (Ubuntu)

## Objective
Replace password authentication with key-based authentication for SSH
access to the Ubuntu server, and disable root login entirely — standard
baseline hardening for any Linux host, and one of the most commonly
expected items on a real hardening checklist.

## Finding 1: The physical host has no network path into the lab
Early attempts to generate and copy an SSH key were run from the physical
Windows laptop's own PowerShell, not from any VM. Every attempt to reach
Ubuntu (`10.0.0.40`) from there failed with "Connection timed out."

Root cause: every lab VM (DC, client, Kali, Ubuntu) uses VirtualBox's
**Internal Network** mode, which by design isolates guest VMs from the
host machine entirely — it's meant purely for VM-to-VM traffic, with no
path back to the physical host. Confirmed via `ipconfig /all` on the real
laptop: its only VirtualBox-related adapter was a Host-Only adapter on an
unrelated subnet (`192.168.56.0/24`), never used by this lab.

**Resolution:** all SSH work had to be performed from the domain-joined
Windows 11 client VM (`10.0.0.20`), which sits on the lab's actual
`10.0.0.0/24` network — not from the physical laptop. This is also the
more realistic setup: in a real environment, admins manage domain
infrastructure from a machine that's actually joined to that network, not
from an unmanaged personal device.

## Finding 2: Visually identical VM windows caused repeated session confusion
Even after correcting course to the client VM, several subsequent
commands were unintentionally run inside the Ubuntu VM's own terminal
instead — confirmed by comparing file paths in verbose SSH debug output
(`/home/vboxuser/.ssh/...`, a Linux path) against expected Windows paths
(`C:\Users\vboxuser\.ssh\...`). At one point this resulted in Ubuntu
attempting to SSH into itself.

**Resolution / working habit adopted:** run `hostname` as the first
command in any terminal before executing anything else. Client returns a
name starting with `Windows-11-Ent...`; Ubuntu returns `UbuntuLab`. The
VirtualBox window's title bar (`<VM Name> [Running] - Oracle VirtualBox`)
is also an unambiguous, always-visible identifier.

## Finding 3: Commented config lines are inert, not "already set to default"
After editing `/etc/ssh/sshd_config` in `nano` and restarting the SSH
service, key-based login worked, but a follow-up check showed:
```
#PermitRootLogin no
#PasswordAuthentication no
```
Both lines were present with the intended values — but commented out
(`#`) — meaning neither setting was actually active; sshd was still
running its compiled-in defaults. A commented line documents a value, it
does not enforce it.

This was compounded by a `nano` usability trap: an accidental `Ctrl+O`
triggered nano's "Write Out" filename prompt, and every subsequent
keystroke was typed into that filename field rather than the document —
which looked identical to a frozen terminal until recognized.

**Fix — bypassed nano entirely in favor of a scriptable, verifiable edit:**
```bash
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
```
Verified with:
```bash
grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config
```
Confirmed both lines present with **no leading `#`**, then applied with:
```bash
sudo systemctl restart ssh
```

## Verification
With the existing SSH session left open as a safety net, a **second,
independent** terminal on the client was used to test:
```bash
ssh vboxuser@10.0.0.40
```
Result: instant login, no password prompt, confirmed via verbose output
(`Authenticated to 10.0.0.40 ... using "publickey"`).

## Lesson
Two separate lessons, both worth carrying forward:
1. **Network topology determines where administrative work can actually
   happen.** Assuming "my laptop" and "the lab" are on the same network
   is an easy but costly assumption to get wrong — always confirm which
   machine actually has a path to the target before troubleshooting the
   target itself.
2. **A config file showing the value you want isn't the same as that
   value being active.** Always verify enforced state (`grep` for the
   uncommented line, or better, test the actual behavior) rather than
   trusting that an edited-looking file means an applied setting.
