import concurrent.futures

import pytest
from fastapi.testclient import TestClient

from key_service.api import create_app
from key_service.security import password_hash
from key_service.store import Denied


PASSWORD = "development-test-password"


@pytest.fixture(scope="session")
def admin_hash():
    return password_hash(PASSWORD)


@pytest.fixture
def admin(setup, admin_hash):
    store, license, clock, _ = setup
    client = TestClient(create_app(store, admin_hash=admin_hash, origin="http://testserver"))
    response = client.post("/admin/api/login", json={"password": PASSWORD}, headers={"origin": "http://testserver"})
    assert response.status_code == 200
    headers = {"origin": "http://testserver", "x-csrf-token": response.json()["csrf"]}
    return store, license, clock, client, headers


def test_all_management_requires_authentication(setup, admin_hash):
    store, license, _, _ = setup
    client = TestClient(create_app(store, admin_hash=admin_hash))
    for path in ["/me", "/applications", "/licenses", "/licenses/" + license["id"], "/licenses/" + license["id"] + "/executions"]:
        assert client.get("/admin/api" + path).status_code == 401
    for path, body in [("/licenses", {"application": "king"}), ("/licenses/" + license["id"], {"action": "delete"}), ("/applications", {"id": "test", "name": "Test", "source": "return true"})]:
        assert client.post("/admin/api" + path, json=body).status_code == 401
    assert client.get("/admin/").status_code == 200
    assert client.get("/admin/assets/app.js").status_code == 200


def test_login_security_and_logout(admin):
    store, _, _, client, headers = admin
    assert client.get("/admin/api/me").json()["csrf"] == headers["x-csrf-token"]
    cookie = client.cookies.get("kinoue_admin")
    assert cookie
    assert client.post("/admin/api/login", json={"password": PASSWORD}, headers={"origin": "https://attacker.invalid"}).status_code == 403
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"origin": "http://testserver"}).status_code == 401
    assert client.post("/admin/api/licenses", json={"application": "king"}, headers={"origin": "http://testserver"}).status_code == 403
    assert client.post("/admin/api/licenses", json={"application": "king"}, headers={**headers, "origin": "https://attacker.invalid"}).status_code == 403
    assert client.post("/admin/api/logout", json={}, headers=headers).status_code == 200
    client.cookies.set("kinoue_admin", cookie, domain="testserver.local", path="/admin")
    assert client.get("/admin/api/me").status_code == 401


def test_create_search_and_private_hwid_details(admin):
    store, _, _, client, headers = admin
    response = client.post("/admin/api/licenses", json={"application": "king", "days": 7, "label": "Test player"}, headers=headers)
    assert response.status_code == 200
    license = response.json()
    store.redeem("king", license["key"], "private-hwid-value")
    result = client.get("/admin/api/licenses?search=Test%20player&application=king&status=active").json()
    assert result["total"] == 1 and result["items"][0]["hwid_bound"]
    assert "private-hwid-value" not in str(result) and license["key"] not in str(result)
    detail = client.get("/admin/api/licenses/" + license["id"]).json()
    assert detail["hwid"] == "private-hwid-value" and detail["activity"][0]["action"] == "key_created"
    with store.connect() as db:
        saved = dict(db.execute("SELECT * FROM licenses WHERE id=?", (license["id"],)).fetchone())
    assert "private-hwid-value" not in str(saved) and license["key"] not in str(saved)


def test_replace_reset_revoke_restore_renew_and_delete(admin):
    store, license, clock, client, headers = admin
    path = "/admin/api/licenses/" + license["id"]
    old = store.redeem("king", license["key"], "original-device")

    def change(action, value=None):
        response = client.post(path, json={"action": action, "value": value}, headers=headers)
        assert response.status_code == 200

    change("set-hwid", "replacement-device")
    with pytest.raises(Denied):
        store.session("king", old["token"], "original-device")
    with pytest.raises(Denied, match="hwid_mismatch"):
        store.redeem("king", license["key"], "original-device")
    assert store.redeem("king", license["key"], "replacement-device")
    change("reset-hwid")
    assert client.get(path).json()["hwid"] is None
    assert store.redeem("king", license["key"], "third-device")
    change("revoke")
    with pytest.raises(Denied, match="license_revoked"):
        store.redeem("king", license["key"], "third-device")
    change("restore")
    assert store.redeem("king", license["key"], "third-device")
    clock[0] += 31 * 86400
    assert client.post("/admin/api/login", json={"password": PASSWORD}, headers={"origin": "http://testserver"}).status_code == 200
    headers["x-csrf-token"] = client.get("/admin/api/me").json()["csrf"]
    change("renew", 90)
    assert client.get(path).json()["expires_at"] == clock[0] + 90 * 86400
    assert store.redeem("king", license["key"], "third-device")
    change("delete")
    assert client.get(path).status_code == 404
    with pytest.raises(Denied):
        store.redeem("king", license["key"], "third-device")


def test_upload_payload_and_validation(admin):
    store, _, _, client, headers = admin
    source = 'return "' + "x" * 20000 + '"'
    response = client.post("/admin/api/applications", json={"id": "new-script", "name": "New script", "source": source}, headers=headers)
    assert response.status_code == 200
    license = store.issue("new-script", 7)
    session = store.redeem("new-script", license["key"], "a-device")
    assert store.script("new-script", session["token"], "a-device") == source
    assert client.post("/admin/api/applications", json={"id": "new-script", "name": "Updated", "source": "return 2"}, headers=headers).status_code == 200
    assert store.script("new-script", session["token"], "a-device") == "return 2"
    assert client.post("/admin/api/licenses", json={"application": "unknown"}, headers=headers).status_code == 400
    assert client.post("/admin/api/licenses", json={"application": "king", "days": 0}, headers=headers).status_code == 400
    assert client.post("/admin/api/applications", json={"id": "../bad", "name": "Bad", "source": "return true"}, headers=headers).status_code == 400
    assert client.post("/admin/api/applications", content=b"x" * (3 * 1024 * 1024 + 1), headers=headers).status_code == 413


def test_password_change_and_expired_admin_session(admin, admin_hash):
    store, _, clock, client, _ = admin
    cookies = dict(client.cookies)
    changed = TestClient(create_app(store, admin_hash=password_hash("a-new-password-12345")))
    for key, value in cookies.items():
        changed.cookies.set(key, value, domain="testserver.local", path="/admin")
    assert changed.get("/admin/api/me").status_code == 401
    clock[0] += 28801
    assert client.get("/admin/api/me").status_code == 401


def test_admin_login_throttled(setup, admin_hash):
    store, _, _, _ = setup
    client = TestClient(create_app(store, admin_hash=admin_hash))
    for _ in range(8):
        assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"origin": "http://testserver"}).status_code == 401
    response = client.post("/admin/api/login", json={"password": PASSWORD}, headers={"origin": "http://testserver"})
    assert response.status_code == 429


def test_rotating_same_token_concurrently_only_succeeds_once(setup):
    store, license, _, _ = setup
    token = store.redeem("king", license["key"], "device")["token"]

    def rotate(_):
        try:
            store.session("king", token, "device", rotate=True)
            return "ok"
        except Denied:
            return "rejected"

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(rotate, range(2))) == ["ok", "rejected"]


def test_admin_page_security_headers(admin):
    _, _, _, client, _ = admin
    response = client.get("/admin/")
    assert response.headers["x-frame-options"] == "DENY"
    assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
    assert response.headers["cache-control"] == "no-store"
    assert client.get("/admin/assets/../../var/secret.key").status_code != 200
