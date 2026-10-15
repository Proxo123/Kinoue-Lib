import concurrent.futures
import json
import sqlite3

import pytest
from fastapi.testclient import TestClient

from key_service.api import create_app
from key_service.store import Denied, Store


@pytest.fixture
def setup(tmp_path):
    Store.initialize(tmp_path)
    clock = [2000000000]
    store = Store(tmp_path, now=lambda: clock[0])
    source = tmp_path / "example.luau"
    source.write_text('return "protected-script"', encoding="utf-8")
    store.register("king", "King", source)
    store.register("second", "Second", source)
    license = store.issue("king", 30)
    return store, license, clock, TestClient(create_app(store))


def redeem(client, license, hwid="device-one", application="king"):
    return client.post("/v1/redeem", json={"application": application, "key": license["key"], "hwid": hwid})


def test_redeem_bind_and_load(setup):
    store, license, _, client = setup
    response = redeem(client, license)
    assert response.status_code == 200
    token = response.json()["token"]
    loaded = client.post("/v1/script", json={"application": "king", "hwid": "device-one", "token": token})
    assert loaded.status_code == 200 and loaded.text == 'return "protected-script"'
    assert loaded.headers["cache-control"] == "no-store"
    assert redeem(client, license, "device-two").status_code == 403
    assert redeem(client, license).status_code == 200
    with sqlite3.connect(store.database) as db:
        dump = "\n".join(db.iterdump())
    assert license["key"] not in dump and token not in dump and "device-one" not in dump


def test_binding_race_is_atomic(setup):
    store, license, _, _ = setup

    def attempt(hwid):
        try:
            store.redeem("king", license["key"], hwid)
            return "ok"
        except Denied as error:
            return error.code

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(attempt, ["first-device", "second-device"]))
    assert sorted(results) == ["hwid_mismatch", "ok"]


def test_refresh_rotates_and_app_and_device_are_checked(setup):
    _, license, _, client = setup
    token = redeem(client, license).json()["token"]
    body = {"application": "king", "hwid": "device-one", "token": token}
    assert client.post("/v1/session", json={**body, "hwid": "another-device"}).status_code == 403
    assert client.post("/v1/session", json={**body, "application": "second"}).status_code == 401
    response = client.post("/v1/session", json=body)
    assert response.status_code == 200 and response.json()["token"] != token
    assert client.post("/v1/script", json=body).status_code == 401
    body["token"] = response.json()["token"]
    assert client.post("/v1/script", json=body).status_code == 200


def test_revoke_and_reset_remove_sessions(setup):
    store, license, _, client = setup
    token = redeem(client, license).json()["token"]
    assert store.reset_device(license["id"])
    assert client.post("/v1/script", json={"application": "king", "hwid": "device-one", "token": token}).status_code == 401
    assert redeem(client, license, "new-device").status_code == 200
    assert store.revoke(license["id"])
    assert redeem(client, license, "new-device").json()["error"] == "license_revoked"


def test_expiry_and_disabled_application(setup):
    store, license, clock, client = setup
    session = redeem(client, license).json()
    assert session["expires_at"] <= license["expires_at"]
    clock[0] = license["expires_at"]
    assert redeem(client, license).json()["error"] == "license_expired"
    clock[0] -= 100
    with store.connect(write=True) as db:
        db.execute("UPDATE applications SET enabled=0 WHERE id='king'")
    assert redeem(client, license).json()["error"] == "license_revoked"


def test_public_api_has_no_admin_or_payload_bypass(setup):
    _, license, _, client = setup
    assert client.get("/health").json() == {"ok": True}
    assert client.get("/docs").status_code == 404
    assert client.get("/payloads/king.luau").status_code == 404
    assert client.post("/v1/script", json={"application": "king", "hwid": "device-one", "token": "a" * 43}).status_code == 401
    assert redeem(client, license, application="second").status_code == 401
    assert client.post("/v1/issue", json={}).status_code == 404


def test_invalid_inputs_are_redacted_and_bounded(setup):
    _, _, _, client = setup
    secret = "DO-NOT-RETURN-THIS-KEY"
    bad = client.post("/v1/redeem", json={"key": secret, "hwid": "private-device", "application": "../king"})
    assert bad.status_code == 400 and secret not in bad.text and "private-device" not in bad.text
    assert client.post("/v1/redeem", content=b"x" * 9000).status_code == 413
    assert client.post("/v1/redeem", content=b"{").status_code == 400


def test_rate_limit_and_reset(setup):
    _, license, clock, client = setup
    for _ in range(60):
        assert redeem(client, {"key": "invalid-key-that-is-long-enough"}).status_code == 401
    response = redeem(client, license)
    assert response.status_code == 429 and response.headers["retry-after"] == "60"
    clock[0] += 61
    assert redeem(client, license).status_code == 200


def test_restart_retains_bindings_and_sessions(setup):
    store, license, _, client = setup
    token = redeem(client, license).json()["token"]
    restarted = Store(store.directory, now=store.now)
    assert restarted.script("king", token, "device-one") == 'return "protected-script"'
    with pytest.raises(Denied, match="hwid_mismatch"):
        restarted.redeem("king", license["key"], "device-two")


def test_payload_registration_rejects_invalid_source_and_paths(setup, tmp_path):
    store, _, _, _ = setup
    source = tmp_path / "source.lua"
    source.write_bytes(b"\xff")
    with pytest.raises(UnicodeDecodeError):
        store.register("test", "Test", source)
    source.write_text("return true")
    with pytest.raises(ValueError):
        store.register("../../bad", "Test", source)


def test_sessions_are_bounded(setup):
    store, license, _, _ = setup
    for _ in range(12):
        store.redeem("king", license["key"], "device-one")
    with store.connect() as db:
        assert db.execute("SELECT count(*) FROM sessions").fetchone()[0] <= 5
