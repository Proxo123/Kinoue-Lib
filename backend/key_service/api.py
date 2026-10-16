import os

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, ConfigDict, Field
from starlette.concurrency import run_in_threadpool

from .store import Denied
from .postgres import environment_store
from .admin import attach_admin
from .security import client_address, login_network


class Credentials(BaseModel):
    model_config = ConfigDict(extra="forbid")
    application: str = Field(strict=True, pattern=r"^[a-z][a-z0-9_-]{0,63}$")
    hwid: str = Field(strict=True, min_length=1, max_length=512)


class Redemption(Credentials):
    key: str = Field(strict=True, min_length=16, max_length=256)


class Session(Credentials):
    token: str = Field(strict=True, min_length=32, max_length=256)


class Execution(Session):
    execution_id: str = Field(strict=True, pattern=r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    user_id: int = Field(strict=True, ge=1, le=9007199254740991)
    username: str = Field(strict=True, pattern=r"^[A-Za-z0-9_]{1,20}$")
    display_name: str = Field(strict=True, min_length=1, max_length=50)
    place_id: int = Field(strict=True, ge=0, le=9007199254740991)
    library_version: str = Field(strict=True, pattern=r"^[0-9A-Za-z._-]{1,32}$")


class BodyLimit:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        chunks, size = [], 0
        while True:
            event = await receive()
            if event["type"] == "http.disconnect":
                return
            size += len(event.get("body", b""))
            limit = 3 * 1024 * 1024 if scope.get("path") == "/admin/api/applications" else 8192
            if size > limit:
                await JSONResponse({"error": "request_too_large"}, status_code=413)(scope, receive, send)
                return
            chunks.append(event.get("body", b""))
            if not event.get("more_body", False):
                break
        delivered = False

        async def replay():
            nonlocal delivered
            if delivered:
                return await receive()
            delivered = True
            return {"type": "http.request", "body": b"".join(chunks), "more_body": False}

        await self.app(scope, replay, send)


def create_app(store=None, admin_hash=None, origin=None):
    store = store or environment_store()
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.state.vercel = bool(os.environ.get("VERCEL"))
    app.add_middleware(BodyLimit)

    @app.middleware("http")
    async def guard(request: Request, call_next):
        if request.url.path.startswith(("/v1/", "/admin/api/")):
            try:
                admin = request.url.path.startswith("/admin/")
                address = client_address(request)
                await run_in_threadpool(store.rate_limit, address, "admin" if admin else "client", 180 if admin else 60)
                if request.method == "POST" and request.url.path == "/admin/api/login":
                    network = login_network(address)
                    await run_in_threadpool(store.rate_limit, network, "login-ip-short", 5, 300)
                    await run_in_threadpool(store.rate_limit, network, "login-ip-hour", 20, 3600)
            except Denied as error:
                response = JSONResponse({"error": error.code}, status_code=error.status)
                if error.retry_after:
                    response.headers["Retry-After"] = str(error.retry_after)
            else:
                response = await call_next(request)
        else:
            response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Content-Security-Policy"] = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if request.url.scheme == "https" or app.state.vercel:
            response.headers["Strict-Transport-Security"] = "max-age=31536000"
        return response

    @app.exception_handler(Denied)
    async def denied(_, error):
        headers = {"Retry-After": str(error.retry_after)} if error.retry_after else {}
        return JSONResponse({"error": error.code}, status_code=error.status, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def invalid(_, __):
        return JSONResponse({"error": "invalid_request"}, status_code=400)

    @app.exception_handler(ValueError)
    async def invalid_value(_, __):
        return JSONResponse({"error": "invalid_request"}, status_code=400)

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.post("/v1/redeem")
    def redeem(body: Redemption):
        return store.redeem(body.application, body.key, body.hwid)

    @app.post("/v1/session")
    def session(body: Session):
        return store.session(body.application, body.token, body.hwid, rotate=True)

    @app.post("/v1/script", response_class=PlainTextResponse)
    def script(body: Session):
        return store.script(body.application, body.token, body.hwid)

    @app.post("/v1/logout")
    def logout(body: Session):
        return store.logout(body.application, body.token, body.hwid)

    @app.post("/v1/executions")
    def execution(body: Execution):
        return store.record_execution(**body.model_dump())

    attach_admin(app, store, admin_hash, origin)
    return app
