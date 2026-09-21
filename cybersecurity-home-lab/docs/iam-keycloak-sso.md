# IAM: Deploying Keycloak and Demonstrating a Real OIDC Login Flow

## Objective
Deploy an open-source Identity and Access Management platform (Keycloak
— the same underlying protocols as Okta, Auth0, and enterprise SSO
providers) and demonstrate a complete, real authentication flow: a
realm, a user, a client application, and a working login that issues an
actual signed token — not just a description of how SSO works, but a
token that was genuinely issued by an identity provider I stood up.

## Why this, and why now
Earlier analysis of the local cybersecurity job market identified IAM as
the most consistently understaffed specialty — not because demand is
low, but because there's no formal degree path for it, and expertise
tends to lock to whichever platform a person happens to have used. This
was built specifically to close that gap with hands-on OIDC/SSO
experience, deliberately chosen to be resource-light: a single Docker
container on infrastructure that already existed, rather than a new VM.

## Deployment
```bash
docker run -d --name keycloak --restart unless-stopped \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:26.0 start-dev
```
Run on the existing Ubuntu host, alongside the already-running Wazuh
stack — no additional VM, no additional guest OS overhead.

**One operational lesson from this step, consistent with earlier
findings in this lab:** the container was initially started without
`--restart unless-stopped`. After a VM RAM adjustment required a reboot,
Keycloak did not come back automatically — the three Wazuh containers
did, because their Compose file already had a restart policy configured,
but this one-off `docker run` container had none. Recreated with the
policy explicitly set, as shown above.

## What was built
- **A dedicated realm** (`lab-realm`) — kept entirely separate from
  Keycloak's own `master` administrative realm, which should never host
  application users or clients directly
- **A test user** (`tuser`) with a real, non-temporary password
- **A client application registration** (`demo-app`) — represents an
  application that would delegate authentication to this identity
  provider, configured as a public client with a redirect URI

## Demonstrating the actual login flow
Rather than build a full custom application just to prove the concept,
used Keycloak's built-in Account Console — every realm ships with one,
and reaching it requires a genuine, complete OIDC authentication
handshake, not just admin access:
```
http://<host>:8080/realms/lab-realm/account
```
This redirected to the realm's own branded login page (distinct from the
admin console), prompted for `tuser`'s credentials, required completing
a first-login profile (email, name — a default realm policy, and a
realistic touch many real enterprise IdPs also enforce), and on success
landed on an authenticated account management page.

## Inspecting the issued token
Captured the actual access token from the browser's Network tab
(request to `/protocol/openid-connect/token`) and decoded it at jwt.io.
The decoded payload contained:
- `iss` — the issuing realm's URL, confirming which IdP issued the token
- `sub` — an internal UUID identifying the authenticated user
- `preferred_username` — `tuser`
- `iat` / `exp` — issued-at and expiry timestamps
- `aud` — the intended audience/client for the token

**Note on the signature panel:** jwt.io could not verify the signature
without the realm's public signing certificate being supplied
separately — this is expected, not an error. A JWT's payload is
base64-encoded for transport, not encrypted, so it's readable by design;
the signature exists to prove authenticity and detect tampering, not to
hide the contents. Verifying it would require fetching the realm's
public keys from `/realms/lab-realm/protocol/openid-connect/certs`,
which is a reasonable follow-up but not required to demonstrate
understanding of the token's structure.

## What this demonstrates
- Realm-based multi-tenancy (keeping application identities separate
  from administrative access)
- Client registration and redirect URI-based trust
- A complete, real OIDC authorization flow, not a diagram of one
- Working knowledge of JWT structure: the distinction between encoding
  (readable, not secret) and signing (authenticity, not secrecy) — a
  distinction that comes up constantly in real IAM and appsec work, and
  is a common point of confusion for people newer to the space

## Lesson
The deployment itself took minutes; the actual value was in the login
flow and the token inspection — understanding *what* SSO produces and
*why* its pieces are structured the way they are, not just that a login
page appeared. The restart-policy gap was also a useful, low-stakes
reminder that ad hoc `docker run` containers behave differently from
services defined in a Compose file with respect to surviving a host
reboot — worth checking explicitly rather than assuming.
