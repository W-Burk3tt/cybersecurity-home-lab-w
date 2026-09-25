# Active Directory Provisioning Script
# ---------------------------------------
# Creates a baseline OU structure, moves a domain-joined computer into place,
# and provisions a standard (non-Administrator) domain user.
# Run on the Domain Controller with Domain Admin privileges.

# Create OUs — kept separate from the built-in default containers
# (avoid naming collisions with AD's built-in "Users" container)
New-ADOrganizationalUnit -Name "Workstations" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Corp Users" -Path "DC=lab,DC=local"

# Move a domain-joined computer out of the default Computers container
Get-ADComputer -Identity "WINDOWS-11-ENTE" | Move-ADObject -TargetPath "OU=Workstations,DC=lab,DC=local"

# Create a standard domain user (never use the built-in Administrator
# account for day-to-day testing — this is also what surfaced the GPO
# scoping bug documented in docs/gpo-scoping-bug.md)
New-ADUser -Name "Test User" `
  -SamAccountName "tuser" `
  -UserPrincipalName "tuser@lab.local" `
  -Path "OU=Corp Users,DC=lab,DC=local" `
  -AccountPassword (ConvertTo-SecureString "<YOUR_PASSWORD_HERE>" -AsPlainText -Force) `
  -Enabled $true `
  -ChangePasswordAtLogon $false

# Verify:
# Get-ADUser -Identity tuser -Properties DistinguishedName | Select Name, DistinguishedName, Enabled
