import asyncio

import pytest

from manual_gpt_server.web.queue import QueueTransport


async def test_queue_stream_basic():
    t = QueueTransport()

    async def producer():
        req = await t.next_request()
        await req["out"].put("a")
        await req["out"].put("b")
        await req["out"].put(None)

    task = asyncio.create_task(producer())
    chunks = []
    async for c in t.stream([{"role": "user", "content": "hi"}]):
        chunks.append(c)
    await task
    assert chunks == ["a", "b"]


async def test_queue_pending_lazy_init():
    t = QueueTransport()
    assert t._pending is None
    _ = t.pending
    assert t._pending is not None
