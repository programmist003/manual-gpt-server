# cli/main.py
import uvicorn
from fastapi import FastAPI
from ..api.high import build_router
from ..lib.terminal import TerminalTransport


def make_app():
    transport = TerminalTransport()
    app = FastAPI()
    app.include_router(build_router(transport, model_id="manual"))
    return app


def main():
    uvicorn.run(make_app(), host="127.0.0.1", port=8000)
