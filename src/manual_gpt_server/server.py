# src/manual_gpt_server/server.py
from __future__ import annotations

from fastapi import FastAPI

from manual_gpt_server.api.high import build_router
from manual_gpt_server.lib.transport import Transport


def build_app(transport: Transport, model_id: str = "manual") -> FastAPI:
    """Композиционный корень: собирает FastAPI-приложение из слоёв."""
    app = FastAPI()
    app.include_router(build_router(transport, model_id=model_id))
    return app