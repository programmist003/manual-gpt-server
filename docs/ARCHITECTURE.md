# Architecture

## Что это

`manual-gpt-server` — OpenAI-совместимый HTTP-сервер, в котором роль
«модели» играет человек. Клиент (openai-python, langchain, chat-ui)
думает, что говорит с LLM. На самом деле запрос уходит оператору —
в терминал или в веб-админку, — оператор печатает ответ, и он
возвращается клиенту в формате `chat.completion` / SSE-стрима.

Применения: отладка LLM-клиентов без токенов, тесты, демонстрации,
заготовка под «человека в цикле» в пайплайнах.

## Требования (инварианты проекта)

Это требования, сформулированные при проектировании. Любое изменение
в коде должно им соответствовать. Если изменение ломает один из
пунктов — это архитектурная ошибка, а не «мелкая правка».

### R1. `lib` — самостоятельная библиотека, как `.dll`

`lib` — это ядро проекта. Он не знает, кто его использует: CLI,
веб, тесты, или сторонний код. Следствия:

- В `lib` **нет** `print`, `input`, `asyncio.Queue` для UI,
  WebSocket, `FileResponse`, ничего из FastAPI-роутов.
- В `lib` **нет** зависимости от конкретного фронта
  (терминал, веб, telegram, что угодно).
- `lib` можно скопировать в другой проект и импортировать без
  доработок. Он должен остаться работоспособным, даже если
  `cli/`, `rest/`, `web/` удалить целиком.

### R2. `cli` и `rest` — равноправные клиенты `lib`

Ни один из них не «выше» другого. Оба сидят на одном уровне, оба
смотрят вниз, в `lib`. Не существует ситуации, когда `cli`
импортирует `rest` или `rest` импортирует `cli`.

### R3. `web` — над `rest`

`web` — это UI поверх REST-слоя. Он не обращается к `lib` напрямую
через API-модули. Он собирает `rest`-приложение и навешивает сверху
админку и статику.

Исключение — конфиг (`lib.config.Settings`), потому что это
разделяемая настройка всех entry point'ов, а не логика.

### R4. `rest` — и сервер, и клиент

`rest/server.py` + `rest/routes.py` — это HTTP-фасад.
`rest/client.py` — это HTTP-клиент к тому же фасаду. Оба
принадлежат слою `rest` и могут использоваться независимо.

### R5. Строгая слоистость

Зависимости идут только сверху вниз:

    cli    ─┐
            ├──▶ rest ──▶ lib ──▶ stdlib
    web ────┘

Никаких обратных стрелок. `lib` не может импортировать
`rest`/`cli`/`web`. `rest` не может импортировать `cli`/`web`.

### R6. Всё через `.bat`

Любое изменение структуры, рефакторинг, миграция — оформляются
`.bat`-скриптом в `dev-scripts/`. Скрипт идемпотентен, безопасен
(бэкапит перезаписываемое), и его можно перезапустить. Ручные
правки в нескольких файлах — источник ошибок.

### R7. Дампы разделены по назначению

- `dump_tree.bat` — структура + `pyproject.toml` + git. Для «что
  изменилось». Размер — килобайты.
- `dump_full.bat <layer>` — исходники одного слоя. Для «покажи мне
  lib». Размер — единицы килобайт.

Полный дамп всего проекта не нужен: он линейно разрастается и
перестаёт быть читаемым.

### R8. Никаких мёртвых файлов

Если файл никем не импортируется — он удаляется сразу. Если
модуль переехал — старый путь исчезает, а не остаётся «на всякий
случай».

## Структура

    src/manual_gpt_server/
    ├── __init__.py             entry point `manual-gpt-server`
    │
    ├── lib/                    ЯДРО (R1)
    │   ├── __init__.py
    │   ├── config.py           Settings (env)
    │   ├── transport.py        Protocol Transport — контракт
    │   ├── api/
    │   │   ├── low.py          сборка чанков OpenAI-формата
    │   │   └── mid.py          оркестрация SSE-стрима
    │   └── primitives/
    │       ├── clock.py        now_ts()
    │       ├── ids.py          new_completion_id()
    │       └── sse.py          sse_frame(), SSE_DONE
    │
    ├── cli/                    ТЕРМИНАЛЬНЫЙ ФРОНТ (R2)
    │   ├── main.py             entry point `manual-gpt-server`
    │   └── terminal.py         TerminalTransport
    │
    ├── rest/                   HTTP-СЛОЙ (R2, R4)
    │   ├── __init__.py         реэкспорт build_rest_app
    │   ├── server.py           build_rest_app(transport, model_id)
    │   ├── routes.py           /v1/models, /v1/chat/completions
    │   └── client.py           RestClient (httpx)
    │
    └── web/                    ВЕБ-АДМИНКА (R3)
        ├── app.py              entry point `manual-gpt-server-web`
        ├── queue.py            QueueTransport
        └── static/
            ├── admin.html
            └── admin.js

## Слои

### lib — ядро

Отвечает за:

- Контракт транспорта (`Transport.stream`)
- Формат OpenAI (`low`, `mid`)
- Настройки из env
- Утилиты (время, id, SSE-фреймы)

Не отвечает ни за:

- Как приходит запрос (HTTP, CLI, WS)
- Как вводится ответ (терминал, браузер)
- Сеть и I/O любого рода

Ключевой контракт:

    class Transport(Protocol):
        def stream(self, messages: list[dict]) -> AsyncIterator[str]: ...

Любой объект с методом `stream()` может быть транспортом. `lib`
не проверяет, кто это — `TerminalTransport`, `QueueTransport` или
тестовый `FakeTransport`.

### cli — терминальный фронт

Собирает `lib`-ядро с `TerminalTransport`. Отвечает за:

- Чтение ответа оператора через `input()`
- Печать запроса в консоль
- Поднятие HTTP-сервера (`build_rest_app`)

Не отвечает за:

- Формат ответа (это `lib`)
- Ввод-вывод за пределами терминала

### rest — HTTP-слой

Отвечает за:

- HTTP-роуты `/v1/models`, `/v1/chat/completions`
- Сборку FastAPI-приложения из транспорта
- HTTP-клиент к тому же API (`client.py`)

Не отвечает за:

- Источник ответа (это `Transport`)
- UI поверх HTTP

### web — веб-админка

Собирает `rest`-приложение, добавляет:

- `/admin` — WebSocket-канал для оператора
- `/` и `/static` — HTML/JS админки
- `QueueTransport` — транспорт, который ходит через WS

Не отвечает за:

- Логику `/v1/*` (это `rest`)
- Формат ответа (это `lib`)

## Поток данных

Сценарий: клиент обращается к `web`-серверу в режиме stream.

    curl
      │ POST /v1/chat/completions {stream: true}
      ▼
    rest/routes.py::chat          принимает HTTP, валидирует тело
      │ StreamingResponse(mid.stream_completion(...))
      ▼
    lib/api/mid.py::stream_completion
      │ async for piece in source.stream(messages)
      ▼
    web/queue.py::QueueTransport.stream
      │ pending.put({messages, out})
      ▼
    web/app.py::admin             WS-хендлер вытаскивает запрос
      │ ws.send_json({type: "request", ...})
      ▼
    браузер → admin.js → оператор печатает
      │ ws.send_json({type: "delta", content: "..."})
      ▼
    web/app.py::admin
      │ out.put("...")
      ▼
    web/queue.py::QueueTransport.stream
      │ yield "..."
      ▼
    lib/api/mid.py::stream_completion
      │ sse_frame(low.content_chunk(...))
      ▼
    lib/primitives/sse.py
      ▼
    клиент видит SSE-чанки

Каждый слой отдаёт наверх ровно то, что обещал по своему контракту.

## Что запрещено

Эти импорты — ошибка, если появились:

    lib  →  cli, rest, web         (нарушает R1, R5)
    rest →  cli, web               (нарушает R5)
    cli  →  rest                   (нарушает R2)
    web  →  cli                    (нарушает R3)
    lib  →  fastapi, starlette     (нарушает R1)
    lib  →  httpx                  (нарушает R1)

В `lib` допустимы только `stdlib` и типизация. Всё остальное —
уровнем выше.

## Проверка инвариантов

- **R5 (слоистость)** — `.importlinter`-контракт, запуск через
  `uv run lint-imports`. Ломается сборка — значит кто-то нарушил
  границу.
- **R1 (чистота lib)** — grep по `lib/` на `print(`, `input(`,
  `from fastapi`, `from starlette`, `from httpx`. Должно быть пусто.
- **R8 (мёртвый код)** — `vulture` или ручной проход по `dump_tree`.

## История решений

- **v1** — три слоя: `api/`, `lib/`, `server.py` в корне. `cli`
  зависел от `server.py`, `web` тоже. Не было разделения на
  HTTP-фасад и точку входа.
- **v2** — разделили `cli` и `web` как равноправные entry points,
  оба собирают `server.py`. Появились `rest/`, но `lib` всё ещё
  содержал `terminal.py` и `queue.py`.
- **v3 (текущая)** — вариант C: `api/` и `primitives/` переехали
  внутрь `lib`, транспорты переехали к своим потребителям
  (`cli/terminal.py`, `web/queue.py`). `lib` стал чистым ядром.

## Что дальше

Не сделано, но планируется:

- **`.importlinter`** — контракт слоёв, автоматическая проверка R5.
- **Тесты** — `pytest` + `TestClient` + `FakeTransport`, покрытие
  `lib/api`, `rest/routes`.
- **`cli/terminal.py`** — живой стриминг пословно (по Enter), а не
  одним куском.
- **UI админки** — счётчик очереди, история ответов, индикатор
  прогресса стрима.
- **Multi-model** — несколько `model_id`, маршрутизация в `rest`.
- **Auth** — `MANUAL_GPT_API_KEY` проверяется на `/v1/*`.
