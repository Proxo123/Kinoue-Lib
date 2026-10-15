import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, ConfigDict, Field
from starlette.concurrency import run_in_threadpool

from .store import Denied, Store


class Credentials(BaseModel):
    model_config = ConfigDict(extra="forbid")
    application: str = Field(strict=True, pattern=r"^[a-z][a-z0-9_-]{0,63}$")
    hwid: str = Field(strict=True, min_length=1, max_length=512)


class Redemption(Credentials):
    key: str = Field(strict=True, min_length=16, max_length=256)


class Session(Credentials):
    token: str = Field(strict=True, min_length=32, max_length=256)


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
            if size > 8192:
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


def create_app(store=None):
    store = store or Store(Path(os.environ.get("KINOUE_DATA_DIR", "var")))
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(BodyLimit)

    @app.middleware("http")
    async def guard(request: Request, call_next):
        if request.url.path != "/health":
            try:
                await run_in_threadpool(store.rate_limit, request.client.host if request.client else "unknown")
            except Denied as error:
                return JSONResponse({"error": error.code}, status_code=error.status, headers={"Retry-After": "60", "Cache-Control": "no-store"})
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.exception_handler(Denied)
    async def denied(_, error):
        return JSONResponse({"error": error.code}, status_code=error.status)

    @app.exception_handler(RequestValidationError)
    async def invalid(_, __):
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

    return app
