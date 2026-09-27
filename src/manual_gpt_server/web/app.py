from __future__ import annotations

from pathlib import Path

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from manual_gpt_server.lib.config import Settings
from manual_gpt_server.lib.queue import QueueTransport
from manual_gpt_server.rest.server import build_rest_app

STATIC_DIR = Path(__file__).parent / "static"


def make_app() -> FastAPI:
    settings = Settings()
    transport = QueueTransport()
    app = build_rest_app(transport, model_id=settings.model_id)

    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

    @app.get("/")
    async def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "admin.html")

    @app.websocket("/admin")
    async def admin(ws: WebSocket) -> None:
        await ws.accept()
        current: dict | None = None
        try:
            while True:
                req = await transport.next_request()
                current = req
                await ws.send_json({"type": "request", "messages": req["messages"]})

                while True:
                    msg = await ws.receive_json()
                    kind = msg.get("type")
                    if kind == "delta":
                        await req["out"].put(msg["content"])
                    elif kind == "done":
                        await req["out"].put(None)
                        current = None
                        break
        except WebSocketDisconnect:
            # 1) текущий запрос — закрыть стрим
            if current is not None:
                await current["out"].put(None)
            # 2) все, что успели накопиться в очереди — тоже закрыть,
            #    иначе клиенты /v1/chat/completions будут висеть вечно
            while not transport.pending.empty():
                pending = transport.pending.get_nowait()
                await pending["out"].put(None)
            return


def main() -> None:
    settings = Settings()
    uvicorn.run(make_app(), host=settings.host, port=settings.port)


if __name__ == "__main__":
    main()