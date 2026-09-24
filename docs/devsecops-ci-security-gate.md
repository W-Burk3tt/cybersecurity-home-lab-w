DevSecOps: A Working CI Security Gate with Bandit SAST
Live repo: DevSecOps-security-gate — Actions tab shows both runs described below.
Objective
Build a minimal but genuine CI/CD security gate — a pipeline that
automatically runs static code analysis on every push and blocks
the build when it finds a real vulnerability, rather than just
reporting one. The goal was a complete, provable before/after story:
vulnerable code correctly failing, then a real fix correctly passing.
Why this, and why now
Of the specialties identified early on as scarce and hireable
(cloud security, application security/DevSecOps, IAM, detection
engineering), DevSecOps was the one with zero prior evidence in this
lab — everything else had some foundation already. It was also
deliberately chosen to be light on local infrastructure: GitHub Actions
runs entirely on GitHub's own cloud runners, so this required no new
VM and no additional load on an already resource-constrained host.
What was built
`app.py` — a small Python file with two deliberately introduced,
well-known vulnerability patterns: SQL injection via string
concatenation (CWE-89) and OS command injection via
`subprocess.run(..., shell=True)` (CWE-78)
`.github/workflows/security-scan.yml` — a GitHub Actions workflow
that runs Bandit (a Python-specific
SAST tool) on every push and pull request to `main`, with no bypass:
no `continue-on-error`, no suppressed exit code. A real finding at
medium severity or higher genuinely fails the job.
The test: fail, then fix
Run #1 — pushed the vulnerable code as-is. Result: Failure,
exit code 1. Bandit's output identified both real issues with exact
file/line references:
```
>> Issue: [B608:hardcoded_sql_expressions] Possible SQL injection vector
   Severity: Medium   Confidence: Low   CWE-89
   Location: ./devsecops-demo/app.py:30

>> Issue: [B602:subprocess_popen_with_shell_equals_true]
   subprocess call with shell=True identified, security issue.
   Severity: High   Confidence: High   CWE-78
   Location: ./devsecops-demo/app.py:41
```
Fix applied:
```python
# Before (SQL injection)
query = "SELECT * FROM users WHERE username = '" + username + "'"
cursor.execute(query)

# After — parameterized query
cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
```
```python
# Before (command injection)
result = subprocess.run(f"ping -c 1 {hostname}", shell=True, capture_output=True)

# After — list-form arguments, no shell
result = subprocess.run(["ping", "-c", "1", hostname], capture_output=True)
```
Run #2 — pushed the fix. Result: Success, green checkmark, no
findings above threshold.
Both runs are permanently visible in the repository's Actions tab —
not a screenshot claiming this happened, but a live, re-verifiable
record that it did.
![Bandit SAST scan output showing the two real findings from the failing run](../Images/bandit-scan-failure.png)
![GitHub Actions run history showing the failed run followed by the passing run after the fix](../Images/actions-fail-then-pass.png)
What this demonstrates
A real, working security gate: vulnerable code cannot merge silently
Recognition and correct remediation of two of the most common
real-world vulnerability classes (injection flaws — consistently
among the top entries in OWASP's Top 10)
Understanding that a security gate's value is in what it blocks,
not just what it reports — the workflow was deliberately written
with no way to ignore a failing scan
Note on scope
A third planted vulnerability (a hardcoded secret) was included in the
original code but did not appear in Bandit's output — it was almost
certainly caught but filtered below the workflow's
`--severity-level medium` threshold. Worth revisiting as a follow-up:
lowering the threshold, or adding a dedicated secrets-scanning step
(e.g., Gitleaks or TruffleHog), since hardcoded credentials are a
distinct and common finding that a general SAST severity filter can
miss.
Lesson
The infrastructure lesson here was as valuable as the security one: a
GitHub web-based drag-and-drop upload placed the project files one
folder level deeper than intended (nested under `devsecops-demo/`
instead of at the repo root), which meant GitHub Actions initially
never detected any workflow at all — not because anything was
misconfigured, but because `.github/workflows/` has to exist at the
exact repository root to be recognized. Creating that one file directly
through GitHub's web editor, at the correct path, resolved it
immediately, and Bandit's own recursive scan (`-r .`) still correctly
found the nested `app.py` regardless. A reminder that a pipeline can be
written perfectly and still never run at all if the file structure
around it isn't exactly what the platform expects.
