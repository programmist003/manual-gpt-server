# lib/config.py
from __future__ import annotations

import os
from typing import Optional


class Settings:
    def __init__(self) -> None:
        self.host: str = os.environ.get("MANUAL_GPT_HOST", "127.0.0.1")
        self.port: int = int(os.environ.get("MANUAL_GPT_PORT", "8000"))
        self.model_id: str = os.environ.get("MANUAL_GPT_MODEL_ID", "manual")
        self.api_key: Optional[str] = os.environ.get("MANUAL_GPT_API_KEY")
