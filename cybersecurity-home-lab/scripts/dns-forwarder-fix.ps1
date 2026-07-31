# DNS Forwarder Fix
# ---------------------------------------
# The DC shipped with default forwarders pointed at defunct IPv6
# site-local placeholder addresses (fec0::...), meaning it could answer
# queries for its own zone (lab.local) but could never actually forward
# and resolve external domains. See docs/dns-forwarder-bug.md for the
# full diagnosis writeup.

# Check current (broken) forwarders
Get-DnsServerForwarder

# Replace with working public resolvers
Set-DnsServerForwarder -IPAddress 8.8.8.8,1.1.1.1

# Verify
Get-DnsServerForwarder

# Test from any client on the domain:
#   nslookup google.com 10.0.0.10
