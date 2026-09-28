@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM === Найти корень проекта (walk-up) ===
cd /d "%~dp0"
set "LAST="
:walk
if exist "pyproject.toml" goto :found
if "!CD!"=="!LAST!" (
    echo [X] pyproject.toml не найден ни в "%CD%", ни выше.
    pause
    exit /b 1
)
set "LAST=!CD!"
cd ..
goto :walk
:found
echo Корень проекта: %CD%
echo.

set "SRC=src\manual_gpt_server"

REM === 1. Создать папки ===
if not exist "%SRC%\lib\api"        mkdir "%SRC%\lib\api"
if not exist "%SRC%\lib\primitives" mkdir "%SRC%\lib\primitives"

REM === 2. Переместить файлы ===
echo Перемещаю api/ -> lib/api/ ...
if exist "%SRC%\api\low.py"       move /y "%SRC%\api\low.py"       "%SRC%\lib\api\low.py"       >nul
if exist "%SRC%\api\mid.py"       move /y "%SRC%\api\mid.py"       "%SRC%\lib\api\mid.py"       >nul
if exist "%SRC%\api\__init__.py"  move /y "%SRC%\api\__init__.py"  "%SRC%\lib\api\__init__.py"  >nul

echo Перемещаю primitives/ -> lib/primitives/ ...
if exist "%SRC%\primitives\clock.py"     move /y "%SRC%\primitives\clock.py"     "%SRC%\lib\primitives\clock.py"     >nul
if exist "%SRC%\primitives\ids.py"       move /y "%SRC%\primitives\ids.py"       "%SRC%\lib\primitives\ids.py"       >nul
if exist "%SRC%\primitives\sse.py"       move /y "%SRC%\primitives\sse.py"       "%SRC%\lib\primitives\sse.py"       >nul
if exist "%SRC%\primitives\__init__.py"  move /y "%SRC%\primitives\__init__.py"  "%SRC%\lib\primitives\__init__.py"  >nul

echo Перемещаю транспорты к потребителям ...
if exist "%SRC%\lib\terminal.py"  move /y "%SRC%\lib\terminal.py"  "%SRC%\cli\terminal.py"  >nul
if exist "%SRC%\lib\queue.py"     move /y "%SRC%\lib\queue.py"     "%SRC%\web\queue.py"     >nul

REM === 3. Удалить пустые старые папки ===
if exist "%SRC%\api\__pycache__"        rmdir /s /q "%SRC%\api\__pycache__"        2>nul
if exist "%SRC%\primitives\__pycache__" rmdir /s /q "%SRC%\primitives\__pycache__" 2>nul
if exist "%SRC%\api"                    rmdir "%SRC%\api"        2>nul
if exist "%SRC%\primitives"             rmdir "%SRC%\primitives" 2>nul

REM === 4. Перезаписать изменённые файлы ===

echo Перезаписываю lib\api\mid.py ...
set "T=%SRC%\lib\api\mid.py"
>  "%T%" echo # lib/api/mid.py
>> "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo from typing import AsyncIterator
>> "%T%" echo.
>> "%T%" echo from manual_gpt_server.lib.api import low
>> "%T%" echo from manual_gpt_server.lib.transport import Transport
>> "%T%" echo from manual_gpt_server.lib.primitives.clock import now_ts
>> "%T%" echo from manual_gpt_server.lib.primitives.ids import new_completion_id
>> "%T%" echo from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def stream_completion^(
>> "%T%" echo     source: Transport, messages: list[dict], model: str
>> "%T%" echo ^) -^> AsyncIterator[bytes]:
>> "%T%" echo     cid = new_completion_id^(^)
>> "%T%" echo     yield sse_frame^(low.dumps^(low.role_chunk^(cid, model^)^)^)
>> "%T%" echo     async for piece in source.stream^(messages^):
>> "%T%" echo         yield sse_frame^(low.dumps^(low.content_chunk^(cid, model, piece^)^)^)
>> "%T%" echo     yield sse_frame^(low.dumps^(low.stop_chunk^(cid, model^)^)^)
>> "%T%" echo     yield SSE_DONE
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def full_completion^(source: Transport, messages: list[dict], model: str^) -^> dict:
>> "%T%" echo     cid = new_completion_id^(^)
>> "%T%" echo     parts: list[str] = []
>> "%T%" echo     async for piece in source.stream^(messages^):
>> "%T%" echo         parts.append^(piece^)
>> "%T%" echo     answer = "".join^(parts^)
>> "%T%" echo     return {
>> "%T%" echo         "id": cid,
>> "%T%" echo         "object": "chat.completion",
>> "%T%" echo         "created": now_ts^(^),
>> "%T%" echo         "model": model,
>> "%T%" echo         "choices": [
>> "%T%" echo             {
>> "%T%" echo                 "index": 0,
>> "%T%" echo                 "message": {"role": "assistant", "content": answer},
>> "%T%" echo                 "finish_reason": "stop",
>> "%T%" echo             }
>> "%T%" echo         ],
>> "%T%" echo         "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
>> "%T%" echo     }

echo Перезаписываю cli\main.py ...
set "T=%SRC%\cli\main.py"
>  "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo from fastapi import FastAPI
>> "%T%" echo.
>> "%T%" echo from manual_gpt_server.cli.terminal import TerminalTransport
>> "%T%" echo from manual_gpt_server.lib.config import Settings
>> "%T%" echo from manual_gpt_server.rest.server import build_rest_app
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def make_app^(^) -^> FastAPI:
>> "%T%" echo     settings = Settings^(^)
>> "%T%" echo     return build_rest_app^(TerminalTransport^(^), model_id=settings.model_id^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def main^(^) -^> None:
>> "%T%" echo     import uvicorn
>> "%T%" echo     settings = Settings^(^)
>> "%T%" echo     config = uvicorn.Config^(
>> "%T%" echo         make_app^(^),
>> "%T%" echo         host=settings.host,
>> "%T%" echo         port=settings.port,
>> "%T%" echo         interface="asgi3",
>> "%T%" echo         log_level="info",
>> "%T%" echo     ^)
>> "%T%" echo     uvicorn.Server^(config^).run^(^)

echo Перезаписываю web\app.py ...
set "T=%SRC%\web\app.py"
>  "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo from pathlib import Path
>> "%T%" echo.
>> "%T%" echo import uvicorn
>> "%T%" echo from fastapi import FastAPI, WebSocket, WebSocketDisconnect
>> "%T%" echo from fastapi.responses import FileResponse
>> "%T%" echo from fastapi.staticfiles import StaticFiles
>> "%T%" echo.
>> "%T%" echo from manual_gpt_server.lib.config import Settings
>> "%T%" echo from manual_gpt_server.rest.server import build_rest_app
>> "%T%" echo from manual_gpt_server.web.queue import QueueTransport
>> "%T%" echo.
>> "%T%" echo STATIC_DIR = Path^(__file__^).parent / "static"
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def make_app^(^) -^> FastAPI:
>> "%T%" echo     settings = Settings^(^)
>> "%T%" echo     transport = QueueTransport^(^)
>> "%T%" echo     app = build_rest_app^(transport, model_id=settings.model_id^)
>> "%T%" echo.
>> "%T%" echo     app.mount^("/static", StaticFiles^(directory=str^(STATIC_DIR^)^), name="static"^)
>> "%T%" echo.
>> "%T%" echo     @app.get^("/"^)
>> "%T%" echo     async def index^(^) -^> FileResponse:
>> "%T%" echo         return FileResponse^(STATIC_DIR / "admin.html"^)
>> "%T%" echo.
>> "%T%" echo     @app.websocket^("/admin"^)
>> "%T%" echo     async def admin^(ws: WebSocket^) -^> None:
>> "%T%" echo         await ws.accept^(^)
>> "%T%" echo         current = None
>> "%T%" echo         try:
>> "%T%" echo             while True:
>> "%T%" echo                 req = await transport.next_request^(^)
>> "%T%" echo                 current = req
>> "%T%" echo                 await ws.send_json^({"type": "request", "messages": req["messages"]}^)
>> "%T%" echo                 while True:
>> "%T%" echo                     msg = await ws.receive_json^(^)
>> "%T%" echo                     kind = msg.get^("type"^)
>> "%T%" echo                     if kind == "delta":
>> "%T%" echo                         await req["out"].put^(msg["content"]^)
>> "%T%" echo                     elif kind == "done":
>> "%T%" echo                         await req["out"].put^(None^)
>> "%T%" echo                         current = None
>> "%T%" echo                         break
>> "%T%" echo         except WebSocketDisconnect:
>> "%T%" echo             if current is not None:
>> "%T%" echo                 await current["out"].put^(None^)
>> "%T%" echo             while not transport.pending.empty^(^):
>> "%T%" echo                 pending = transport.pending.get_nowait^(^)
>> "%T%" echo                 await pending["out"].put^(None^)
>> "%T%" echo             return
>> "%T%" echo.
>> "%T%" echo     return app
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def main^(^) -^> None:
>> "%T%" echo     settings = Settings^(^)
>> "%T%" echo     config = uvicorn.Config^(
>> "%T%" echo         make_app^(^),
>> "%T%" echo         host=settings.host,
>> "%T%" echo         port=settings.port,
>> "%T%" echo         interface="asgi3",
>> "%T%" echo         log_level="info",
>> "%T%" echo     ^)
>> "%T%" echo     uvicorn.Server^(config^).run^(^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo if __name__ == "__main__":
>> "%T%" echo     main^(^)

echo Перезаписываю rest\routes.py ...
set "T=%SRC%\rest\routes.py"
>  "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo from fastapi import APIRouter, Request
>> "%T%" echo from fastapi.responses import JSONResponse, StreamingResponse
>> "%T%" echo.
>> "%T%" echo from manual_gpt_server.lib.api import mid
>> "%T%" echo from manual_gpt_server.lib.transport import Transport
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def build_router^(source: Transport, model_id: str^) -^> APIRouter:
>> "%T%" echo     router = APIRouter^(^)
>> "%T%" echo.
>> "%T%" echo     @router.get^("/v1/models"^)
>> "%T%" echo     async def models^(^) -^> dict:
>> "%T%" echo         return {
>> "%T%" echo             "object": "list",
>> "%T%" echo             "data": [
>> "%T%" echo                 {"id": model_id, "object": "model", "created": 0, "owned_by": "human"}
>> "%T%" echo             ],
>> "%T%" echo         }
>> "%T%" echo.
>> "%T%" echo     @router.post^("/v1/chat/completions"^)
>> "%T%" echo     async def chat^(request: Request^):
>> "%T%" echo         body = await request.json^(^)
>> "%T%" echo         messages = body.get^("messages", []^)
>> "%T%" echo         model = body.get^("model", model_id^)
>> "%T%" echo.
>> "%T%" echo         if body.get^("stream"^):
>> "%T%" echo             return StreamingResponse^(
>> "%T%" echo                 mid.stream_completion^(source, messages, model^),
>> "%T%" echo                 media_type="text/event-stream",
>> "%T%" echo                 headers={
>> "%T%" echo                     "Cache-Control": "no-cache",
>> "%T%" echo                     "X-Accel-Buffering": "no",
>> "%T%" echo                     "Connection": "keep-alive",
>> "%T%" echo                 },
>> "%T%" echo             ^)
>> "%T%" echo         return JSONResponse^(await mid.full_completion^(source, messages, model^)^)
>> "%T%" echo.
>> "%T%" echo     return router

REM === 5. uv sync ===
echo.
echo uv sync ...
uv sync

echo.
echo ============================================
echo  Готово.
echo.
echo  Проверка:
echo    dev-scripts\dump_tree.bat     ^(структура^)
echo    uv run manual-gpt-server-web  ^(веб^)
echo    uv run manual-gpt-server      ^(консоль^)
echo ============================================
pause