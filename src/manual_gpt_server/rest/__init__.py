# rest/__init__.py
from __future__ import annotations

from manual_gpt_server.rest.server import build_rest_app

__all__ = ["build_rest_app"]