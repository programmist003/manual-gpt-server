from manual_gpt_server.lib.api import low
from manual_gpt_server.lib.api.mid import full_completion, stream_completion
from manual_gpt_server.lib.primitives.sse import SSE_DONE, sse_frame


# ---- low ----


def test_low_role_chunk():
    c = low.role_chunk("id1", "m1", 1000)
    assert c["object"] == "chat.completion.chunk"
    assert c["created"] == 1000
    assert c["model"] == "m1"
    assert c["choices"][0]["delta"] == {"role": "assistant"}
    assert c["choices"][0]["finish_reason"] is None


def test_low_content_chunk():
    c = low.content_chunk("id1", "m1", "hi", 1000)
    assert c["created"] == 1000
    assert c["choices"][0]["delta"] == {"content": "hi"}


def test_low_stop_chunk():
    c = low.stop_chunk("id1", "m1", 1000)
    assert c["created"] == 1000
    assert c["choices"][0]["delta"] == {}
    assert c["choices"][0]["finish_reason"] == "stop"


def test_low_dumps_keeps_unicode():
    c = low.content_chunk("i", "m", "privet", 1000)
    assert "privet" in low.dumps(c)


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


async def test_mid_stream_created_is_fixed(fake_transport):
    """Все чанки одного ответа должны иметь одинаковый created."""
    import json

    created_values = []
    async for b in stream_completion(fake_transport, [], "test"):
        if b == SSE_DONE:
            continue
        payload = b.decode().split("data: ", 1)[1].strip()
        created_values.append(json.loads(payload)["created"])
    assert len(set(created_values)) == 1


async def test_mid_full_completion(fake_transport):
    d = await full_completion(fake_transport, [], "test")
    assert d["object"] == "chat.completion"
    assert d["model"] == "test"
    assert d["choices"][0]["message"]["content"] == "hello world"
    assert d["choices"][0]["finish_reason"] == "stop"


# --- legacy completions ---


def test_legacy_text_chunk():
    c = low.legacy_text_chunk("id1", "m1", "hello", 1000)
    assert c["object"] == "text_completion"
    assert c["created"] == 1000
    assert c["choices"][0]["text"] == "hello"
    assert c["choices"][0]["finish_reason"] is None


def test_legacy_stop_chunk():
    c = low.legacy_stop_chunk("id1", "m1", 1000)
    assert c["choices"][0]["text"] == ""
    assert c["choices"][0]["finish_reason"] == "stop"


async def test_legacy_stream_sequence(fake_transport):
    from manual_gpt_server.lib.api.mid import legacy_stream_completion

    out = []
    async for b in legacy_stream_completion(fake_transport, "say hi", "test"):
        out.append(b)
    # role-чанка тут нет — только контент + stop + [DONE]
    assert len(out) == 5  # hello, ' ', world, stop, DONE
    assert b"hello" in out[0]
    assert b"world" in out[2]
    assert b"text_completion" in out[3]
    assert out[4] == SSE_DONE


async def test_legacy_full_completion(fake_transport):
    from manual_gpt_server.lib.api.mid import legacy_full_completion

    d = await legacy_full_completion(fake_transport, "say hi", "test")
    assert d["object"] == "text_completion"
    assert d["choices"][0]["text"] == "hello world"
    assert d["choices"][0]["finish_reason"] == "stop"
