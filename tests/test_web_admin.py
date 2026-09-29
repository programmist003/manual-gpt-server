from fastapi.testclient import TestClient

from manual_gpt_server.control.app import build_control_app
from manual_gpt_server.lib.runtime import RuntimeState


def test_control_admin_ws_accepts_connection():
    state = RuntimeState()
    app = build_control_app(state)
    with TestClient(app) as c:
        with c.websocket_connect("/admin"):
            pass


def test_control_status():
    state = RuntimeState()
    app = build_control_app(state)
    with TestClient(app) as c:
        r = c.get("/status")
        assert r.status_code == 200
        d = r.json()
        assert "uptime_seconds" in d
        assert "queue_len" in d