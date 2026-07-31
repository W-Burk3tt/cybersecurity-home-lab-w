# Cybersecurity Home Lab

A self-built simulated enterprise environment, constructed on a single
16GB Windows 11 laptop using VirtualBox. Built as hands-on practice
alongside a Bachelor's in Cybersecurity and Information Assurance, with a
focus on Active Directory/IAM, network infrastructure, and — just as
importantly — real troubleshooting under resource constraints.

## Architecture

| Host | Role | IP | OS |
|---|---|---|---|
| pfSense | Router / Firewall | 10.0.0.1 | pfSense CE 2.7.2 |
| DC01 | Domain Controller / DNS | 10.0.0.10 | Windows Server 2022 |
| Client01 | Domain-joined workstation | 10.0.0.20 | Windows 11 Enterprise |
| Kali | Attacker / testing box | 10.0.0.30 | Kali Linux |
| Ubuntu | Linux server | 10.0.0.40 | Ubuntu Server LTS |

All hosts route through pfSense as a single gateway/choke point rather than
relying on individual NAT adapters — WAN-side internet access is provided
once, centrally, at the router.

## What's in this repo

**`scripts/`** — PowerShell scripts for AD provisioning and Group Policy
setup, written to be re-run from scratch rather than clicked through a GUI
one time.

**`network-configs/`** — Static IP/routing configuration for the Linux
hosts (netplan for Ubuntu, NetworkManager/nmcli for Kali).

**`docs/`** — Incident-style writeups of real bugs hit and diagnosed during
the build, in symptom → isolation → root cause → fix → lesson format. These
are the most representative part of this repo — anyone can follow a
tutorial where nothing breaks; these are the parts that didn't work the
first time and how I figured out why.

## Highlighted writeups

- [DNS Forwarder Bug](docs/dns-forwarder-bug.md) — lab-wide external DNS
  resolution failure traced to defunct default forwarder addresses on the
  Domain Controller
- [GPO Scoping Bug](docs/gpo-scoping-bug.md) — a Group Policy silently not
  applying due to a mismatch between computer-OU and user-OU placement
- [Network Segmentation Bug](docs/network-segmentation-bug.md) — VMs
  unable to communicate due to a NAT vs. Internal Network mismatch in
  VirtualBox

## Status

Actively in progress — this is the first month of a three-month roadmap
covering AD/IAM fundamentals, detection engineering, DevSecOps, and cloud
security. Later additions will include a SIEM (Wazuh) with custom
detections, an IAM/SSO deployment (Keycloak), a CI pipeline with security
scanning, and AWS cloud security exercises (CloudGoat).
