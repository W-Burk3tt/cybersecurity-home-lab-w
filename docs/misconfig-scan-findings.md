# Misconfiguration Scan Findings: Ubuntu Server

## Objective
Run a baseline misconfiguration scan (`scripts/misconfig-check.sh`)
against the hardened Ubuntu server to verify prior hardening work
actually took effect, and surface anything unexpected running on the
host.

## Results Summary

### SSH hardening — confirmed enforced
```
PermitRootLogin:        PermitRootLogin no
PasswordAuthentication: PasswordAuthentication no
```
Independent confirmation that the SSH hardening work (see
`ssh-hardening-notes.md`) is genuinely active, not just present-but-
commented in the config file.

### World-writable files and sudoers NOPASSWD entries — clean
No findings in either category. A clean result here is itself worth
recording as a baseline — it confirms the host wasn't left in a loose
state by default, and gives a reference point to compare against if a
future scan turns up something new.

### Listening ports — mostly expected, one investigated
| Port | Service | Assessment |
|---|---|---|
| 22 | sshd | Expected — hardened SSH access |
| 631 (loopback only) | cupsd | Ubuntu's print service. Not network-exposed, but unnecessary for this lab — candidate for disabling to reduce attack surface (`systemctl disable --now cups`) |
| 53 (loopback) | systemd-resolved | Normal local DNS stub resolver, not an exposed DNS server |
| 11434 (loopback) | ollama | **Investigated** — confirmed as a deliberate prior install for local LLM experimentation on this lab host, not unexpected software. Loopback-only, not network-exposed. |
| 40749 (loopback) | containerd | Background container runtime, expected ahead of Week 8 (Docker/DevSecOps work) |

The Ollama entry is a good example of why a misconfiguration scanner is
useful even on a system the operator built themselves — enough time and
enough steps had passed that a piece of intentionally-installed software
no longer stood out as "known" on first glance. Confirming it required a
deliberate pause and check rather than assuming.

### Unowned files — GDM3 artifacts, root cause traced and resolved
All unowned files traced back to `/var/lib/gdm3/seat0/`. GDM (GNOME
Display Manager) provides a graphical login screen — its presence was
unusual on what should have been a headless Ubuntu **Server** install.

**Investigation revealed a bigger finding than a stray package.**
`dpkg -l | grep -i gnome` showed a full GNOME desktop environment
installed — dozens of packages including `gnome-shell`,
`gnome-control-center`, and `gnome-remote-desktop` — all pulled in by a
single metapackage:
```bash
dpkg -l | grep -E "ubuntu-desktop|ubuntu-desktop-minimal"
# ii  ubuntu-desktop-minimal   1.570   amd64   Ubuntu desktop minimal system
```
**Root cause:** the Ubuntu **Desktop** ISO was used at initial install
time, not Server — an easy mix-up between similarly-named downloads. The
host had been running with a full graphical session available the entire
time, confirmed directly when a later `sudo reboot` was blocked with:
```
Operation inhibited by "vboxuser" (PID ... "gnome-session-s", ...)
User vboxuser is logged in on tty2.
```
This proved an active GNOME session was running on the VM's console
display the whole time — simply never noticed, since all prior work was
done exclusively through the text console and SSH.

**Fix:**
```bash
sudo apt purge ubuntu-desktop-minimal -y
sudo apt autoremove -y
sudo apt autoclean
sudo systemctl reboot -i   # -i: override the running-session inhibitor
```
A first re-scan after reboot still showed the same unowned
`/var/lib/gdm3/` files — `apt purge` had removed the `gdm3` package
itself, but left its state/config directory behind under `/var/lib`,
which package managers commonly treat as user data rather than package
files. Confirmed via `dpkg -l | grep gdm3` (package no longer listed),
then manually removed:
```bash
sudo rm -rf /var/lib/gdm3
```
A final scan confirmed zero unowned files.

## Lesson
A misconfiguration scan's value isn't limited to catching things that are
outright wrong — it also surfaces software and services the operator
forgot they'd installed, or never consciously decided to keep running.
What started as a handful of unowned files traced back not to a stray
package, but to the base OS edition itself being wrong from initial
install — a good reminder that a small anomaly is worth following all
the way to its actual source rather than patching the first plausible
cause and moving on. It's also a reminder that a package's data
directories under `/var/lib` don't always get removed by a normal
`purge` — verifying with the package database (`dpkg -l`), not just
re-running the original scan, was what confirmed the real state.
