import asyncio

from manual_gpt_server.lib.runtime import RuntimeState


async def test_runtime_stream_basic():
    state = RuntimeState()

    async def producer():
        req = await state.next_request()
        await req["out"].put("a")
        await req["out"].put("b")
        await req["out"].put(None)

    task = asyncio.create_task(producer())
    chunks = []
    async for c in state.stream([{"role": "user", "content": "hi"}]):
        chunks.append(c)
    await task
    assert chunks == ["a", "b"]


async def test_runtime_pending_lazy_init():
    state = RuntimeState()
    assert state._pending is None
    _ = state.pending
    assert state._pending is not None


async def test_runtime_status_and_history():
    state = RuntimeState()

    async def producer():
        req = await state.next_request()
        await req["out"].put("hello")
        await req["out"].put(None)

    task = asyncio.create_task(producer())
    async for _ in state.stream([{"role": "user", "content": "hi"}]):
        pass
    await task

    s = state.status()
    assert s["requests_handled"] == 1

    h = state.history()
    assert len(h) == 1
    assert h[0]["answer"] == "hello"