import pytest


def test_admin_ws_accepts_connection(monkeypatch):
    from manual_gpt_server.web import app as web_app
    from fastapi.testclient import TestClient

    application = web_app.make_app()
    with TestClient(application) as c:
        with c.websocket_connect("/admin"):
            pass
