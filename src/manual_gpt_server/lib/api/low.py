# lib/api/low.py
from __future__ import annotations

import json
from typing import Optional


def _base(cid: str, model: str, created: int, delta: dict, finish: Optional[str]) -> dict:
    return {
        "id": cid,
        "object": "chat.completion.chunk",
        "created": created,
        "model": model,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
    }


def role_chunk(cid: str, model: str, created: int) -> dict:
    return _base(cid, model, created, {"role": "assistant"}, None)


def content_chunk(cid: str, model: str, text: str, created: int) -> dict:
    return _base(cid, model, created, {"content": text}, None)


def stop_chunk(cid: str, model: str, created: int) -> dict:
    return _base(cid, model, created, {}, "stop")


# --- legacy Completions API (не chat) ---
# Формат для /v1/completions. Используется Continue в Edit mode и
# другими клиентами, которым нужен "сырой" prompt -> text.


def _legacy_base(cid: str, model: str, created: int, text: str, finish: Optional[str]) -> dict:
    return {
        "id": cid,
        "object": "text_completion",
        "created": created,
        "model": model,
        "choices": [
            {"index": 0, "text": text, "logprobs": None, "finish_reason": finish}
        ],
    }


def legacy_text_chunk(cid: str, model: str, text: str, created: int) -> dict:
    return _legacy_base(cid, model, created, text, None)


def legacy_stop_chunk(cid: str, model: str, created: int) -> dict:
    return _legacy_base(cid, model, created, "", "stop")


def dumps(chunk: dict) -> str:
    return json.dumps(chunk, ensure_ascii=False)