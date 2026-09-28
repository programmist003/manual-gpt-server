from manual_gpt_server.lib.api import low
from manual_gpt_server.lib.api.mid import full_completion, stream_completion
from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame


# ---- low ----


def test_low_role_chunk():
    c = low.role_chunk("id1", "m1")
    assert c["object"] == "chat.completion.chunk"
    assert c["model"] == "m1"
    assert c["choices"][0]["delta"] == {"role": "assistant"}
    assert c["choices"][0]["finish_reason"] is None


def test_low_content_chunk():
    c = low.content_chunk("id1", "m1", "hi")
    assert c["choices"][0]["delta"] == {"content": "hi"}


def test_low_stop_chunk():
    c = low.stop_chunk("id1", "m1")
    assert c["choices"][0]["delta"] == {}
    assert c["choices"][0]["finish_reason"] == "stop"


def test_low_dumps_keeps_unicode():
    c = low.content_chunk("i", "m", "privet")
    s = low.dumps(c)
    assert "privet" in s


# ---- sse ----


def test_sse_simple():
    assert sse_frame("hi") == b"data: hi\n\n"


def test_sse_multiline():
    assert sse_frame("a\nb") == b"data: a\ndata: b\n\n"


def test_sse_done_constant():
    assert SSE_DONE == b"data: [DONE]\n\n"


# ---- mid ----


async def test_mid_stream_sequence(fake_transport):
    out = []
    async for b in stream_completion(fake_transport, [], "test"):
        out.append(b)
    assert len(out) == 6
    assert b"assistant" in out[0]
    assert b"hello" in out[1]
    assert b"world" in out[3]
    assert b"stop" in out[4]
    assert out[5] == SSE_DONE


async def test_mid_full_completion(fake_transport):
    d = await full_completion(fake_transport, [], "test")
    assert d["object"] == "chat.completion"
    assert d["model"] == "test"
    assert d["choices"][0]["message"]["content"] == "hello world"
    assert d["choices"][0]["finish_reason"] == "stop"
