# primitives/sse.py
def sse_frame(payload: str) -> bytes:
    return f"data: {payload}\n\n".encode("utf-8")

SSE_DONE = sse_frame("[DONE]")