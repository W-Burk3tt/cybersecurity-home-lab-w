# Detection Engineering: Custom Rule for Windows Discovery Commands (T1087/T1018)

## Objective
Deploy a working Wazuh SIEM, connect live agents to a domain-joined DC and
client, then write and load a custom detection rule for a real MITRE
ATT&CK technique — account/network discovery via `net.exe` — and trace
the full pipeline from raw command execution to a fired alert.

## Infrastructure: confirmed working
- Wazuh 4.14.3 deployed via Docker Compose (indexer, manager, dashboard)
  on the existing Ubuntu host
- Two agents live and reporting: `Win-DC` (10.0.0.10) and `Win11-Client`
  (10.0.0.20), both confirmed `Active` from the manager's own
  `agent_control -l` output — the authoritative source, not just the
  dashboard UI
- Dashboard reachable and functional at `https://<ubuntu-ip>`

## The investigation chain
Ran `net user`, `systeminfo`, and similar discovery commands on the
client, expecting them to appear in the dashboard's Discover view. They
didn't. Rather than guess, worked through the pipeline in order:

1. **Confirmed Windows itself was logging the activity.** Windows does
   not audit process creation by default. Enabled it directly:
   ```powershell
   auditpol /set /subcategory:"Process Creation" /success:enable
   reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f
   ```
   Verified via `Get-WinEvent -LogName Security` — Event ID 4688 entries
   confirmed, full command lines captured correctly. **Windows-side
   logging: working.**

2. **Confirmed the agent was configured to forward the Security log.**
   Checked `ossec.conf` directly — a `<localfile>` block for
   `Security` with `eventchannel` format was already present by default,
   alongside Application and System. **Agent config: correct.**

3. **Confirmed network connectivity to the manager.**
   ```powershell
   Test-NetConnection -ComputerName <manager-ip> -Port 1514
   ```
   `TcpTestSucceeded: True`. **Connectivity: confirmed open.**

4. **Wrote a custom rule** targeting `net.exe` execution, mapped to
   MITRE T1087 (Account Discovery) and T1018 (Remote System Discovery).
   Loaded it into the manager's `local_rules.xml` and restarted the
   service. Two initial attempts (via heredoc, then `printf`) produced
   silently corrupted XML that crashed the manager on load — traced to
   quote/escape handling issues in the terminal during paste, not a
   logic error in the rule itself. Rebuilt cleanly via `nano` through an
   SSH session (bypassing both the shell-escaping issue and a separate,
   unrelated clipboard limitation specific to Ubuntu Server's headless
   console). Manager restarted cleanly with no rule-loading errors.

5. **Isolated rule logic from pipeline delivery using `wazuh-logtest`** —
   a manager-side tool that tests a rule against a sample log directly,
   independent of the full agent→manager→indexer→dashboard chain:
   ```bash
   docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
   ```
   A synthetic test log returned **"No decoder matched"** — meaning the
   sample format didn't match any of Wazuh's built-in Windows decoders,
   so it never reached rule evaluation at all.

6. **Checked whether raw events were being archived** to pull a genuine
   sample instead of guessing at the format:
   ```bash
   docker compose exec wazuh.manager ls -la /var/ossec/logs/archives/2026/Sep/
   ```
   Archive files existed but were consistently ~20 bytes — consistent
   with `logall`/`logall_json` (full raw-event archiving) being
   **disabled by default**, which is Wazuh's standard out-of-the-box
   behavior to conserve disk space. Only events that already match a
   rule get written anywhere queryable; there was no "raw events" index
   to fall back on and inspect.

## Current state (open finding, not a blocker)
The rule (`id 100010`) is syntactically valid and loaded cleanly into
the manager. It has not yet been confirmed to fire against real agent
traffic. The most likely remaining gap: the rule's `<match>` condition
targets raw text (`net.exe`), while Wazuh's real Windows eventchannel
decoder likely exposes the process name in a structured field (e.g.
`win.eventdata.image` or similar) — meaning the rule needs to target
that decoded field specifically, not a generic string match, to
reliably catch it regardless of surrounding log formatting.

## Next steps (planned)
1. Enable `logall_json` in `ossec.conf` temporarily to capture one
   genuine raw event
2. Pull a real `net.exe`-triggering event from the archive
3. Feed it into `wazuh-logtest` to see exactly which decoder matches it
   and what field the process name lands in
4. Update the rule to match against that specific field
5. Re-test and confirm a fired alert end-to-end in the dashboard

## Lesson
A SIEM producing "no results" for an expected event has several
independent possible causes stacked on top of each other — source
logging disabled, agent forwarding misconfigured, network blocked, rule
syntax broken, rule logic not matching the actual decoded structure,
raw data never archived in the first place. Each of these needed to be
checked and ruled out **in isolation** before the next was meaningful to
investigate; skipping straight to "the rule must be wrong" would have
wasted time correcting something that was already fine. `wazuh-logtest`
in particular is the right tool for cutting a multi-layer pipeline
problem in half instantly: it answers "is my rule correct" completely
independently of whether agents, connectivity, or ingestion are working
at all. This is the actual day-to-day work of detection engineering —
writing a rule is the easy part; proving it actually catches what it's
meant to, and diagnosing why it doesn't yet, is the job.
