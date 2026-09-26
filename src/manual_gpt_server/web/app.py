from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import uvicorn
from manual_gpt_server.server import build_app
from manual_gpt_server.lib.queue import QueueTransport
from manual_gpt_server.lib.config import Settings


def make_app() -> FastAPI:
    settings = Settings()
    transport = QueueTransport()
    app = build_app(transport, model_id=settings.model_id)

    @app.websocket("/admin")
    async def admin(ws: WebSocket) -> None:
        await ws.accept()
        try:
            while True:
                req = await transport.next_request()
                await ws.send_json({"messages": req["messages"]})
                reply = await ws.receive_json()
                req["future"].set_result(reply["content"])
        except WebSocketDisconnect:
            return

    return app


def main() -> None:
    settings = Settings()
    uvicorn.run(make_app(), host=settings.host, port=settings.port)


if __name__ == "__main__":
    main()
