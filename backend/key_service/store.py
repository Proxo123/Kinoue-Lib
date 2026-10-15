import hashlib
import hmac
import os
import re
import secrets
import sqlite3
import time
import uuid
import base64
from contextlib import contextmanager
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


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
            columns = {row["name"] for row in db.execute("PRAGMA table_info(licenses)").fetchall()}
            for name, definition in LICENSE_COLUMNS.items():
                if name not in columns:
                    db.execute("ALTER TABLE licenses ADD COLUMN " + name + " " + definition)
            if "source" not in {row["name"] for row in db.execute("PRAGMA table_info(applications)").fetchall()}:
                db.execute("ALTER TABLE applications ADD COLUMN source TEXT")
            for statement in ADMIN_SCHEMA:
                db.execute(statement)
            for row in db.execute("SELECT id FROM applications WHERE source IS NULL").fetchall():
                path = self.payloads / (row["id"] + ".luau")
                if path.is_file():
                    db.execute("UPDATE applications SET source=? WHERE id=?", (path.read_text(encoding="utf-8"), row["id"]))

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

    def locked(self, query):
        return query

    def encrypt_hwid(self, application, value):
        nonce = secrets.token_bytes(12)
        key = hmac.new(self.secret, b"hwid-encryption-v1", hashlib.sha256).digest()
        return base64.urlsafe_b64encode(nonce + AESGCM(key).encrypt(nonce, value.encode(), application.encode())).decode()

    def decrypt_hwid(self, application, value):
        if not value:
            return None
        data = base64.urlsafe_b64decode(value)
        key = hmac.new(self.secret, b"hwid-encryption-v1", hashlib.sha256).digest()
        return AESGCM(key).decrypt(data[:12], data[12:], application.encode()).decode()

    @staticmethod
    def application_id(value):
        if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", value):
            raise ValueError("Application IDs use lowercase letters, numbers, hyphens, and underscores")
        return value

    def register(self, application, name, source):
        self.register_source(application, name, Path(source).read_text(encoding="utf-8"))

    def register_source(self, application, name, source):
        self.application_id(application)
        if not isinstance(source, str) or not source or len(source.encode()) > 2 * 1024 * 1024:
            raise ValueError("Scripts must contain between 1 byte and 2 MiB of UTF-8 Luau")
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80:
            raise ValueError("Script names must contain 1 to 80 characters")
        with self.connect(write=True) as db:
            db.execute("INSERT INTO applications(id,name,source) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,source=excluded.source",
                       (application, name.strip(), source))
            self.audit(db, "script_saved", application)

    def issue(self, application, days=30, label=""):
        self.application_id(application)
        if type(days) is not int or not 1 <= days <= 3650:
            raise ValueError("Key duration must be between 1 and 3650 days")
        if not isinstance(label, str) or len(label) > 120:
            raise ValueError("Labels must contain at most 120 characters")
        key, identifier = application.upper() + "-" + secrets.token_urlsafe(24), uuid.uuid4().hex
        now = int(self.now())
        with self.connect(write=True) as db:
            if not db.execute("SELECT id FROM applications WHERE id=?", (application,)).fetchone():
                raise ValueError("Register this application first")
            db.execute("INSERT INTO licenses(id,application,key_hash,expires_at,created_at,key_hint,label) VALUES(?,?,?,?,?,?,?)",
                       (identifier, application, self.digest("key", key), now + days * 86400, now, application.upper() + "-…" + key[-4:], label.strip()))
            self.audit(db, "key_created", identifier)
        return {"id": identifier, "key": key, "expires_at": now + days * 86400}

    def revoke(self, identifier):
        with self.connect(write=True) as db:
            found = db.execute("UPDATE licenses SET revoked=1 WHERE id=?", (identifier,)).rowcount
            db.execute("DELETE FROM sessions WHERE license_id=?", (identifier,))
            if found:
                self.audit(db, "key_revoked", identifier)
        return found == 1

    def reset_device(self, identifier):
        with self.connect(write=True) as db:
            found = db.execute("UPDATE licenses SET hwid_hash=NULL,hwid_ciphertext=NULL WHERE id=?", (identifier,)).rowcount
            db.execute("DELETE FROM sessions WHERE license_id=?", (identifier,))
            if found:
                self.audit(db, "hwid_reset", identifier)
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
        old = db.execute("SELECT token_hash FROM sessions WHERE license_id=? ORDER BY created_at DESC,token_hash", (row["id"],)).fetchall()
        for session in old[4:]:
            db.execute("DELETE FROM sessions WHERE token_hash=?", (session["token_hash"],))
        db.execute("INSERT INTO sessions(token_hash,license_id,expires_at,created_at) VALUES(?,?,?,?)",
                   (self.digest("session", token), row["id"], expires, now))
        return {"token": token, "expires_at": expires, "license_expires_at": row["expires_at"], "server_time": now}

    def redeem(self, application, key, hwid):
        now = int(self.now())
        with self.connect(write=True) as db:
            row = db.execute(self.locked("SELECT l.*,a.enabled FROM licenses l JOIN applications a ON a.id=l.application WHERE l.application=? AND l.key_hash=?"),
                             (application, self.digest("key", key.strip()))).fetchone()
            self.check_license(row, now)
            fingerprint = self.digest("hwid:" + application, hwid)
            if row["hwid_hash"] and not hmac.compare_digest(row["hwid_hash"], fingerprint):
                raise Denied("hwid_mismatch", 403)
            db.execute("UPDATE licenses SET hwid_hash=?,hwid_ciphertext=?,last_seen=? WHERE id=?", (fingerprint, self.encrypt_hwid(application, hwid), now, row["id"]))
            return self.new_session(db, row, now)

    def session(self, application, token, hwid, rotate=False):
        now = int(self.now())
        with self.connect(write=True) as db:
            hashed = self.digest("session", token)
            row = db.execute(self.locked("SELECT l.*,a.enabled,s.expires_at AS session_expires FROM sessions s JOIN licenses l ON l.id=s.license_id JOIN applications a ON a.id=l.application WHERE s.token_hash=? AND l.application=?"),
                             (hashed, application)).fetchone()
            self.check_license(row, now)
            if row["session_expires"] <= now:
                raise Denied("session_expired")
            if not row["hwid_hash"] or not hmac.compare_digest(row["hwid_hash"], self.digest("hwid:" + application, hwid)):
                raise Denied("hwid_mismatch", 403)
            db.execute("UPDATE licenses SET hwid_ciphertext=?,last_seen=? WHERE id=?", (self.encrypt_hwid(application, hwid), now, row["id"]))
            if rotate:
                if db.execute("DELETE FROM sessions WHERE token_hash=?", (hashed,)).rowcount != 1:
                    raise Denied()
                return self.new_session(db, row, now)
        return {"expires_at": row["session_expires"], "license_expires_at": row["expires_at"], "server_time": now}

    def record_execution(self, application, token, hwid, execution_id, user_id, username, display_name, place_id, library_version):
        now = int(self.now())
        with self.connect(write=True) as db:
            row = db.execute(self.locked("SELECT l.*,a.enabled,s.expires_at AS session_expires FROM sessions s JOIN licenses l ON l.id=s.license_id JOIN applications a ON a.id=l.application WHERE s.token_hash=? AND l.application=?"),
                             (self.digest("session", token), application)).fetchone()
            self.check_license(row, now)
            if row["session_expires"] <= now:
                raise Denied("session_expired")
            if not row["hwid_hash"] or not hmac.compare_digest(row["hwid_hash"], self.digest("hwid:" + application, hwid)):
                raise Denied("hwid_mismatch", 403)
            identifier = self.digest("execution", token + ":" + execution_id)
            db.execute("INSERT INTO executions(id,license_id,user_id,username,display_name,place_id,library_version,executed_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING",
                       (identifier, row["id"], user_id, username, display_name, place_id, library_version, now))
        return {"ok": True}

    def executions(self, identifier, page=1):
        with self.connect() as db:
            if not db.execute("SELECT id FROM licenses WHERE id=?", (identifier,)).fetchone():
                raise Denied("not_found", 404)
            total = db.execute("SELECT COUNT(*) AS total FROM executions WHERE license_id=?", (identifier,)).fetchone()["total"]
            rows = db.execute("SELECT user_id,username,display_name,place_id,library_version,executed_at FROM executions WHERE license_id=? ORDER BY executed_at DESC,id DESC LIMIT 25 OFFSET ?",
                              (identifier, (page - 1) * 25)).fetchall()
        return {"items": [dict(row) for row in rows], "total": total, "page": page, "page_size": 25}

    def script(self, application, token, hwid):
        self.application_id(application)
        self.session(application, token, hwid)
        with self.connect() as db:
            row = db.execute("SELECT source FROM applications WHERE id=?", (application,)).fetchone()
        if not row or not row["source"]:
            raise Denied("script_unavailable", 503)
        return row["source"]

    def logout(self, application, token, hwid):
        with self.connect(write=True) as db:
            row = db.execute(self.locked("SELECT l.* FROM sessions s JOIN licenses l ON l.id=s.license_id WHERE s.token_hash=? AND l.application=?"),
                             (self.digest("session", token), application)).fetchone()
            if row and row["hwid_hash"] and hmac.compare_digest(row["hwid_hash"], self.digest("hwid:" + application, hwid)):
                db.execute("DELETE FROM sessions WHERE token_hash=?", (self.digest("session", token),))
        return {"ok": True}

    def rate_limit(self, ip, group="client", limit=60, seconds=60):
        now = int(self.now())
        bucket = self.digest("rate:" + group, ip)
        with self.connect(write=True) as db:
            db.execute("DELETE FROM limits WHERE reset_at<=?", (now,))
            row = db.execute("INSERT INTO limits(bucket,attempts,reset_at) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET attempts=limits.attempts+1 RETURNING attempts",
                             (bucket, now + seconds)).fetchone()
            if row["attempts"] > limit:
                raise Denied("rate_limited", 429)

    def audit(self, db, action, target):
        db.execute("INSERT INTO audit(id,action,target,created_at) VALUES(?,?,?,?)", (uuid.uuid4().hex, action, target, int(self.now())))

    def applications(self):
        with self.connect() as db:
            return [dict(row) for row in db.execute("SELECT id,name,enabled,LENGTH(source) AS source_size FROM applications ORDER BY name,id").fetchall()]

    def license_view(self, row):
        value = {key: row[key] for key in ("id", "application", "label", "key_hint", "expires_at", "created_at", "last_seen")}
        value["hwid_bound"] = bool(row["hwid_hash"])
        value["status"] = "revoked" if row["revoked"] else "expired" if row["expires_at"] and row["expires_at"] <= int(self.now()) else "active"
        return value

    def licenses(self, application="", search="", status="", page=1):
        clauses, values = [], []
        if application:
            self.application_id(application)
            clauses.append("application=?")
            values.append(application)
        if search:
            clauses.append("(LOWER(label) LIKE ? OR LOWER(id) LIKE ? OR LOWER(key_hint) LIKE ?)")
            values.extend(["%" + search.lower().replace("%", "").replace("_", "") + "%"] * 3)
        now = int(self.now())
        if status == "revoked":
            clauses.append("revoked=1")
        elif status == "expired":
            clauses.append("revoked=0 AND expires_at<=?")
            values.append(now)
        elif status == "active":
            clauses.append("revoked=0 AND (expires_at IS NULL OR expires_at>?)")
            values.append(now)
        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        with self.connect() as db:
            total = db.execute("SELECT COUNT(*) AS total FROM licenses" + where, tuple(values)).fetchone()["total"]
            rows = db.execute("SELECT * FROM licenses" + where + " ORDER BY created_at DESC,id DESC LIMIT 50 OFFSET ?", tuple(values + [(page - 1) * 50])).fetchall()
        return {"items": [self.license_view(row) for row in rows], "total": total, "page": page, "page_size": 50}

    def license_detail(self, identifier):
        with self.connect() as db:
            row = db.execute("SELECT * FROM licenses WHERE id=?", (identifier,)).fetchone()
            if not row:
                raise Denied("not_found", 404)
            value = self.license_view(row)
            value["hwid"] = self.decrypt_hwid(row["application"], row["hwid_ciphertext"])
            value["hwid_fingerprint"] = row["hwid_hash"]
            value["activity"] = [dict(item) for item in db.execute("SELECT action,created_at FROM audit WHERE target=? ORDER BY created_at DESC,id DESC LIMIT 20", (identifier,)).fetchall()]
        value["executions"] = self.executions(identifier)
        return value

    def change_license(self, identifier, action, value=None):
        if action == "reset-hwid":
            return self.reset_device(identifier)
        if action == "revoke":
            return self.revoke(identifier)
        with self.connect(write=True) as db:
            row = db.execute(self.locked("SELECT l.* FROM licenses l WHERE l.id=?"), (identifier,)).fetchone()
            if not row:
                return False
            if action == "set-hwid":
                if not isinstance(value, str) or not value.strip() or len(value) > 512:
                    raise ValueError("HWID must contain 1 to 512 characters")
                db.execute("UPDATE licenses SET hwid_hash=?,hwid_ciphertext=? WHERE id=?", (self.digest("hwid:" + row["application"], value), self.encrypt_hwid(row["application"], value), identifier))
            elif action == "restore":
                db.execute("UPDATE licenses SET revoked=0 WHERE id=?", (identifier,))
            elif action == "renew":
                if type(value) is not int or not 1 <= value <= 3650:
                    raise ValueError("Duration must be between 1 and 3650 days")
                db.execute("UPDATE licenses SET expires_at=? WHERE id=?", (int(self.now()) + value * 86400, identifier))
            elif action == "delete":
                db.execute("DELETE FROM licenses WHERE id=?", (identifier,))
            else:
                raise ValueError("Unknown action")
            db.execute("DELETE FROM sessions WHERE license_id=?", (identifier,))
            self.audit(db, action.replace("-", "_"), identifier)
        return True

    def admin_login(self, password_version):
        token = secrets.token_urlsafe(32)
        now = int(self.now())
        with self.connect(write=True) as db:
            db.execute("DELETE FROM admin_sessions WHERE expires_at<=? OR password_version<>?", (now, password_version))
            old = db.execute("SELECT token_hash FROM admin_sessions ORDER BY created_at DESC,token_hash").fetchall()
            for row in old[9:]:
                db.execute("DELETE FROM admin_sessions WHERE token_hash=?", (row["token_hash"],))
            db.execute("INSERT INTO admin_sessions(token_hash,expires_at,created_at,password_version) VALUES(?,?,?,?)", (self.digest("admin", token), now + 28800, now, password_version))
        return token

    def admin_session(self, token, password_version):
        if not token or len(token) > 256:
            raise Denied("admin_login_required")
        with self.connect() as db:
            row = db.execute("SELECT expires_at,password_version FROM admin_sessions WHERE token_hash=?", (self.digest("admin", token),)).fetchone()
        if not row or row["expires_at"] <= int(self.now()) or not hmac.compare_digest(row["password_version"], password_version):
            raise Denied("admin_login_required")
        return self.digest("admin-csrf", token)

    def admin_logout(self, token):
        with self.connect(write=True) as db:
            db.execute("DELETE FROM admin_sessions WHERE token_hash=?", (self.digest("admin", token),))


LICENSE_COLUMNS = {"label": "TEXT NOT NULL DEFAULT ''", "key_hint": "TEXT NOT NULL DEFAULT ''", "hwid_ciphertext": "TEXT", "last_seen": "BIGINT"}
ADMIN_SCHEMA = [
    "CREATE TABLE IF NOT EXISTS executions(id TEXT PRIMARY KEY,license_id TEXT NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,user_id BIGINT NOT NULL,username TEXT NOT NULL,display_name TEXT NOT NULL,place_id BIGINT NOT NULL,library_version TEXT NOT NULL,executed_at BIGINT NOT NULL)",
    "CREATE INDEX IF NOT EXISTS executions_license_time ON executions(license_id,executed_at)",
    "CREATE TABLE IF NOT EXISTS admin_sessions(token_hash TEXT PRIMARY KEY,expires_at BIGINT NOT NULL,created_at BIGINT NOT NULL,password_version TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS audit(id TEXT PRIMARY KEY,action TEXT NOT NULL,target TEXT NOT NULL,created_at BIGINT NOT NULL)",
    "CREATE INDEX IF NOT EXISTS audit_target ON audit(target,created_at)",
    "CREATE INDEX IF NOT EXISTS licenses_application_created ON licenses(application,created_at)",
]
