# Incident Writeup: Group Policy Not Applying to Target User

## Symptom
A GPO ("Workstation Baseline") containing a password-protected screensaver
policy was created and linked to the `Workstations` OU, which contains the
domain-joined Windows 11 client computer object. After running `gpupdate
/force` on the client while logged in as a standard domain user (`tuser`),
`gpresult /r` showed:
```
Applied Group Policy Objects
-----------------------------
    N/A
```
Not "filtered out" — genuinely not in scope at all.

## Isolation
First checked whether this was a permissions/account issue by running
`gpresult /r` while logged in as the domain Administrator instead —
returned `INFO: The user "LAB\Administrator" does not have RSoP data`,
which is expected default behavior for that account and not informative
either way.

Logged in as `tuser` specifically and re-ran `gpresult /r`. The output
confirmed:
- The user's RSoP data was being generated correctly (`Last time Group
  Policy was applied` showed a recent timestamp)
- The user's OU location: `CN=Test User,OU=Corp Users,DC=lab,DC=local`
- Applied Group Policy Objects: `N/A`

That last detail was the key: `tuser` lives in `Corp Users`, not
`Workstations`.

## Root Cause
The GPO's setting (`HKCU\...\ScreenSaveActive`, etc.) is a **User
Configuration** setting. Group Policy applies user-configuration settings
based on where the **user object** sits in Active Directory, not where the
computer object sits — unless Loopback Processing is explicitly configured
to override that behavior (not the case here).

The GPO was linked only to `Workstations` (the computer's OU). Since
`tuser` lives in a different OU (`Corp Users`) that never had this GPO
linked to it, Windows never even considered the policy for this user —
hence `N/A` rather than a "filtered" result, which would have indicated the
policy was in scope but blocked by a security/WMI filter.

## Fix
```powershell
New-GPLink -Name "Workstation Baseline" -Target "OU=Corp Users,DC=lab,DC=local"
```
Linked the same GPO to the OU where the user object actually resides, in
addition to the existing link on the computer's OU.

## Verification
```
gpupdate /force
gpresult /r
```
`Workstation Baseline` now appeared under Applied Group Policy Objects in
the User Settings section.

## Lesson
Computer-side and user-side Group Policy settings scope independently by
default. Assuming that placing a computer in the "right" OU is sufficient
to control everything that happens on it — including settings for whichever
user logs in — is a common and easy mistake. In a real environment, this is
exactly the kind of gap Loopback Processing (Replace or Merge mode) is
designed to close, e.g., for shared/kiosk machines where the computer's
location should dictate policy regardless of which user logs in.
