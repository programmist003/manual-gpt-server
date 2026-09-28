@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

REM === Проверка, что мы в корне проекта ===
if not exist "pyproject.toml" (
    echo [X] pyproject.toml не найден. Запусти из корня проекта.
    pause
    exit /b 1
)
if not exist "src\manual_gpt_server\web\app.py" (
    echo [X] src\manual_gpt_server\web\app.py не найден.
    pause
    exit /b 1
)

set "TARGET=src\manual_gpt_server\web\app.py"
set "BACKUP=src\manual_gpt_server\web\app.py.bak"

REM === Бэкап ===
echo [1/3] Бэкап: %BACKUP%
copy /y "%TARGET%" "%BACKUP%" >nul

REM === Запись нового app.py ===
echo [2/3] Перезаписываю %TARGET%

>  "%TARGET%" echo from __future__ import annotations
>> "%TARGET%" echo.
>> "%TARGET%" echo from pathlib import Path
>> "%TARGET%" echo.
>> "%TARGET%" echo import uvicorn
>> "%TARGET%" echo from fastapi import FastAPI, WebSocket, WebSocketDisconnect
>> "%TARGET%" echo from fastapi.responses import FileResponse
>> "%TARGET%" echo from fastapi.staticfiles import StaticFiles
>> "%TARGET%" echo.
>> "%TARGET%" echo from manual_gpt_server.lib.config import Settings
>> "%TARGET%" echo from manual_gpt_server.lib.queue import QueueTransport
>> "%TARGET%" echo from manual_gpt_server.rest.server import build_rest_app
>> "%TARGET%" echo.
>> "%TARGET%" echo STATIC_DIR = Path^(__file__^).parent / "static"
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo def make_app^(^) -^> FastAPI:
>> "%TARGET%" echo     settings = Settings^(^)
>> "%TARGET%" echo     transport = QueueTransport^(^)
>> "%TARGET%" echo     app = build_rest_app^(transport, model_id=settings.model_id^)
>> "%TARGET%" echo.
>> "%TARGET%" echo     app.mount^("/static", StaticFiles^(directory=str^(STATIC_DIR^)^), name="static"^)
>> "%TARGET%" echo.
>> "%TARGET%" echo     @app.get^("/"^)
>> "%TARGET%" echo     async def index^(^) -^> FileResponse:
>> "%TARGET%" echo         return FileResponse^(STATIC_DIR / "admin.html"^)
>> "%TARGET%" echo.
>> "%TARGET%" echo     @app.websocket^("/admin"^)
>> "%TARGET%" echo     async def admin^(ws: WebSocket^) -^> None:
>> "%TARGET%" echo         await ws.accept^(^)
>> "%TARGET%" echo         current = None
>> "%TARGET%" echo         try:
>> "%TARGET%" echo             while True:
>> "%TARGET%" echo                 req = await transport.next_request^(^)
>> "%TARGET%" echo                 current = req
>> "%TARGET%" echo                 await ws.send_json^({"type": "request", "messages": req["messages"]}^)
>> "%TARGET%" echo                 while True:
>> "%TARGET%" echo                     msg = await ws.receive_json^(^)
>> "%TARGET%" echo                     kind = msg.get^("type"^)
>> "%TARGET%" echo                     if kind == "delta":
>> "%TARGET%" echo                         await req["out"].put^(msg["content"]^)
>> "%TARGET%" echo                     elif kind == "done":
>> "%TARGET%" echo                         await req["out"].put^(None^)
>> "%TARGET%" echo                         current = None
>> "%TARGET%" echo                         break
>> "%TARGET%" echo         except WebSocketDisconnect:
>> "%TARGET%" echo             if current is not None:
>> "%TARGET%" echo                 await current["out"].put^(None^)
>> "%TARGET%" echo             while not transport.pending.empty^(^):
>> "%TARGET%" echo                 pending = transport.pending.get_nowait^(^)
>> "%TARGET%" echo                 await pending["out"].put^(None^)
>> "%TARGET%" echo             return
>> "%TARGET%" echo.
>> "%TARGET%" echo     return app
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo def main^(^) -^> None:
>> "%TARGET%" echo     settings = Settings^(^)
>> "%TARGET%" echo     app = make_app^(^)
>> "%TARGET%" echo     print^("[DEBUG] make_app returned:", type^(app^).__name__, flush=True^)
>> "%TARGET%" echo     if app is None:
>> "%TARGET%" echo         raise RuntimeError^("make_app returned None"^)
>> "%TARGET%" echo     config = uvicorn.Config^(app, host=settings.host, port=settings.port, interface="asgi3", log_level="info"^)
>> "%TARGET%" echo     uvicorn.Server^(config^).run^(^)
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo if __name__ == "__main__":
>> "%TARGET%" echo     main^(^)

echo [3/3] uv sync
uv sync

echo.
echo ============================================
echo  Готово.
echo  Backup: %BACKUP%
echo  Запускай: uv run manual-gpt-server-web
echo ============================================
pause