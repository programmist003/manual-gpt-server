# lib/transport.py
from __future__ import annotations

from typing import AsyncIterator, Protocol


class Transport(Protocol):
    """Источник ответа «ассистента». Может быть терминал, веб-админка, что угодно."""

    def stream(self, messages: list[dict]) -> AsyncIterator[str]:
        """Отдаёт куски ответа по мере готовности."""
        ...