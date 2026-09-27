# primitives/sse.py
from __future__ import annotations


def sse_frame(payload: str) -> bytes:
    """Сформировать SSE-фрейм.

    Если в payload есть переводы строк, каждый превращается в отдельную
    строку `data: ...` — так требует спецификация SSE, иначе вторая и
    последующие строки будут молча потеряны клиентом.
    """
    lines = payload.split("\n")
    body = "".join(f"data: {line}\n" for line in lines)
    return (body + "\n").encode("utf-8")


SSE_DONE = sse_frame("[DONE]")