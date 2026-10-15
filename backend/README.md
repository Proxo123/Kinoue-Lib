# Kinoue key service

This service redeems per-application keys, binds the first successful redemption to a device fingerprint, revalidates remembered sessions, and serves the protected Luau payload only after authorization. The Kinoue library and the small loader stay public; script payloads stay in the private database. The `/admin/` site manages scripts, keys, and device bindings.

## Vercel

Deploy the repository with **Root Directory = `backend`**. Vercel detects `app.py` as the FastAPI entrypoint. See [FastAPI on Vercel](https://vercel.com/docs/frameworks/backend/fastapi).

1. Connect a persistent Postgres database through the [Vercel Marketplace](https://vercel.com/docs/postgres), such as Neon. Use its pooled TLS connection URL as `DATABASE_URL`. `POSTGRES_URL` is also supported.
2. Generate `KINOUE_SECRET_KEY` with `python -m key_service generate-secret`. Save this 64-character hexadecimal value as a sensitive Vercel environment variable. Keep it stable and back it up: changing it invalidates key/session hashes and makes stored HWIDs unreadable.
3. Generate `KINOUE_ADMIN_PASSWORD_HASH` with `python -m key_service admin-password`. Enter a password of at least 12 characters. Store the printed scrypt hash as a sensitive environment variable. Do not put the raw admin password in source code or a frontend variable.
4. Set `KINOUE_ADMIN_ORIGIN` to the exact production origin, such as `https://king-keys.vercel.app`. It must match the address used to sign in, including any custom domain. Do not include a path or trailing slash.
5. Deploy, open `/admin/`, and sign in. Open **Scripts**, name the script, choose an application ID such as `king`, and upload the private `.luau` payload. Then use **New key**.
6. Point the Kinoue loader's `Endpoint` at the production HTTPS origin. Remove `AllowLocalhost` from the public loader.

Schema creation and additive migrations run automatically with a Postgres advisory lock. Scripts, licenses, encrypted HWIDs, sessions, and throttling records live in Postgres, so instances share the same state. Vercel deployments refuse to start without database, secret, admin password hash, and HTTPS admin origin configuration. No local SQLite or temporary filesystem fallback is used on Vercel.

Use a separate database and secrets for previews, or disable preview deployment. The production origin is deliberately rejected from a different preview origin. Back up the database and secret together. Keep Vercel's platform access protection off the public redemption routes so executors can reach them; admin access is protected by this application's password/session checks.

## Admin panel

- Create labeled keys for any registered script, with 1–3650 days of validity.
- Search and filter keys by script, status, label, key hint, or license ID; results are paginated.
- View the bound HWID, replace it with another HWID, or reset the lock so the next redemption establishes a new binding.
- Revoke, restore, renew, or permanently delete a key. Reset/replacement/revocation/renewal invalidate its existing remembered sessions.
- Upload or replace a script's private payload. Existing keys continue to work against the replacement.

New key values appear once. Only an HMAC and a short hint are stored; the full key cannot be retrieved later. HWIDs are authenticated-encrypted with AES-GCM for viewing by the signed-in administrator, with a separate HMAC for binding checks. Existing local installations with hash-only bindings show the fingerprint until a successful redemption/session refresh supplies the HWID again. Audit records contain operation names and license IDs, never raw keys or HWIDs.

The admin password uses scrypt. Admin sessions expire after eight hours and use HttpOnly, SameSite=Strict cookies, with Secure enabled for HTTPS/Vercel. Mutations require the configured Origin and a session-bound CSRF token. Changing the password hash invalidates existing admin sessions. Login attempts are separately throttled. There are no public administration or issuance routes outside the authenticated `/admin/api/` namespace.

## Local setup

Use Python 3.12 or later. Run these commands from `backend`:

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
.venv/Scripts/python.exe -m key_service init
.venv/Scripts/python.exe -m key_service register king C:/path/to/King.luau --name King
.venv/Scripts/python.exe -m key_service issue king --days 30
.venv/Scripts/python.exe -m uvicorn key_service.api:create_app --factory --host 127.0.0.1 --port 8765 --no-access-log
```

The issue command prints a key, its license ID, and its expiry timestamp. Keep that output private and give the key to its intended user. Keys expire from issuance. Registering an application again replaces its payload without changing existing licenses. Register another application ID to serve another developer's script from the same operator-managed service.

For local admin access, save the output of `python -m key_service admin-password` to `var/admin-password.hash`, then restart the server and open `http://127.0.0.1:8765/admin/`. It also accepts `KINOUE_ADMIN_PASSWORD_HASH`. Set `KINOUE_ADMIN_ORIGIN` when using a hostname other than localhost/127.0.0.1.

`var/secret.key` and the SQLite database must stay private and persist across restarts. The secret is generated once; replacing it invalidates existing key hashes and sessions. Back up the entire directory together. Use `--data PATH` before a CLI command and set `KINOUE_DATA_DIR` for the server to select another directory. These paths are ignored by Git. Existing `var/payloads` files are imported into the local database automatically. New uploads are stored in the database.

## Kinoue client

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/Kinoue-Lib/main/dist/Kinoue.lua"))()

return UI:CreateKeySystem({
    Name = "King",
    Application = "king",
    Endpoint = "https://your-key-service.example",
    CachePath = "King/auth.json",
    Remember = true,
})
```

For a local-only demonstration, use `Endpoint = "http://127.0.0.1:8765"` and explicitly set `AllowLocalhost = true`. This option does not permit HTTP to public hosts. Public deployments need HTTPS, usually terminated by a reverse proxy or hosting platform. See [FastAPI HTTPS deployment](https://fastapi.tiangolo.com/deployment/https/).

The executor must provide a working `gethwid`, `get_hwid`, or `syn.get_hwid`, an HTTP request function (`request`, `http_request`, or `syn.request`), and `loadstring`. Without HWID support, the UI reports **Unsupported executor: HWID unavailable**, disables redemption, and never downloads or runs the script. It does not substitute a Roblox user ID or installation ID. File functions enable Remember; executors without them can redeem for the current session.

Only the device-bound session token and its expiry, application, and endpoint are cached. Raw keys and HWIDs are not written to the client cache. The server revalidates and rotates a cached session before downloading a script. An invalid/revoked/expired login never falls back to running a previously downloaded payload. A network failure preserves the cache so it can be tried again later.

`CreateKeySystem` returns a controller with `Window`, `State`, `Error`, `Supported`, `Loaded`, `Result`, `Remembered`, and the methods `Redeem(key)`, `Forget()`, and `Destroy()`. Optional `OnLoaded(result)` and `OnError(code, message)` callbacks report outcomes. Protected scripts should return after setting up their own event handlers. There is no frame-based authentication loop.

## Operations

```powershell
python -m key_service revoke LICENSE_ID
python -m key_service reset-device LICENSE_ID
```

Revocation blocks future redemption, session refreshes, and script downloads. A device reset clears the binding and invalidates all remembered sessions; the next successful key redemption establishes the new binding. Neither operation can erase code already downloaded to a user-controlled executor or stop a script that is already running. Executor HWIDs are client-provided identifiers, not hardware attestation, and can be spoofed by a modified client. This is a licensing gate, not copy protection.

The executor API exposes `/health`, `/v1/redeem`, `/v1/session`, and `/v1/script`. Each POST includes `application` and `hwid`; redeem adds `key`, and session/script add `token`. Responses are marked `no-store`. Inputs are bounded, validation errors redact submitted credentials, and device binding uses a transaction with row locking on Postgres. Keys/device binding IDs/session tokens use domain-separated HMACs; only the admin-readable HWID additionally has encrypted storage. The server limits requests per source IP. If using a proxy, configure Uvicorn to trust only that proxy and configure HTTPS, body limits, and connection timeouts there as well.

## Container

Build with `docker build -t kinoue-keys .`, mount a persistent directory at `/data`, and initialize/register/issue using `python -m key_service --data /data ...` inside the container. The image runs as UID 10001, so its data directory must be writable by that user. Publish the API behind HTTPS; do not publish `/data` as a static directory. The service needs a persistent volume for SQLite and payloads.

## Tests

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest -q
```

Tests cover simultaneous redemption and token rotation, cross-device/application rejection, revocation/reset/replacement/deletion, expiry and renewal, restart persistence, bounded sessions, invalid requests, body limits, rate limiting, authenticated payload access, admin authentication/CSRF/origin/logout, encrypted HWID details, and script uploads. Set `KINOUE_TEST_DATABASE_URL` to an isolated test Postgres database to run the same suite against SQLite and Postgres; tests create and remove their own schemas. CI runs both engines.
