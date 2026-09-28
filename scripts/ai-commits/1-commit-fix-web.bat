@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "TARGET=src\manual_gpt_server\web\app.py"
set "BACKUP=%TARGET%.bak"

if not exist "%TARGET%" (
    echo Не найден %TARGET% — запусти из корня проекта.
    pause
    exit /b 1
)

if not exist "%BACKUP%" (
    echo [1/3] Бэкап: %BACKUP%
    copy /y "%TARGET%" "%BACKUP%" >nul
) else (
    echo [1/3] Бэкап уже есть — оставляю %BACKUP%
)

echo [2/3] Пишу исправленный %TARGET% ...
> "%TARGET%" echo from __future__ import annotations
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
>> "%TARGET%" echo         current: dict ^| None = None
>> "%TARGET%" echo         try:
>> "%TARGET%" echo             while True:
>> "%TARGET%" echo                 req = await transport.next_request^(^)
>> "%TARGET%" echo                 current = req
>> "%TARGET%" echo                 await ws.send_json^({"type": "request", "messages": req["messages"]}^)
>> "%TARGET%" echo.
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
>> "%TARGET%" echo.
>> "%TARGET%" echo def main^(^) -^> None:
>> "%TARGET%" echo     settings = Settings^(^)
>> "%TARGET%" echo     config = uvicorn.Config^(
>> "%TARGET%" echo         make_app^(^),
>> "%TARGET%" echo         host=settings.host,
>> "%TARGET%" echo         port=settings.port,
>> "%TARGET%" echo         interface="asgi3",
>> "%TARGET%" echo     ^)
>> "%TARGET%" echo     uvicorn.Server^(config^).run^(^)
>> "%TARGET%" echo.
>> "%TARGET%" echo.
>> "%TARGET%" echo if __name__ == "__main__":
>> "%TARGET%" echo     main^(^)

echo [3/3] Обновляю venv...
uv sync

echo.
echo Готово. Бэкап: %BACKUP%
echo Запускай:
echo     uv run manual-gpt-server-web
echo и открывай http://127.0.0.1:8000/
pause