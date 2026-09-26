from fastapi import FastAPI
from manual_gpt_server.server import build_app
from manual_gpt_server.lib.terminal import TerminalTransport
from manual_gpt_server.lib.config import Settings


def make_app() -> FastAPI:
    settings = Settings()
    return build_app(TerminalTransport(), model_id=settings.model_id)


def main() -> None:
    settings = Settings()
    import uvicorn
    uvicorn.run(make_app(), host=settings.host, port=settings.port)