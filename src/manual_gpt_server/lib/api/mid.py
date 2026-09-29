# lib/api/mid.py
from __future__ import annotations

from typing import AsyncIterator

from manual_gpt_server.lib.api import low
from manual_gpt_server.lib.primitives.clock import now_ts
from manual_gpt_server.lib.primitives.ids import new_completion_id
from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
from manual_gpt_server.lib.transport import Transport


# --- Chat Completions API (/v1/chat/completions) ---


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


# --- Legacy Completions API (/v1/completions) ---
# Continue в Edit mode и некоторые другие клиенты дёргают этот
# эндпоинт. Формат проще: prompt -> text. Внутри конвертируем
# prompt в одно user-сообщение и отдаём оператору через тот же
# Transport.stream.


async def legacy_stream_completion(
    source: Transport, prompt: str, model: str
) -> AsyncIterator[bytes]:
    cid = new_completion_id()
    created = now_ts()
    messages = [{"role": "user", "content": prompt}]

    async for piece in source.stream(messages):
        yield sse_frame(low.dumps(low.legacy_text_chunk(cid, model, piece, created)))
    yield sse_frame(low.dumps(low.legacy_stop_chunk(cid, model, created)))
    yield SSE_DONE


async def legacy_full_completion(source: Transport, prompt: str, model: str) -> dict:
    cid = new_completion_id()
    created = now_ts()
    messages = [{"role": "user", "content": prompt}]

    parts: list[str] = []
    async for piece in source.stream(messages):
        parts.append(piece)
    answer = "".join(parts)
    return {
        "id": cid,
        "object": "text_completion",
        "created": created,
        "model": model,
        "choices": [
            {"index": 0, "text": answer, "logprobs": None, "finish_reason": "stop"}
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }