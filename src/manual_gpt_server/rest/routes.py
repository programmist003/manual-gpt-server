from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, StreamingResponse

from manual_gpt_server.lib.api import mid
from manual_gpt_server.lib.transport import Transport

_SSE_HEADERS = {
    "Cache-Control": "no-cache",
    "X-Accel-Buffering": "no",
    "Connection": "keep-alive",
}


def _normalize_prompt(prompt) -> str:
    """OpenAI legacy позволяет строку или список строк."""
    if isinstance(prompt, list):
        return "\n".join(str(p) for p in prompt)
    return str(prompt or "")


def build_router(source: Transport, model_id: str) -> APIRouter:
    router = APIRouter()

    @router.get("/v1/models")
    async def models() -> dict:
        return {
            "object": "list",
            "data": [
                {"id": model_id, "object": "model", "created": 0, "owned_by": "human"}
            ],
        }

    @router.post("/v1/chat/completions")
    async def chat(request: Request):
        body = await request.json()
        messages = body.get("messages", [])
        model = body.get("model", model_id)

        if body.get("stream"):
            return StreamingResponse(
                mid.stream_completion(source, messages, model),
                media_type="text/event-stream",
                headers=_SSE_HEADERS,
            )
        return JSONResponse(await mid.full_completion(source, messages, model))

    @router.post("/v1/completions")
    async def completions(request: Request):
        body = await request.json()
        prompt = _normalize_prompt(body.get("prompt", ""))
        model = body.get("model", model_id)

        if body.get("stream"):
            return StreamingResponse(
                mid.legacy_stream_completion(source, prompt, model),
                media_type="text/event-stream",
                headers=_SSE_HEADERS,
            )
        return JSONResponse(await mid.legacy_full_completion(source, prompt, model))

    return router