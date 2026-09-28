@echo off
setlocal
chcp 65001 >nul

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

REM === 1. low.py ===
set "T=src\manual_gpt_server\lib\api\low.py"
copy /y "%T%" "%T%.bak" >nul
echo [1/4] Перезаписываю %T%

>  "%T%" echo # lib/api/low.py
>> "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo import json
>> "%T%" echo from typing import Optional
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def _base^(cid: str, model: str, created: int, delta: dict, finish: Optional[str]^) -^> dict:
>> "%T%" echo     return {
>> "%T%" echo         "id": cid,
>> "%T%" echo         "object": "chat.completion.chunk",
>> "%T%" echo         "created": created,
>> "%T%" echo         "model": model,
>> "%T%" echo         "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
>> "%T%" echo     }
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def role_chunk^(cid: str, model: str, created: int^) -^> dict:
>> "%T%" echo     return _base^(cid, model, created, {"role": "assistant"}, None^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def content_chunk^(cid: str, model: str, text: str, created: int^) -^> dict:
>> "%T%" echo     return _base^(cid, model, created, {"content": text}, None^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def stop_chunk^(cid: str, model: str, created: int^) -^> dict:
>> "%T%" echo     return _base^(cid, model, created, {}, "stop"^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def dumps^(chunk: dict^) -^> str:
>> "%T%" echo     return json.dumps^(chunk, ensure_ascii=False^)

REM === 2. mid.py ===
set "T=src\manual_gpt_server\lib\api\mid.py"
copy /y "%T%" "%T%.bak" >nul
echo [2/4] Перезаписываю %T%

>  "%T%" echo # lib/api/mid.py
>> "%T%" echo from __future__ import annotations
>> "%T%" echo.
>> "%T%" echo from typing import AsyncIterator
>> "%T%" echo.
>> "%T%" echo from manual_gpt_server.lib.api import low
>> "%T%" echo from manual_gpt_server.lib.primitives.clock import now_ts
>> "%T%" echo from manual_gpt_server.lib.primitives.ids import new_completion_id
>> "%T%" echo from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
>> "%T%" echo from manual_gpt_server.lib.transport import Transport
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def stream_completion^(
>> "%T%" echo     source: Transport, messages: list[dict], model: str
>> "%T%" echo ^) -^> AsyncIterator[bytes]:
>> "%T%" echo     cid = new_completion_id^(^)
>> "%T%" echo     created = now_ts^(^)  # фиксируем один раз на весь ответ
>> "%T%" echo.
>> "%T%" echo     yield sse_frame^(low.dumps^(low.role_chunk^(cid, model, created^)^)^)
>> "%T%" echo     async for piece in source.stream^(messages^):
>> "%T%" echo         yield sse_frame^(low.dumps^(low.content_chunk^(cid, model, piece, created^)^)^)
>> "%T%" echo     yield sse_frame^(low.dumps^(low.stop_chunk^(cid, model, created^)^)^)
>> "%T%" echo     yield SSE_DONE
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def full_completion^(source: Transport, messages: list[dict], model: str^) -^> dict:
>> "%T%" echo     cid = new_completion_id^(^)
>> "%T%" echo     created = now_ts^(^)
>> "%T%" echo     parts: list[str] = []
>> "%T%" echo     async for piece in source.stream^(messages^):
>> "%T%" echo         parts.append^(piece^)
>> "%T%" echo     answer = "".join^(parts^)
>> "%T%" echo     return {
>> "%T%" echo         "id": cid,
>> "%T%" echo         "object": "chat.completion",
>> "%T%" echo         "created": created,
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

REM === 3. tests/test_lib.py ===
set "T=tests\test_lib.py"
copy /y "%T%" "%T%.bak" >nul
echo [3/4] Перезаписываю %T%

>  "%T%" echo from manual_gpt_server.lib.api import low
>> "%T%" echo from manual_gpt_server.lib.api.mid import full_completion, stream_completion
>> "%T%" echo from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo # ---- low ----
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_low_role_chunk^():
>> "%T%" echo     c = low.role_chunk^("id1", "m1", 1000^)
>> "%T%" echo     assert c["object"] == "chat.completion.chunk"
>> "%T%" echo     assert c["created"] == 1000
>> "%T%" echo     assert c["model"] == "m1"
>> "%T%" echo     assert c["choices"][0]["delta"] == {"role": "assistant"}
>> "%T%" echo     assert c["choices"][0]["finish_reason"] is None
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_low_content_chunk^():
>> "%T%" echo     c = low.content_chunk^("id1", "m1", "hi", 1000^)
>> "%T%" echo     assert c["created"] == 1000
>> "%T%" echo     assert c["choices"][0]["delta"] == {"content": "hi"}
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_low_stop_chunk^():
>> "%T%" echo     c = low.stop_chunk^("id1", "m1", 1000^)
>> "%T%" echo     assert c["created"] == 1000
>> "%T%" echo     assert c["choices"][0]["delta"] == {}
>> "%T%" echo     assert c["choices"][0]["finish_reason"] == "stop"
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_low_dumps_keeps_unicode^():
>> "%T%" echo     c = low.content_chunk^("i", "m", "privet", 1000^)
>> "%T%" echo     assert "privet" in low.dumps^(c^)
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo # ---- sse ----
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_sse_simple^():
>> "%T%" echo     assert sse_frame^("hi"^) == b"data: hi\n\n"
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_sse_multiline^():
>> "%T%" echo     assert sse_frame^("a\nb"^) == b"data: a\ndata: b\n\n"
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo def test_sse_done_constant^():
>> "%T%" echo     assert SSE_DONE == b"data: [DONE]\n\n"
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo # ---- mid ----
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def test_mid_stream_sequence^(fake_transport^):
>> "%T%" echo     out = []
>> "%T%" echo     async for b in stream_completion^(fake_transport, [], "test"^):
>> "%T%" echo         out.append^(b^)
>> "%T%" echo     assert len^(out^) == 6
>> "%T%" echo     assert b"assistant" in out[0]
>> "%T%" echo     assert b"hello" in out[1]
>> "%T%" echo     assert b"world" in out[3]
>> "%T%" echo     assert b"stop" in out[4]
>> "%T%" echo     assert out[5] == SSE_DONE
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def test_mid_stream_created_is_fixed^(fake_transport^):
>> "%T%" echo     """Все чанки одного ответа должны иметь одинаковый created."""
>> "%T%" echo     import json
>> "%T%" echo     created_values = []
>> "%T%" echo     async for b in stream_completion^(fake_transport, [], "test"^):
>> "%T%" echo         if b == SSE_DONE:
>> "%T%" echo             continue
>> "%T%" echo         payload = b.decode^(^) .split^("data: ", 1^)[1].strip^(^)
>> "%T%" echo         created_values.append^(json.loads^(payload^)["created"]^)
>> "%T%" echo     assert len^(set^(created_values^)^) == 1
>> "%T%" echo.
>> "%T%" echo.
>> "%T%" echo async def test_mid_full_completion^(fake_transport^):
>> "%T%" echo     d = await full_completion^(fake_transport, [], "test"^)
>> "%T%" echo     assert d["object"] == "chat.completion"
>> "%T%" echo     assert d["model"] == "test"
>> "%T%" echo     assert d["choices"][0]["message"]["content"] == "hello world"
>> "%T%" echo     assert d["choices"][0]["finish_reason"] == "stop"

REM === 4. Прогнать тесты ===
echo [4/4] uv sync + pytest
uv sync >nul
echo.
uv run pytest

echo.
echo ============================================
echo  Готово.
echo  Бэкапы: *.py.bak рядом с оригиналами
echo ============================================
pause