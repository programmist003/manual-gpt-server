# lib/transport.py
from typing import Protocol


class Transport(Protocol):
    async def ask(self, messages: list[dict]) -> str: ...
