# web/app.py
from fastapi import FastAPI, WebSocket
from ..api.high import build_router
from ..lib.queue import QueueTransport


def make_app():
    transport = QueueTransport()
    app = FastAPI()
    app.include_router(build_router(transport, model_id="manual"))

    @app.websocket("/admin")
    async def admin(ws: WebSocket):
        await ws.accept()
        while True:
            req = await transport.next_request()
            await ws.send_json({"messages": req["messages"]})
            reply = await ws.receive_json()
            req["future"].set_result(reply["content"])

    return app
