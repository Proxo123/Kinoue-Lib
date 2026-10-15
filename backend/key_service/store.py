import hashlib
import hmac
import os
import re
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from pathlib import Path


class Denied(Exception):
    def __init__(self, code="invalid_credentials", status=401):
        self.code, self.status = code, status
        super().__init__(code)


class Store:
    def __init__(self, directory, now=time.time):
        self.directory = Path(directory).resolve()
        self.directory.mkdir(parents=True, exist_ok=True)
        self.payloads = self.directory / "payloads"
        self.payloads.mkdir(exist_ok=True)
        self.secret = (self.directory / "secret.key").read_bytes()
        if len(self.secret) != 32:
            raise ValueError("secret.key must contain 32 random bytes")
        self.database = self.directory / "licenses.sqlite3"
        self.now = now
        with self.connect() as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS applications (
                    id TEXT PRIMARY KEY, name TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE IF NOT EXISTS licenses (
                    id TEXT PRIMARY KEY, application TEXT NOT NULL REFERENCES applications(id),
                    key_hash TEXT NOT NULL UNIQUE, hwid_hash TEXT, expires_at INTEGER,
                    revoked INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY, license_id TEXT NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
                    expires_at INTEGER NOT NULL, created_at INTEGER NOT NULL
                );
                CREATE INDEX IF NOT EXISTS sessions_license ON sessions(license_id);
                CREATE TABLE IF NOT EXISTS limits (
                    bucket TEXT PRIMARY KEY, attempts INTEGER NOT NULL, reset_at INTEGER NOT NULL
                );
            """)

    @staticmethod
    def initialize(directory):
        directory = Path(directory)
        directory.mkdir(parents=True, exist_ok=True)
        secret = directory / "secret.key"
        try:
            fd = os.open(secret, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            return
        with os.fdopen(fd, "wb") as output:
            output.write(secrets.token_bytes(32))

    @contextmanager
    def connect(self, write=False):
        db = sqlite3.connect(self.database, timeout=10, isolation_level=None)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        try:
            if write:
                db.execute("BEGIN IMMEDIATE")
            yield db
            if write:
                db.commit()
        except BaseException:
            if write:
                db.rollback()
            raise
        finally:
            db.close()

    def digest(self, kind, value):
        return hmac.new(self.secret, (kind + "\0" + value).encode(), hashlib.sha256).hexdigest()

    @staticmethod
    def application_id(value):
        if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", value):
            raise ValueError("Application IDs use lowercase letters, numbers, hyphens, and underscores")
        return value

    def register(self, application, name, source):
        self.application_id(application)
        data = Path(source).read_bytes()
        data.decode("utf-8")
        if not data or len(data) > 2 * 1024 * 1024:
            raise ValueError("Scripts must contain between 1 byte and 2 MiB of UTF-8 Luau")
        target = self.payloads / (application + ".luau")
        temporary = self.payloads / (application + "." + secrets.token_hex(8) + ".tmp")
        try:
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as output:
                output.write(data)
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
        with self.connect(write=True) as db:
            db.execute("INSERT INTO applications(id,name) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name",
                       (application, name))

    def issue(self, application, days=30):
        self.application_id(application)
        if not 1 <= days <= 3650:
            raise ValueError("Key duration must be between 1 and 3650 days")
        key, identifier = application.upper() + "-" + secrets.token_urlsafe(24), uuid.uuid4().hex
        now = int(self.now())
        with self.connect(write=True) as db:
            if not db.execute("SELECT id FROM applications WHERE id=?", (application,)).fetchone():
                raise ValueError("Register this application first")
            db.execute("INSERT INTO licenses(id,application,key_hash,expires_at,created_at) VALUES(?,?,?,?,?)",
                       (identifier, application, self.digest("key", key), now + days * 86400, now))
        return {"id": identifier, "key": key, "expires_at": now + days * 86400}

    def revoke(self, identifier):
        with self.connect(write=True) as db:
            found = db.execute("UPDATE licenses SET revoked=1 WHERE id=?", (identifier,)).rowcount
            db.execute("DELETE FROM sessions WHERE license_id=?", (identifier,))
        return found == 1

    def reset_device(self, identifier):
        with self.connect(write=True) as db:
            found = db.execute("UPDATE licenses SET hwid_hash=NULL WHERE id=?", (identifier,)).rowcount
            db.execute("DELETE FROM sessions WHERE license_id=?", (identifier,))
        return found == 1

    def check_license(self, row, now):
        if not row:
            raise Denied()
        if row["revoked"] or not row["enabled"]:
            raise Denied("license_revoked", 403)
        if row["expires_at"] is not None and row["expires_at"] <= now:
            raise Denied("license_expired", 403)

    def new_session(self, db, row, now):
        token = secrets.token_urlsafe(32)
        expires = min(now + 30 * 86400, row["expires_at"] or now + 30 * 86400)
        db.execute("DELETE FROM sessions WHERE expires_at<=?", (now,))
        db.execute("DELETE FROM sessions WHERE token_hash IN (SELECT token_hash FROM sessions WHERE license_id=? ORDER BY created_at DESC LIMIT -1 OFFSET 4)",
                   (row["id"],))
        db.execute("INSERT INTO sessions(token_hash,license_id,expires_at,created_at) VALUES(?,?,?,?)",
                   (self.digest("session", token), row["id"], expires, now))
        return {"token": token, "expires_at": expires, "license_expires_at": row["expires_at"]}

    def redeem(self, application, key, hwid):
        now = int(self.now())
        with self.connect(write=True) as db:
            row = db.execute("SELECT l.*,a.enabled FROM licenses l JOIN applications a ON a.id=l.application WHERE l.application=? AND l.key_hash=?",
                             (application, self.digest("key", key.strip()))).fetchone()
            self.check_license(row, now)
            fingerprint = self.digest("hwid:" + application, hwid)
            if row["hwid_hash"] and not hmac.compare_digest(row["hwid_hash"], fingerprint):
                raise Denied("hwid_mismatch", 403)
            if not row["hwid_hash"]:
                db.execute("UPDATE licenses SET hwid_hash=? WHERE id=? AND hwid_hash IS NULL", (fingerprint, row["id"]))
            return self.new_session(db, row, now)

    def session(self, application, token, hwid, rotate=False):
        now = int(self.now())
        with self.connect(write=True) as db:
            hashed = self.digest("session", token)
            row = db.execute("SELECT l.*,a.enabled,s.expires_at AS session_expires FROM sessions s JOIN licenses l ON l.id=s.license_id JOIN applications a ON a.id=l.application WHERE s.token_hash=? AND l.application=?",
                             (hashed, application)).fetchone()
            self.check_license(row, now)
            if row["session_expires"] <= now:
                raise Denied("session_expired")
            if not row["hwid_hash"] or not hmac.compare_digest(row["hwid_hash"], self.digest("hwid:" + application, hwid)):
                raise Denied("hwid_mismatch", 403)
            if rotate:
                db.execute("DELETE FROM sessions WHERE token_hash=?", (hashed,))
                return self.new_session(db, row, now)
        return {"expires_at": row["session_expires"]}

    def script(self, application, token, hwid):
        self.application_id(application)
        self.session(application, token, hwid)
        target = (self.payloads / (application + ".luau")).resolve()
        if not target.is_relative_to(self.payloads.resolve()):
            raise Denied("script_unavailable", 503)
        try:
            data = target.read_bytes()
        except OSError:
            raise Denied("script_unavailable", 503) from None
        if not data or len(data) > 2 * 1024 * 1024:
            raise Denied("script_unavailable", 503)
        return data.decode("utf-8")

    def rate_limit(self, ip):
        now = int(self.now())
        bucket = self.digest("rate", ip)
        with self.connect(write=True) as db:
            db.execute("DELETE FROM limits WHERE reset_at<=?", (now,))
            row = db.execute("SELECT attempts FROM limits WHERE bucket=?", (bucket,)).fetchone()
            if row and row["attempts"] >= 60:
                raise Denied("rate_limited", 429)
            db.execute("INSERT INTO limits(bucket,attempts,reset_at) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET attempts=attempts+1",
                       (bucket, now + 60))
