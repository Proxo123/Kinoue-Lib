# Security boundaries

Kinoue is a public client library. Published source and release assets can be read and copied. Keep license keys, admin passwords, service secrets, database URLs, session caches, deployment configuration, and protected game payloads outside Git.

The public library contains only generic API paths. Operators supply the service address at runtime from private configuration. That keeps deployment details out of GitHub; a client that sends requests can still observe their destination. Do not treat an address, obfuscation, or a loadstring as an access-control mechanism.

The backend enforces password authentication, CSRF/origin checks, device-bound sessions, expiry, revocation and rate limits. Remembered executor sessions contain a token and the service address and must remain private. The protected payload gets the already authenticated library instance, without an authentication token, key, HWID or endpoint in its context.

## Publication checks

- `python tools/security_check.py` rejects tracked private files and hardcoded deployment addresses. It reads the Git index, so stage changes before running it.
- Gitleaks 8.30.1 scans full reachable Git history. Only two exact non-secret placeholder values are allowlisted; tests and examples are not excluded from scanning.
- CI runs the checks for every push and pull request. Public reports redact values. Local caches, credentials, environments and databases are ignored and excluded from Vercel uploads.

## Releases

Use a `vMAJOR.MINOR.PATCH` tag pointing at a reviewed commit. The release workflow checks history, compiles and tests the library, verifies reproducible bundles, and publishes the library asset and its checksum. It does not overwrite an existing release asset. The automatic loader follows the newest published release and does not fall back after a failure. A compromised maintainer account or hostile executor is outside the protection that a client-side loader can provide.

Report a suspected credential leak privately through GitHub's private vulnerability reporting when available. Do not paste credentials into public issues. Revoke a leaked credential; deleting a file from the latest commit does not remove its old Git copies.
