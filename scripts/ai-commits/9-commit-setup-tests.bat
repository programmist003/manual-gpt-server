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

REM === 1. Dev-зависимости ===
echo [1/4] Добавляю pytest, pytest-asyncio, httpx ...
uv add --dev pytest pytest-asyncio httpx
if errorlevel 1 (
    echo [X] uv add не сработал.
    pause
    exit /b 1
)

REM === 2. Папка tests ===
echo [2/4] Создаю tests\ ...
if not exist "tests" mkdir "tests"

REM === 3. Пишу тестовые файлы ===

echo [3/4] Пишу tests\conftest.py ...
set "T=tests\conftest.py"
> "%T%"  echo import pytest
>>"%T%"  echo from fastapi.testclient import TestClient
>>"%T%"  echo.
>>"%T%"  echo from manual_gpt_server.rest.server import build_rest_app
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo class FakeTransport:
>>"%T%"  echo     def __init__(self, chunks):
>>"%T%"  echo         self.chunks = chunks
>>"%T%"  echo.
>>"%T%"  echo     async def stream(self, messages):
>>"%T%"  echo         for c in self.chunks:
>>"%T%"  echo             yield c
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo @pytest.fixture
>>"%T%"  echo def fake_transport():
>>"%T%"  echo     return FakeTransport(["hello", " ", "world"])
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo @pytest.fixture
>>"%T%"  echo def app(fake_transport):
>>"%T%"  echo     return build_rest_app(fake_transport, model_id="test")
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo @pytest.fixture
>>"%T%"  echo def client(app):
>>"%T%"  echo     with TestClient(app) as c:
>>"%T%"  echo         yield c

echo Пишу tests\test_lib.py ...
set "T=tests\test_lib.py"
> "%T%"  echo from manual_gpt_server.lib.api import low
>>"%T%"  echo from manual_gpt_server.lib.api.mid import full_completion, stream_completion
>>"%T%"  echo from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo # ---- low ----
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_low_role_chunk():
>>"%T%"  echo     c = low.role_chunk("id1", "m1")
>>"%T%"  echo     assert c["object"] == "chat.completion.chunk"
>>"%T%"  echo     assert c["model"] == "m1"
>>"%T%"  echo     assert c["choices"][0]["delta"] == {"role": "assistant"}
>>"%T%"  echo     assert c["choices"][0]["finish_reason"] is None
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_low_content_chunk():
>>"%T%"  echo     c = low.content_chunk("id1", "m1", "hi")
>>"%T%"  echo     assert c["choices"][0]["delta"] == {"content": "hi"}
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_low_stop_chunk():
>>"%T%"  echo     c = low.stop_chunk("id1", "m1")
>>"%T%"  echo     assert c["choices"][0]["delta"] == {}
>>"%T%"  echo     assert c["choices"][0]["finish_reason"] == "stop"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_low_dumps_keeps_unicode():
>>"%T%"  echo     c = low.content_chunk("i", "m", "privet")
>>"%T%"  echo     s = low.dumps(c)
>>"%T%"  echo     assert "privet" in s
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo # ---- sse ----
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_sse_simple():
>>"%T%"  echo     assert sse_frame("hi") == b"data: hi\n\n"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_sse_multiline():
>>"%T%"  echo     assert sse_frame("a\nb") == b"data: a\ndata: b\n\n"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_sse_done_constant():
>>"%T%"  echo     assert SSE_DONE == b"data: [DONE]\n\n"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo # ---- mid ----
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo async def test_mid_stream_sequence(fake_transport):
>>"%T%"  echo     out = []
>>"%T%"  echo     async for b in stream_completion(fake_transport, [], "test"):
>>"%T%"  echo         out.append(b)
>>"%T%"  echo     assert len(out) == 6
>>"%T%"  echo     assert b"assistant" in out[0]
>>"%T%"  echo     assert b"hello" in out[1]
>>"%T%"  echo     assert b"world" in out[3]
>>"%T%"  echo     assert b"stop" in out[4]
>>"%T%"  echo     assert out[5] == SSE_DONE
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo async def test_mid_full_completion(fake_transport):
>>"%T%"  echo     d = await full_completion(fake_transport, [], "test")
>>"%T%"  echo     assert d["object"] == "chat.completion"
>>"%T%"  echo     assert d["model"] == "test"
>>"%T%"  echo     assert d["choices"][0]["message"]["content"] == "hello world"
>>"%T%"  echo     assert d["choices"][0]["finish_reason"] == "stop"

echo Пишу tests\test_rest.py ...
set "T=tests\test_rest.py"
> "%T%"  echo # ---- rest: HTTP контракт ----
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_models(client):
>>"%T%"  echo     r = client.get("/v1/models")
>>"%T%"  echo     assert r.status_code == 200
>>"%T%"  echo     data = r.json()
>>"%T%"  echo     assert data["object"] == "list"
>>"%T%"  echo     assert data["data"][0]["id"] == "test"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_chat_full(client):
>>"%T%"  echo     r = client.post("/v1/chat/completions", json={
>>"%T%"  echo         "model": "test",
>>"%T%"  echo         "messages": [{"role": "user", "content": "hi"}],
>>"%T%"  echo     })
>>"%T%"  echo     assert r.status_code == 200
>>"%T%"  echo     d = r.json()
>>"%T%"  echo     assert d["choices"][0]["message"]["content"] == "hello world"
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_chat_stream(client):
>>"%T%"  echo     r = client.post("/v1/chat/completions", json={
>>"%T%"  echo         "model": "test",
>>"%T%"  echo         "messages": [{"role": "user", "content": "hi"}],
>>"%T%"  echo         "stream": True,
>>"%T%"  echo     })
>>"%T%"  echo     assert r.status_code == 200
>>"%T%"  echo     assert "text/event-stream" in r.headers["content-type"]
>>"%T%"  echo     text = r.text
>>"%T%"  echo     assert "data: [DONE]" in text
>>"%T%"  echo     assert "hello" in text

echo Пишу tests\test_queue.py ...
set "T=tests\test_queue.py"
> "%T%"  echo import asyncio
>>"%T%"  echo.
>>"%T%"  echo import pytest
>>"%T%"  echo.
>>"%T%"  echo from manual_gpt_server.web.queue import QueueTransport
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo async def test_queue_stream_basic():
>>"%T%"  echo     t = QueueTransport()
>>"%T%"  echo.
>>"%T%"  echo     async def producer():
>>"%T%"  echo         req = await t.next_request()
>>"%T%"  echo         await req["out"].put("a")
>>"%T%"  echo         await req["out"].put("b")
>>"%T%"  echo         await req["out"].put(None)
>>"%T%"  echo.
>>"%T%"  echo     task = asyncio.create_task(producer())
>>"%T%"  echo     chunks = []
>>"%T%"  echo     async for c in t.stream([{"role": "user", "content": "hi"}]):
>>"%T%"  echo         chunks.append(c)
>>"%T%"  echo     await task
>>"%T%"  echo     assert chunks == ["a", "b"]
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo async def test_queue_pending_lazy_init():
>>"%T%"  echo     t = QueueTransport()
>>"%T%"  echo     assert t._pending is None
>>"%T%"  echo     _ = t.pending
>>"%T%"  echo     assert t._pending is not None

echo Пишу tests\test_web_admin.py ...
set "T=tests\test_web_admin.py"
> "%T%"  echo import pytest
>>"%T%"  echo.
>>"%T%"  echo.
>>"%T%"  echo def test_admin_ws_accepts_connection(monkeypatch):
>>"%T%"  echo     from manual_gpt_server.web import app as web_app
>>"%T%"  echo     from fastapi.testclient import TestClient
>>"%T%"  echo.
>>"%T%"  echo     application = web_app.make_app()
>>"%T%"  echo     with TestClient(application) as c:
>>"%T%"  echo         with c.websocket_connect("/admin"):
>>"%T%"  echo             pass

REM === 4. pytest.ini ===
echo [4/4] Пишу pytest.ini ...
set "T=pytest.ini"
> "%T%"  echo [pytest]
>>"%T%"  echo asyncio_mode = auto
>>"%T%"  echo testpaths = tests
>>"%T%"  echo addopts = -v

REM === Запуск ===
echo.
echo ============================================
echo  Запускаю тесты...
echo ============================================
echo.
uv run pytest

echo.
echo ============================================
echo  Готово. Повторный запуск: uv run pytest
echo ============================================
pause