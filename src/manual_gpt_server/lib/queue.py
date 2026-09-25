# lib/queue.py
import asyncio
from typing import Any


class QueueTransport:
    """Web-транспорт: запрос кладётся в очередь, ответ приходит через asyncio.Future."""

    def __init__(self):
        self.pending: asyncio.Queue[dict[str, Any]] = asyncio.Queue()

    async def ask(self, messages: list[dict]) -> str:
        loop = asyncio.get_running_loop()
        future: asyncio.Future[str] = loop.create_future()
        await self.pending.put({"messages": messages, "future": future})
        return await future

    async def next_request(self):
        return await self.pending.get()
