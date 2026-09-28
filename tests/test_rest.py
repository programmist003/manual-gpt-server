# ---- rest: HTTP контракт ----


def test_models(client):
    r = client.get("/v1/models")
    assert r.status_code == 200
    data = r.json()
    assert data["object"] == "list"
    assert data["data"][0]["id"] == "test"


def test_chat_full(client):
    r = client.post("/v1/chat/completions", json={
        "model": "test",
        "messages": [{"role": "user", "content": "hi"}],
    })
    assert r.status_code == 200
    d = r.json()
    assert d["choices"][0]["message"]["content"] == "hello world"


def test_chat_stream(client):
    r = client.post("/v1/chat/completions", json={
        "model": "test",
        "messages": [{"role": "user", "content": "hi"}],
        "stream": True,
    })
    assert r.status_code == 200
    assert "text/event-stream" in r.headers["content-type"]
    text = r.text
    assert "data: [DONE]" in text
    assert "hello" in text
