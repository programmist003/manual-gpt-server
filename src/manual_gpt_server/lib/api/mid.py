# lib/api/mid.py
from __future__ import annotations

from typing import AsyncIterator

from manual_gpt_server.lib.api import low
from manual_gpt_server.lib.primitives.clock import now_ts
from manual_gpt_server.lib.primitives.ids import new_completion_id
from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
from manual_gpt_server.lib.transport import Transport


async def stream_completion(
    source: Transport, messages: list[dict], model: str
) -> AsyncIterator[bytes]:
    cid = new_completion_id()
    created = now_ts()  # фиксируем один раз на весь ответ

    yield sse_frame(low.dumps(low.role_chunk(cid, model, created)))
    async for piece in source.stream(messages):
        yield sse_frame(low.dumps(low.content_chunk(cid, model, piece, created)))
    yield sse_frame(low.dumps(low.stop_chunk(cid, model, created)))
    yield SSE_DONE


async def full_completion(source: Transport, messages: list[dict], model: str) -> dict:
    cid = new_completion_id()
    created = now_ts()
    parts: list[str] = []
    async for piece in source.stream(messages):
        parts.append(piece)
    answer = "".join(parts)
    return {
        "id": cid,
        "object": "chat.completion",
        "created": created,
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": answer},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }
