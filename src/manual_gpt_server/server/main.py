from __future__ import annotations

import asyncio

import uvicorn

from manual_gpt_server.control.app import build_control_app
from manual_gpt_server.lib.config import Settings
from manual_gpt_server.lib.runtime import RuntimeState
from manual_gpt_server.rest.server import build_rest_app


async def _serve_both(
    api_config: uvicorn.Config, control_config: uvicorn.Config
) -> None:
    api_server = uvicorn.Server(api_config)
    control_server = uvicorn.Server(control_config)
    await asyncio.gather(api_server.serve(), control_server.serve())


def main() -> None:
    settings = Settings()
    state = RuntimeState()

    api_app = build_rest_app(state, model_id=settings.model_id)
    control_app = build_control_app(state)

    api_config = uvicorn.Config(
        api_app,
        host=settings.host,
        port=settings.port,
        interface="asgi3",
        log_level="info",
    )

    # Control: жёстко loopback, никогда не открывается наружу
    control_config = uvicorn.Config(
        control_app,
        host="127.0.0.1",
        port=settings.control_port,
        interface="asgi3",
        log_level="info",
    )

    asyncio.run(_serve_both(api_config, control_config))


if __name__ == "__main__":
    main()