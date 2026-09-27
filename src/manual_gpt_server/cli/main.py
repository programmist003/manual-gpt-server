from __future__ import annotations

from fastapi import FastAPI

from manual_gpt_server.lib.config import Settings
from manual_gpt_server.lib.terminal import TerminalTransport
from manual_gpt_server.rest.server import build_rest_app


def make_app() -> FastAPI:
    settings = Settings()
    return build_rest_app(TerminalTransport(), model_id=settings.model_id)


def main() -> None:
    import uvicorn

    settings = Settings()
    uvicorn.run(make_app(), host=settings.host, port=settings.port)