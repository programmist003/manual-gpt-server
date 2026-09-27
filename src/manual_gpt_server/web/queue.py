from __future__ import annotations

import asyncio
from typing import Any, AsyncIterator


class QueueTransport:
    """Веб-транспорт: запрос уходит админке через очередь, ответ приходит чанками."""

    def __init__(self) -> None:
        self._pending: asyncio.Queue[dict[str, Any]] | None = None

    @property
    def pending(self) -> asyncio.Queue[dict[str, Any]]:
        # Ленивая инициализация: очередь должна создаваться
        # внутри работающего event loop, иначе её future'ы
        # привяжутся к чужому циклу (RuntimeError: different loop).
        if self._pending is None:
            self._pending = asyncio.Queue()
        return self._pending

    async def stream(self, messages: list[dict]) -> AsyncIterator[str]:
        out: asyncio.Queue[str | None] = asyncio.Queue()
        await self.pending.put({"messages": messages, "out": out})
        while True:
            chunk = await out.get()
            if chunk is None:
                return
            yield chunk

    async def next_request(self) -> dict[str, Any]:
        return await self.pending.get()
