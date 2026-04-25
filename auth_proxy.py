"""Lightweight reverse proxy that gates PaddleX with Bearer-token auth.

PaddleX listens on 127.0.0.1:8080 (internal only).
This proxy listens on 0.0.0.0:8000 and validates the Authorization header
before forwarding requests to PaddleX.

If PADDLEOCR_API_TOKEN is empty, all requests are passed through (no auth).
"""

import os
import logging

import httpx
from fastapi import FastAPI, Request, Response, HTTPException

UPSTREAM = "http://127.0.0.1:8080"
API_TOKEN = os.environ.get("PADDLEOCR_API_TOKEN", "")

logger = logging.getLogger("auth_proxy")
app = FastAPI()


@app.middleware("http")
async def token_gate(request: Request, call_next):
    if API_TOKEN and request.url.path != "/health":
        auth = request.headers.get("authorization", "")
        if auth != f"Bearer {API_TOKEN}":
            raise HTTPException(status_code=401, detail="Unauthorized")
    return await call_next(request)


@app.api_route("/{path:path}", methods=["GET", "POST", "OPTIONS", "HEAD"])
async def proxy(request: Request, path: str):
    url = f"{UPSTREAM}/{path}"
    headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in ("host", "authorization")
    }
    body = await request.body()

    async with httpx.AsyncClient(timeout=660.0) as client:
        resp = await client.request(
            method=request.method,
            url=url,
            headers=headers,
            content=body,
            params=request.query_params,
        )

    return Response(
        content=resp.content,
        status_code=resp.status_code,
        headers=dict(resp.headers),
    )
