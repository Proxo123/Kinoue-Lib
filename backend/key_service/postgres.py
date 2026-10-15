import os
import time
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

from .store import ADMIN_SCHEMA, LICENSE_COLUMNS, Store


class Connection:
    def __init__(self, connection):
        self.connection = connection

    def execute(self, query, parameters=()):
        return self.connection.execute(query.replace("?", "%s"), parameters)


class PostgresStore(Store):
    def __init__(self, url, secret, now=time.time):
        self.url, self.secret, self.now = url, bytes.fromhex(secret), now
        if len(self.secret) != 32:
            raise ValueError("KINOUE_SECRET_KEY must contain 64 hexadecimal characters")
        with self.connect(write=True) as db:
            db.execute("SELECT pg_advisory_xact_lock(812749023)")
            for query in [
                "CREATE TABLE IF NOT EXISTS applications(id TEXT PRIMARY KEY,name TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1,source TEXT)",
                "CREATE TABLE IF NOT EXISTS licenses(id TEXT PRIMARY KEY,application TEXT NOT NULL REFERENCES applications(id),key_hash TEXT NOT NULL UNIQUE,hwid_hash TEXT,expires_at BIGINT,revoked INTEGER NOT NULL DEFAULT 0,created_at BIGINT NOT NULL)",
                "CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,license_id TEXT NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,expires_at BIGINT NOT NULL,created_at BIGINT NOT NULL)",
                "CREATE INDEX IF NOT EXISTS sessions_license ON sessions(license_id)",
                "CREATE TABLE IF NOT EXISTS limits(bucket TEXT PRIMARY KEY,attempts INTEGER NOT NULL,reset_at BIGINT NOT NULL)",
                *ADMIN_SCHEMA,
            ]:
                db.execute(query)
            for name, definition in LICENSE_COLUMNS.items():
                db.execute("ALTER TABLE licenses ADD COLUMN IF NOT EXISTS " + name + " " + definition)

    @contextmanager
    def connect(self, write=False):
        with psycopg.connect(self.url, row_factory=dict_row, connect_timeout=10) as connection:
            connection.execute("SET LOCAL statement_timeout=15000")
            yield Connection(connection)

    def locked(self, query):
        return query + " FOR UPDATE OF l"


def environment_store():
    url = os.environ.get("DATABASE_URL") or os.environ.get("POSTGRES_URL")
    if url:
        return PostgresStore(url, os.environ.get("KINOUE_SECRET_KEY", ""))
    if os.environ.get("VERCEL"):
        raise ValueError("Vercel requires DATABASE_URL and KINOUE_SECRET_KEY; local SQLite is not supported there")
    return Store(os.environ.get("KINOUE_DATA_DIR", "var"))
