from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, WebSocket
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from manual_gpt_server.control.admin import admin_endpoint
from manual_gpt_server.control.routes import build_router
from manual_gpt_server.lib.runtime import RuntimeState

STATIC_DIR = Path(__file__).parent / "static"


def build_control_app(state: RuntimeState) -> FastAPI:
    app = FastAPI(title="manual-gpt-server control")
    app.include_router(build_router(state))

    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

    @app.get("/")
    async def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "admin.html")

    @app.websocket("/admin")
    async def admin(ws: WebSocket) -> None:
        await admin_endpoint(ws, state)

    return app