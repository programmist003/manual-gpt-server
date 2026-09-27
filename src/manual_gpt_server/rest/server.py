# rest/server.py
from __future__ import annotations

from fastapi import FastAPI

from manual_gpt_server.lib.transport import Transport
from manual_gpt_server.rest.routes import build_router


def build_rest_app(transport: Transport, model_id: str = "manual") -> FastAPI:
    """Композиционный корень REST-слоя: собирает FastAPI-приложение из транспорта."""
    app = FastAPI(title="manual-gpt-server", version="0.1.0")
    app.include_router(build_router(transport, model_id=model_id))
    return app