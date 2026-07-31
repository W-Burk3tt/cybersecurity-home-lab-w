# GPO Setup Script — Workstation Baseline Policy
# ---------------------------------------
# Demonstrates GPO creation, linking, and a real scoping lesson learned
# the hard way: Group Policy applies User Configuration settings based on
# the location of the USER object in AD — not the computer object.
#
# This GPO contains a User Configuration (HKCU) setting, so it must be
# linked to BOTH the Workstations OU (where the computer lives) AND the
# Corp Users OU (where the user lives) to actually apply.
# See docs/gpo-scoping-bug.md for the full diagnosis writeup.

# Create the GPO and link it to the computer's OU
New-GPO -Name "Workstation Baseline" | New-GPLink -Target "OU=Workstations,DC=lab,DC=local"

# Link the same GPO to the user's OU — required for HKCU settings to apply
New-GPLink -Name "Workstation Baseline" -Target "OU=Corp Users,DC=lab,DC=local"

# Set a password-protected screensaver policy (5 minute timeout)
Set-GPRegistryValue -Name "Workstation Baseline" -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName "ScreenSaveActive" -Type String -Value "1"
Set-GPRegistryValue -Name "Workstation Baseline" -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName "ScreenSaveTimeOut" -Type String -Value "300"
Set-GPRegistryValue -Name "Workstation Baseline" -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName "ScreenSaverIsSecure" -Type String -Value "1"

# Verify from the client, logged in as the target (non-admin) user:
#   gpupdate /force
#   gpresult /r
# Confirm "Workstation Baseline" appears under Applied Group Policy Objects
# in the User Settings section.
