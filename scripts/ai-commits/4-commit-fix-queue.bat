@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

if not exist "pyproject.toml" (
    echo [X] Запусти из корня проекта ^(нужен pyproject.toml^).
    pause
    exit /b 1
)
if not exist "src\manual_gpt_server\lib\queue.py" (
    echo [X] Не найден src\manual_gpt_server\lib\queue.py
    pause
    exit /b 1
)

set "TARGET=src\manual_gpt_server\lib\queue.py"
set "BACKUP=%TARGET%.bak"

echo [1/3] Бэкап: %BACKUP%
copy /y "%TARGET%" "%BACKUP%" >nul

echo [2/3] Перезаписываю %TARGET%
>  "%TARGET%" echo from __future__ import annotations
>> "%TARGET%" echo.
>> "%TARGET%" echo import asyncio
>> "%TARGET%" echo from typing import Any, AsyncIterator
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo class QueueTransport:
>> "%TARGET%" echo     """Веб-транспорт: запрос уходит админке через очередь, ответ приходит чанками."""
>> "%TARGET%" echo.
>> "%TARGET%" echo     def __init__(self) -^> None:
>> "%TARGET%" echo         self._pending: asyncio.Queue[dict[str, Any]] ^| None = None
>> "%TARGET%" echo.
>> "%TARGET%" echo     @property
>> "%TARGET%" echo     def pending(self) -^> asyncio.Queue[dict[str, Any]]:
>> "%TARGET%" echo         # Ленивая инициализация: очередь должна создаваться
>> "%TARGET%" echo         # внутри работающего event loop, иначе её future'ы
>> "%TARGET%" echo         # привяжутся к чужому циклу ^(RuntimeError: different loop^).
>> "%TARGET%" echo         if self._pending is None:
>> "%TARGET%" echo             self._pending = asyncio.Queue^(^)
>> "%TARGET%" echo         return self._pending
>> "%TARGET%" echo.
>> "%TARGET%" echo     async def stream^(self, messages: list[dict]^) -^> AsyncIterator[str]:
>> "%TARGET%" echo         out: asyncio.Queue[str ^| None] = asyncio.Queue^(^)
>> "%TARGET%" echo         await self.pending.put^({"messages": messages, "out": out}^)
>> "%TARGET%" echo         while True:
>> "%TARGET%" echo             chunk = await out.get^(^)
>> "%TARGET%" echo             if chunk is None:
>> "%TARGET%" echo                 return
>> "%TARGET%" echo             yield chunk
>> "%TARGET%" echo.
>> "%TARGET%" echo     async def next_request^(self^) -^> dict[str, Any]:
>> "%TARGET%" echo         return await self.pending.get^(^)

echo [3/3] uv sync
uv sync

echo.
echo ============================================
echo  Готово. Backup: %BACKUP%
echo  Запускай: uv run manual-gpt-server-web
echo ============================================
pause