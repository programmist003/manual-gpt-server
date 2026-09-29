from __future__ import annotations

from fastapi import WebSocket, WebSocketDisconnect

from manual_gpt_server.lib.runtime import RuntimeState


async def admin_endpoint(ws: WebSocket, state: RuntimeState) -> None:
    await ws.accept()
    current = None
    try:
        while True:
            req = await state.next_request()
            current = req
            await ws.send_json(
                {
                    "type": "request",
                    "id": req["id"],
                    "messages": req["messages"],
                }
            )
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
        if current is not None:
            await current["out"].put(None)
        while not state.pending.empty():
            pending = state.pending.get_nowait()
            await pending["out"].put(None)
        return