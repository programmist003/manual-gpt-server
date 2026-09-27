# lib/terminal.py
from __future__ import annotations

from typing import AsyncIterator

from starlette.concurrency import run_in_threadpool


class TerminalTransport:
    async def stream(self, messages: list[dict]) -> AsyncIterator[str]:
        print("\n=== Запрос ===")
        for m in messages:
            print(f"{m['role']}: {m['content']}")
        print("(пустая строка — конец ответа)")

        first = True
        while True:
            line = await run_in_threadpool(input, "assistant> ")
            if not line:
                return
            yield line if first else "\n" + line
            first = False