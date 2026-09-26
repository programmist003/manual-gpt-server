# lib/terminal.py
from starlette.concurrency import run_in_threadpool


class TerminalTransport:
    async def ask(self, messages: list[dict]) -> str:
        print("\n=== Запрос ===")
        for m in messages:
            print(f"{m['role']}: {m['content']}")
        return await run_in_threadpool(input, "assistant> ")
