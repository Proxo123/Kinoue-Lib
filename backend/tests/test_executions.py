import uuid

from test_service import redeem
from test_admin import admin, admin_hash


def execution_body(token, **changes):
    return {
        "application": "king", "hwid": "device-one", "token": token,
        "execution_id": str(uuid.uuid4()), "user_id": 1234567, "username": "Test_Player",
        "display_name": "Test Player", "place_id": 987654, "library_version": "0.9.3", **changes,
    }


def test_execution_is_authenticated_idempotent_and_uses_server_time(setup):
    store, license, clock, client = setup
    session = redeem(client, license).json()
    assert session["license_expires_at"] == license["expires_at"] and session["server_time"] == clock[0]
    body = execution_body(session["token"])
    assert store.executions(license["id"])["total"] == 0
    assert client.post("/v1/executions", json=body).json() == {"ok": True}
    clock[0] += 2
    assert client.post("/v1/executions", json=body).status_code == 200
    history = store.executions(license["id"])
    assert history["total"] == 1
    assert history["items"][0] == {
        "user_id": 1234567, "username": "Test_Player", "display_name": "Test Player",
        "place_id": 987654, "library_version": "0.9.3", "executed_at": clock[0] - 2,
    }
    assert session["token"] not in str(history) and license["key"] not in str(history) and "device-one" not in str(history)


def test_execution_rejects_wrong_key_device_application_and_expiry(setup):
    store, license, clock, client = setup
    token = redeem(client, license).json()["token"]
    body = execution_body(token)
    for changes, status in [({"token": "x" * 43}, 401), ({"hwid": "different"}, 403), ({"application": "second"}, 401)]:
        assert client.post("/v1/executions", json={**body, **changes}).status_code == status
    assert store.executions(license["id"])["total"] == 0
    clock[0] = license["expires_at"]
    assert client.post("/v1/executions", json=body).status_code == 403


def test_execution_fields_are_bounded_and_private(setup):
    _, license, _, client = setup
    body = execution_body(redeem(client, license).json()["token"])
    for changes in [{"user_id": True}, {"user_id": 0}, {"username": "x" * 21}, {"display_name": "x" * 51}, {"execution_id": "bad"}, {"place_id": -1}, {"executed_at": 1}]:
        response = client.post("/v1/executions", json={**body, **changes})
        assert response.status_code == 400 and body["token"] not in response.text


def test_admin_execution_history_is_per_key_paginated_and_survives_reset(admin):
    store, license, clock, client, headers = admin
    token = store.redeem("king", license["key"], "device-one")["token"]
    for index in range(27):
        clock[0] += 1
        assert client.post("/v1/executions", json=execution_body(token, user_id=1000 + index)).status_code == 200
    other = store.issue("king", 30)
    path = "/admin/api/licenses/" + license["id"]
    detail = client.get(path).json()
    assert detail["executions"]["total"] == 27 and len(detail["executions"]["items"]) == 25
    assert detail["executions"]["items"][0]["user_id"] == 1026
    assert len(client.get(path + "/executions?page=2").json()["items"]) == 2
    assert client.get("/admin/api/licenses/" + other["id"] + "/executions").json()["total"] == 0
    assert client.post(path, json={"action": "reset-hwid"}, headers=headers).status_code == 200
    assert client.get(path).json()["executions"]["total"] == 27
    assert client.post("/v1/executions", json=execution_body(token)).status_code == 401
    assert client.post(path, json={"action": "delete"}, headers=headers).status_code == 200
    with store.connect() as db:
        assert db.execute("SELECT COUNT(*) AS total FROM executions WHERE license_id=?", (license["id"],)).fetchone()["total"] == 0


def test_download_does_not_report_a_successful_execution(setup):
    store, license, _, client = setup
    session = redeem(client, license).json()
    assert client.post("/v1/script", json={"application": "king", "token": session["token"], "hwid": "device-one"}).status_code == 200
    assert store.executions(license["id"])["total"] == 0
