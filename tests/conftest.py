import pytest
from fastapi.testclient import TestClient

from manual_gpt_server.rest.server import build_rest_app


class FakeTransport:
    def __init__(self, chunks):
        self.chunks = chunks

    async def stream(self, messages):
        for c in self.chunks:
            yield c


@pytest.fixture
def fake_transport():
    return FakeTransport(["hello", " ", "world"])


@pytest.fixture
def app(fake_transport):
    return build_rest_app(fake_transport, model_id="test")


@pytest.fixture
def client(app):
    with TestClient(app) as c:
        yield c
