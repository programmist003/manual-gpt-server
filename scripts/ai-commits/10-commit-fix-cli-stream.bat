@echo off
setlocal
chcp 65001 >nul

REM === Найти корень проекта ===
cd /d "%~dp0"
set "LAST="
:walk
if exist "pyproject.toml" goto :found
if "%CD%"=="%LAST%" (
    echo [X] pyproject.toml не найден.
    pause
    exit /b 1
)
set "LAST=%CD%"
cd ..
goto :walk
:found
echo Корень проекта: %CD%
echo.

set "TARGET=src\manual_gpt_server\cli\terminal.py"
set "BACKUP=%TARGET%.bak"

if not exist "%TARGET%" (
    echo [X] Не найден %TARGET%
    pause
    exit /b 1
)

echo [1/3] Бэкап: %BACKUP%
copy /y "%TARGET%" "%BACKUP%" >nul

echo [2/3] Перезаписываю %TARGET%
>  "%TARGET%" echo from __future__ import annotations
>> "%TARGET%" echo.
>> "%TARGET%" echo import asyncio
>> "%TARGET%" echo import re
>> "%TARGET%" echo from typing import AsyncIterator
>> "%TARGET%" echo.
>> "%TARGET%" echo from starlette.concurrency import run_in_threadpool
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo # Задержка между чанками, сек. Не для синхронизации, а чтобы
>> "%TARGET%" echo # клиент успевал обработать поток и это было похоже на живой ответ.
>> "%TARGET%" echo CHUNK_DELAY = 0.02
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo def _split_words(text: str) -^> list[str]:
>> "%TARGET%" echo     """Режем строку на слова, сохраняя пробелы как отдельные чанки.
>> "%TARGET%" echo.
>> "%TARGET%" echo     'hello world' -^> ['hello', ' ', 'world']
>> "%TARGET%" echo     'a  b'        -^> ['a', ' ', ' ', 'b']
>> "%TARGET%" echo     """
>> "%TARGET%" echo     return [p for p in re.split(r"(\s+)", text) if p]
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo class TerminalTransport:
>> "%TARGET%" echo     """Транспорт, читающий ответ оператора из stdin.
>> "%TARGET%" echo.
>> "%TARGET%" echo     Одна введённая строка = один смысловой блок. Внутри строки
>> "%TARGET%" echo     слова отдаются отдельными чанками с небольшой задержкой —
>> "%TARGET%" echo     клиент SSE видит поток, а не один большой кусок.
>> "%TARGET%" echo.
>> "%TARGET%" echo     Многострочный ответ: печатай строку за строкой, между
>> "%TARGET%" echo     строками клиент получит '\n'. Пустая строка завершает ответ.
>> "%TARGET%" echo     """
>> "%TARGET%" echo.
>> "%TARGET%" echo     async def stream^(self, messages: list[dict]^) -^> AsyncIterator[str]:
>> "%TARGET%" echo         print^("\n=== Запрос ==="^)
>> "%TARGET%" echo         for m in messages:
>> "%TARGET%" echo             print^(f"{m['role']}: {m['content']}"^)
>> "%TARGET%" echo         print^("(пустая строка — конец ответа)"^)
>> "%TARGET%" echo.
>> "%TARGET%" echo         first_chunk = True
>> "%TARGET%" echo         while True:
>> "%TARGET%" echo             line = await run_in_threadpool^(input, "assistant^> "^)
>> "%TARGET%" echo             if not line:
>> "%TARGET%" echo                 return
>> "%TARGET%" echo.
>> "%TARGET%" echo             # Первая строка не нуждается в ведущем '\n'.
>> "%TARGET%" echo             # Каждая следующая строка — начинается с '\n'.
>> "%TARGET%" echo             if not first_chunk:
>> "%TARGET%" echo                 yield "\n"
>> "%TARGET%" echo                 await asyncio.sleep^(CHUNK_DELAY^)
>> "%TARGET%" echo.
>> "%TARGET%" echo             for part in _split_words^(line^):
>> "%TARGET%" echo                 yield part
>> "%TARGET%" echo                 first_chunk = False
>> "%TARGET%" echo                 await asyncio.sleep^(CHUNK_DELAY^)
>> "%TARGET%" echo.
>> "%TARGET%" echo             first_chunk = False

echo [3/3] uv sync
uv sync

echo.
echo ============================================
echo  Готово. Backup: %BACKUP%
echo.
echo  Проверка:
echo    1. Запусти:    uv run manual-gpt-server
echo    2. В другом окне:
echo         curl -N -X POST http://127.0.0.1:8000/v1/chat/completions ^^
echo           -H "Content-Type: application/json" ^^
echo           -d "{\"model\":\"manual\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":true}"
echo    3. В окне сервера печатай ОДНОЙ строкой: "Privet kak dela"
echo       и жми Enter.
echo       curl должен показать пословные чанки, а не один кусок.
echo ============================================
pause