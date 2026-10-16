import concurrent.futures
import hashlib

import pytest
from fastapi.testclient import TestClient
from starlette.requests import Request

from key_service.api import create_app
from key_service.security import client_address, login_network, password_hash, verify_password
from key_service.store import Denied, Store
from key_service.postgres import PostgresStore


def test_password_hash_is_salted_and_uses_current_work_factor():
    password = "a-long-test-password-with-spaces"
    first, second = password_hash(password), password_hash(password)
    assert first != second
    assert first.startswith("scrypt$131072$8$1$")
    assert password not in first
    assert verify_password(password, first)
    assert not verify_password(password + "wrong", first)
    assert not verify_password("x" * 257, first)
    assert not verify_password(None, first)
    with pytest.raises(ValueError):
        password_hash("short-password")


def test_legacy_hash_can_be_read_without_changing_the_password():
    salt = "ab" * 16
    derived = hashlib.scrypt(b"legacy-test-password", salt=bytes.fromhex(salt), n=32768, r=8, p=1, maxmem=67108864)
    encoded = "scrypt$" + salt + "$" + derived.hex()
    assert verify_password("legacy-test-password", encoded)
    assert not verify_password("incorrect", encoded)


@pytest.mark.parametrize("encoded", ["", "bad$value", "scrypt$1000000000$8$1$" + "ab" * 16 + "$" + "01" * 64, "scrypt$131072$8$1$zz$not-hex", None])
def test_bad_password_hashes_fail_closed(encoded):
    assert not verify_password("test-password", encoded)


def request_for_address(vercel=False, peer="192.0.2.1", **headers):
    class State:
        pass
    app = State()
    app.state = State()
    app.state.vercel = vercel
    return Request({"type": "http", "app": app, "client": (peer, 12345), "headers": [(name.replace("_", "-").encode(), value.encode()) for name, value in headers.items()]})


def test_only_vercel_proxy_address_is_trusted_in_vercel_runtime():
    local = request_for_address(x_forwarded_for="198.51.100.1", x_vercel_forwarded_for="198.51.100.2")
    assert client_address(local) == "192.0.2.1"
    hosted = request_for_address(True, x_forwarded_for="198.51.100.1", x_vercel_forwarded_for="2001:db8::01")
    assert client_address(hosted) == "2001:db8::1"
    assert client_address(request_for_address(True, x_vercel_forwarded_for="invalid")) == "192.0.2.1"
    assert login_network("2001:db8:42::1") == login_network("2001:db8:42::ffff")
    assert login_network("2001:db8:43::1") != login_network("2001:db8:42::1")


def test_login_burst_is_shared_across_ips_and_avoids_password_work(setup, monkeypatch):
    store, _, clock, _ = setup
    calls = []
    monkeypatch.setattr("key_service.admin.verify_password", lambda *args: calls.append(True) or False)
    app = create_app(store, admin_hash="configured", origin="http://testserver")
    for index in range(3):
        client = TestClient(app, client=(f"192.0.2.{index + 1}", 12345))
        assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401
    client = TestClient(app, client=("198.51.100.1", 12345))
    response = client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"})
    assert response.status_code == 429 and response.headers["retry-after"] == "10"
    assert len(calls) == 3
    clock[0] += 11
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401
    assert len(calls) == 4


def test_rotating_ips_cannot_bypass_the_account_window(setup, monkeypatch):
    store, _, clock, _ = setup
    calls = []
    monkeypatch.setattr("key_service.admin.verify_password", lambda *args: calls.append(True) or False)
    app = create_app(store, admin_hash="configured", origin="http://testserver")
    for index in range(30):
        if index and index % 3 == 0:
            clock[0] += 11
        client = TestClient(app, client=(f"192.0.2.{index + 1}", 12345))
        assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401
    clock[0] += 11
    client = TestClient(app, client=("198.51.100.1", 12345))
    response = client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"})
    assert response.status_code == 429 and int(response.headers["retry-after"]) == 790
    assert len(calls) == 30
    # A separate application/store instance sees the same persistent cooldown.
    restarted = PostgresStore(store.url, store.secret.hex(), now=store.now) if isinstance(store, PostgresStore) else Store(store.directory, now=store.now)
    client = TestClient(create_app(restarted, admin_hash="configured", origin="http://testserver"), client=("198.51.100.2", 12345))
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 429
    clock[0] += 791
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401


def test_login_ip_budget_covers_invalid_bodies_and_ignores_forwarded_spoofs(setup):
    store, _, _, _ = setup
    client = TestClient(create_app(store, admin_hash="configured", origin="http://testserver"), client=("192.0.2.1", 12345))
    for index in range(5):
        response = client.post("/admin/api/login", content=b"{", headers={"Origin": "http://testserver", "X-Forwarded-For": f"198.51.100.{index}", "X-Vercel-Forwarded-For": f"198.51.100.{index}"})
        assert response.status_code == 400
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 429


def test_slow_guessing_is_limited_over_an_hour(setup, monkeypatch):
    store, _, clock, _ = setup
    calls = []
    monkeypatch.setattr("key_service.admin.verify_password", lambda *args: calls.append(True) or False)
    client = TestClient(create_app(store, admin_hash="configured", origin="http://testserver"), client=("192.0.2.1", 12345))
    for _ in range(20):
        assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401
        clock[0] += 151
    response = client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"})
    assert response.status_code == 429 and response.headers["retry-after"] == "580"
    assert len(calls) == 20
    clock[0] += 581
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 401


def test_existing_admin_sessions_still_work_during_a_login_cooldown(setup):
    store, _, _, _ = setup
    admin_hash = password_hash("development-test-password")
    client = TestClient(create_app(store, admin_hash=admin_hash, origin="http://testserver"))
    response = client.post("/admin/api/login", json={"password": "development-test-password"}, headers={"Origin": "http://testserver"})
    assert response.status_code == 200
    for _ in range(2):
        store.rate_limit("administrator", "login-account-burst", 3, 10)
    assert client.post("/admin/api/login", json={"password": "wrong"}, headers={"Origin": "http://testserver"}).status_code == 429
    assert client.get("/admin/api/me").status_code == 200
    assert client.get("/admin/api/licenses").status_code == 200


def test_rate_limit_is_atomic_across_parallel_requests(setup):
    store, _, _, _ = setup
    def attempt(_):
        try:
            store.rate_limit("parallel-client", "parallel-test", 5, 300)
            return True
        except Denied as error:
            assert error.status == 429 and error.retry_after == 300
            return False
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        assert sum(pool.map(attempt, range(20))) == 5


def test_https_and_throttled_responses_keep_security_headers(setup):
    store, _, _, _ = setup
    client = TestClient(create_app(store, admin_hash=""), base_url="https://testserver")
    response = client.get("/admin/")
    assert response.headers["strict-transport-security"] == "max-age=31536000"
    assert response.headers["permissions-policy"] == "camera=(), microphone=(), geolocation=()"
    assert client.get("/admin/assets/theme.js").status_code == 200
