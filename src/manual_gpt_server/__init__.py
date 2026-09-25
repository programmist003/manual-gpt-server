# src/manual_gpt_server/__init__.py
from __future__ import annotations

__version__ = "0.1.0"


def main() -> None:
    """Entry point для команды `manual-gpt-server`."""
    from manual_gpt_server.cli.main import main as _main

    _main()
