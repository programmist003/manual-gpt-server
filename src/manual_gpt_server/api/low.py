# api/low.py
import json, time


def _base(cid, model, delta, finish):
    return {
        "id": cid,
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
    }


def role_chunk(cid, model):
    return _base(cid, model, {"role": "assistant"}, None)


def content_chunk(cid, model, text):
    return _base(cid, model, {"content": text}, None)


def stop_chunk(cid, model):
    return _base(cid, model, {}, "stop")


def dumps(chunk) -> str:
    return json.dumps(chunk, ensure_ascii=False)
