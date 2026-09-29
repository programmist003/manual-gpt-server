from __future__ import annotations

from fastapi import APIRouter

from manual_gpt_server.lib.runtime import RuntimeState


def build_router(state: RuntimeState) -> APIRouter:
    router = APIRouter()

    @router.get("/status")
    async def status() -> dict:
        return state.status()

    @router.get("/history")
    async def history() -> list:
        return state.history()

    return router