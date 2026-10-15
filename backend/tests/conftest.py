import os
import secrets
import uuid

import pytest
from fastapi.testclient import TestClient

from key_service.api import create_app
from key_service.postgres import PostgresStore
from key_service.store import Store


@pytest.fixture(params=["sqlite", "postgres"] if os.environ.get("KINOUE_TEST_DATABASE_URL") else ["sqlite"])
def setup(request, tmp_path):
    clock = [2000000000]
    schema = None
    if request.param == "postgres":
        import psycopg
        from psycopg.conninfo import make_conninfo
        schema = "test_" + uuid.uuid4().hex
        url = os.environ["KINOUE_TEST_DATABASE_URL"]
        with psycopg.connect(url, autocommit=True) as db:
            db.execute('CREATE SCHEMA "' + schema + '"')
        scoped = make_conninfo(url, options="-c search_path=" + schema)
        store = PostgresStore(scoped, secrets.token_hex(32), now=lambda: clock[0])
    else:
        Store.initialize(tmp_path)
        store = Store(tmp_path, now=lambda: clock[0])
    source = tmp_path / "example.luau"
    source.write_text('return "protected-script"', encoding="utf-8")
    store.register("king", "King", source)
    store.register("second", "Second", source)
    license = store.issue("king", 30)
    yield store, license, clock, TestClient(create_app(store, admin_hash=""))
    if schema:
        with psycopg.connect(url, autocommit=True) as db:
            db.execute('DROP SCHEMA "' + schema + '" CASCADE')
