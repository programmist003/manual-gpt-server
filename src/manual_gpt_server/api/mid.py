# api/mid.py
from typing import Protocol, AsyncIterator
from . import low
from ..primitives.sse import sse_frame, SSE_DONE
from ..primitives.ids import new_completion_id


class AnswerSource(Protocol):
    async def ask(self, messages: list[dict]) -> str: ...


def _split_words(text: str) -> list[str]:
    words = text.split(" ")
    return [w if i == 0 else " " + w for i, w in enumerate(words)]


async def stream_completion(source, messages, model) -> AsyncIterator[bytes]:
    cid = new_completion_id()
    answer = await source.ask(messages)
    yield sse_frame(low.dumps(low.role_chunk(cid, model)))
    for piece in _split_words(answer):
        yield sse_frame(low.dumps(low.content_chunk(cid, model, piece)))
    yield sse_frame(low.dumps(low.stop_chunk(cid, model)))
    yield SSE_DONE


async def full_completion(source, messages, model) -> dict:
    cid = new_completion_id()
    answer = await source.ask(messages)
    return {
        "id": cid,
        "object": "chat.completion",
        "created": int(__import__("time").time()),
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
