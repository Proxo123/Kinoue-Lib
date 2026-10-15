import hmac
import os
from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, StrictInt, StrictStr

from .security import verify_password
from .store import Denied


class Login(BaseModel):
    model_config = ConfigDict(extra="forbid")
    password: str = Field(strict=True, min_length=1, max_length=256)


class Issue(BaseModel):
    model_config = ConfigDict(extra="forbid")
    application: str = Field(strict=True, pattern=r"^[a-z][a-z0-9_-]{0,63}$")
    label: str = Field(default="", strict=True, max_length=120)
    days: int = Field(default=30, strict=True, ge=1, le=3650)


class Script(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str = Field(strict=True, pattern=r"^[a-z][a-z0-9_-]{0,63}$")
    name: str = Field(strict=True, min_length=1, max_length=80)
    source: str = Field(strict=True, min_length=1, max_length=2097152)


class Change(BaseModel):
    model_config = ConfigDict(extra="forbid")
    action: Literal["revoke", "restore", "reset-hwid", "set-hwid", "renew", "delete"]
    value: StrictStr | StrictInt | None = None


def attach_admin(app, store, admin_hash=None, origin=None):
    admin_hash = admin_hash if admin_hash is not None else os.environ.get("KINOUE_ADMIN_PASSWORD_HASH", "")
    origin = origin or os.environ.get("KINOUE_ADMIN_ORIGIN", "")
    if not admin_hash and not os.environ.get("VERCEL"):
        path = Path(os.environ.get("KINOUE_DATA_DIR", "var")) / "admin-password.hash"
        if path.is_file():
            admin_hash = path.read_text().strip()
    if os.environ.get("VERCEL") and (not admin_hash or not origin.startswith("https://")):
        raise ValueError("Vercel requires KINOUE_ADMIN_PASSWORD_HASH and an HTTPS KINOUE_ADMIN_ORIGIN")
    if origin and (urlsplit(origin).path not in ("", "/") or urlsplit(origin).query or urlsplit(origin).fragment or urlsplit(origin).username):
        raise ValueError("KINOUE_ADMIN_ORIGIN must contain only the site origin")
    password_version = store.digest("admin-password", admin_hash)
    assets = Path(__file__).parent / "web"
    router = APIRouter(prefix="/admin/api")

    def check_origin(request):
        expected = origin.rstrip("/") if origin else str(request.base_url).rstrip("/")
        if not origin and request.url.hostname not in ("localhost", "127.0.0.1", "testserver"):
            raise Denied("admin_origin_unconfigured", 503)
        if request.headers.get("origin") != expected or request.headers.get("sec-fetch-site") == "cross-site":
            raise Denied("invalid_origin", 403)

    def authenticated(request: Request):
        if not admin_hash:
            raise Denied("admin_unconfigured", 503)
        token = request.cookies.get("kinoue_admin", "")
        csrf = store.admin_session(token, password_version)
        if request.method != "GET":
            check_origin(request)
            if not hmac.compare_digest(request.headers.get("x-csrf-token", ""), csrf):
                raise Denied("invalid_csrf", 403)
        return csrf

    @app.get("/", include_in_schema=False)
    def home():
        return RedirectResponse("/admin/", status_code=303)

    @app.get("/admin", include_in_schema=False)
    @app.get("/admin/", include_in_schema=False)
    def page():
        return FileResponse(assets / "index.html", media_type="text/html")

    @app.get("/admin/assets/{filename}", include_in_schema=False)
    def asset(filename: Literal["app.js", "style.css", "icon.svg"]):
        return FileResponse(assets / filename, media_type={"app.js": "text/javascript", "style.css": "text/css", "icon.svg": "image/svg+xml"}[filename])

    @router.post("/login")
    def login(body: Login, request: Request):
        check_origin(request)
        store.rate_limit(request.client.host if request.client else "unknown", "login", 8, 300)
        if not admin_hash:
            raise Denied("admin_unconfigured", 503)
        if not verify_password(body.password, admin_hash):
            raise Denied("invalid_admin_password")
        old = request.cookies.get("kinoue_admin")
        if old:
            store.admin_logout(old)
        token = store.admin_login(password_version)
        response = JSONResponse({"csrf": store.digest("admin-csrf", token)})
        response.set_cookie("kinoue_admin", token, httponly=True, secure=bool(os.environ.get("VERCEL")) or request.url.scheme == "https", samesite="strict", max_age=28800, path="/admin")
        return response

    @router.get("/me")
    def me(csrf=Depends(authenticated)):
        return {"csrf": csrf}

    @router.post("/logout")
    def logout(request: Request, _=Depends(authenticated)):
        store.admin_logout(request.cookies["kinoue_admin"])
        response = JSONResponse({"ok": True})
        response.delete_cookie("kinoue_admin", path="/admin", httponly=True, secure=bool(os.environ.get("VERCEL")) or request.url.scheme == "https", samesite="strict")
        return response

    @router.get("/applications")
    def applications(_=Depends(authenticated)):
        return {"items": store.applications()}

    @router.post("/applications")
    def save_script(body: Script, _=Depends(authenticated)):
        store.register_source(body.id, body.name, body.source)
        return {"ok": True}

    @router.get("/licenses")
    def licenses(application: str = Query(default="", max_length=64), search: str = Query(default="", max_length=120), status: Literal["", "active", "expired", "revoked"] = "", page: int = Query(default=1, ge=1, le=1000000), _=Depends(authenticated)):
        return store.licenses(application, search, status, page)

    @router.get("/licenses/{identifier}")
    def license_detail(identifier: str, _=Depends(authenticated)):
        return store.license_detail(identifier)

    @router.post("/licenses")
    def issue(body: Issue, _=Depends(authenticated)):
        return store.issue(body.application, body.days, body.label)

    @router.get("/licenses/{identifier}/executions")
    def executions(identifier: str, page: int = Query(default=1, ge=1, le=1000000), _=Depends(authenticated)):
        return store.executions(identifier, page)

    @router.post("/licenses/{identifier}")
    def change(identifier: str, body: Change, _=Depends(authenticated)):
        if not store.change_license(identifier, body.action, body.value):
            raise Denied("not_found", 404)
        return {"ok": True}

    app.include_router(router)
