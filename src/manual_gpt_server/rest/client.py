# rest/client.py
from __future__ import annotations

import json
from typing import AsyncIterator

import httpx


class RestClient:
    """OpenAI-совместимый HTTP-клиент к manual-gpt-server."""

    def __init__(self, base_url: str, api_key: str | None = None, timeout: float = 600.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}

    async def models(self) -> dict:
        async with httpx.AsyncClient(timeout=self.timeout) as c:
            r = await c.get(f"{self.base_url}/v1/models", headers=self.headers)
            r.raise_for_status()
            return r.json()

    async def chat(self, messages: list[dict], model: str = "manual") -> dict:
        async with httpx.AsyncClient(timeout=self.timeout) as c:
            r = await c.post(
                f"{self.base_url}/v1/chat/completions",
                json={"model": model, "messages": messages},
                headers=self.headers,
            )
            r.raise_for_status()
            return r.json()

    async def stream(
        self, messages: list[dict], model: str = "manual"
    ) -> AsyncIterator[str]:
        """Отдаёт куски ответа по мере поступления (SSE)."""
        async with httpx.AsyncClient(timeout=self.timeout) as c:
            async with c.stream(
                "POST",
                f"{self.base_url}/v1/chat/completions",
                json={"model": model, "messages": messages, "stream": True},
                headers=self.headers,
            ) as r:
                r.raise_for_status()
                async for line in r.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    payload = line[6:]
                    if payload == "[DONE]":
                        return
                    chunk = json.loads(payload)
                    delta = chunk["choices"][0].get("delta", {})
                    if "content" in delta:
                        yield delta["content"]