from __future__ import annotations

import asyncio
import time
import uuid
from typing import Any, AsyncIterator


class RuntimeState:
    """Общее состояние между API-слоем и control-plane.

    Сюда стекаются запросы из /v1/*, отсюда их забирает /admin.
    Хранит очередь, историю, счётчики.
    """

    def __init__(self) -> None:
        self._pending: asyncio.Queue[dict[str, Any]] | None = None
        self._history: list[dict[str, Any]] = []
        self._handled: int = 0
        self._started_at: float = time.time()

    @property
    def pending(self) -> asyncio.Queue[dict[str, Any]]:
        # Ленивая инициализация: очередь создаётся внутри работающего
        # event loop, иначе её future'ы привяжутся к чужому циклу.
        if self._pending is None:
            self._pending = asyncio.Queue()
        return self._pending

    # --- Transport protocol (для rest/routes.py) ---

    async def stream(self, messages: list[dict]) -> AsyncIterator[str]:
        out: asyncio.Queue[str | None] = asyncio.Queue()
        req = {
            "id": uuid.uuid4().hex,
            "messages": messages,
            "out": out,
            "created": time.time(),
        }
        await self.pending.put(req)

        parts: list[str] = []
        while True:
            chunk = await out.get()
            if chunk is None:
                self._handled += 1
                self._history.append(
                    {
                        "id": req["id"],
                        "messages": messages,
                        "answer": "".join(parts),
                        "created": req["created"],
                        "finished": time.time(),
                    }
                )
                if len(self._history) > 50:
                    self._history = self._history[-50:]
                return
            parts.append(chunk)
            yield chunk

    # --- Control-plane API ---

    async def next_request(self) -> dict[str, Any]:
        return await self.pending.get()

    def status(self) -> dict[str, Any]:
        return {
            "uptime_seconds": int(time.time() - self._started_at),
            "queue_len": self.pending.qsize() if self._pending is not None else 0,
            "requests_handled": self._handled,
            "history_len": len(self._history),
        }

    def history(self) -> list[dict[str, Any]]:
        return list(reversed(self._history))