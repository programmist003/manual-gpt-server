from __future__ import annotations

import asyncio
import re
from typing import AsyncIterator

from starlette.concurrency import run_in_threadpool


# Задержка между чанками, сек. Не для синхронизации, а чтобы
# клиент успевал обработать поток и это было похоже на живой ответ.
CHUNK_DELAY = 0.02


def _split_words(text: str) -> list[str]:
    """Режем строку на слова, сохраняя пробелы как отдельные чанки.

    'hello world' -> ['hello', ' ', 'world']
    'a  b'        -> ['a', ' ', ' ', 'b']
    """
    return [p for p in re.split(r"(\s+)", text) if p]


class TerminalTransport:
    """Транспорт, читающий ответ оператора из stdin.

    Одна введённая строка = один смысловой блок. Внутри строки
    слова отдаются отдельными чанками с небольшой задержкой —
    клиент SSE видит поток, а не один большой кусок.

    Многострочный ответ: печатай строку за строкой, между
    строками клиент получит '\n'. Пустая строка завершает ответ.
    """

    async def stream(self, messages: list[dict]) -> AsyncIterator[str]:
        print("\n=== Запрос ===")
        for m in messages:
            print(f"{m['role']}: {m['content']}")
        print("(пустая строка — конец ответа)")

        first_chunk = True
        while True:
            line = await run_in_threadpool(input, "assistant^> ")
            if not line:
                return

            # Первая строка не нуждается в ведущем '\n'.
            # Каждая следующая строка — начинается с '\n'.
            if not first_chunk:
                yield "\n"
                await asyncio.sleep(CHUNK_DELAY)

            for part in _split_words(line):
                yield part
                first_chunk = False
                await asyncio.sleep(CHUNK_DELAY)

            first_chunk = False
