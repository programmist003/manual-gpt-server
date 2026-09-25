# api/high.py
from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse, JSONResponse
from . import mid

def build_router(source, model_id: str) -> APIRouter:
    router = APIRouter()

    @router.get("/v1/models")
    async def models():
        return {"object": "list",
                "data": [{"id": model_id, "object": "model",
                          "created": 0, "owned_by": "human"}]}

    @router.post("/v1/chat/completions")
    async def chat(request: Request):
        body = await request.json()
        messages = body.get("messages", [])
        model = body.get("model", model_id)
        if body.get("stream"):
            return StreamingResponse(
                mid.stream_completion(source, messages, model),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
            )
        return JSONResponse(await mid.full_completion(source, messages, model))

    return router