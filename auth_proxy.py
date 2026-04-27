"""Lightweight reverse proxy that gates PaddleX with Bearer-token auth.

PaddleX listens on 127.0.0.1:8080 (internal only).
This proxy listens on 0.0.0.0:8000 and validates the Authorization header
before forwarding requests to PaddleX.

If PADDLEOCR_API_TOKEN is empty, all requests are passed through (no auth).
"""

import hmac
import os
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Response

UPSTREAM = "http://127.0.0.1:8080"
API_TOKEN = os.environ.get("PADDLEOCR_API_TOKEN", "")

_HOP_HEADERS = frozenset({
    "transfer-encoding", "connection", "keep-alive",
    "proxy-authenticate", "proxy-authorization", "te",
    "trailers", "upgrade", "content-encoding", "content-length",
})

_STRIP_REQUEST_HEADERS = frozenset({"host", "authorization", "accept-encoding"})

_http_client: httpx.AsyncClient | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _http_client
    _http_client = httpx.AsyncClient(timeout=660.0)
    yield
    await _http_client.aclose()


app = FastAPI(lifespan=lifespan)


@app.middleware("http")
async def token_gate(request: Request, call_next):
    if API_TOKEN and request.url.path != "/health":
        auth = request.headers.get("authorization", "")
        expected = f"Bearer {API_TOKEN}"
        if not hmac.compare_digest(auth.encode(), expected.encode()):
            return Response(content='{"detail":"Unauthorized"}', status_code=401, media_type="application/json")
    return await call_next(request)


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def proxy(request: Request, path: str):
    url = f"{UPSTREAM}/{path}"
    fwd_headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in _STRIP_REQUEST_HEADERS
    }
    body = await request.body()

    resp = await _http_client.request(
        method=request.method,
        url=url,
        headers=fwd_headers,
        content=body,
        params=request.query_params,
    )

    resp_headers = {
        k: v for k, v in resp.headers.items()
        if k.lower() not in _HOP_HEADERS
    }
    return Response(
        content=resp.content,
        status_code=resp.status_code,
        headers=resp_headers,
        media_type=resp.headers.get("content-type"),
    )
