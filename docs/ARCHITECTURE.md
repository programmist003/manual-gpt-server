# Architecture

## Что это

`manual-gpt-server` — OpenAI-совместимый HTTP-сервер, в котором роль
«модели» играет человек. Клиент (openai-python, langchain, chat-ui,
Continue) думает, что говорит с LLM. На самом деле запрос уходит
оператору — в терминал или в веб-админку, — оператор печатает ответ,
и он возвращается клиенту в формате `chat.completion` / SSE-стрима.

Применения: отладка LLM-клиентов без токенов, тесты, демонстрации,
заготовка под «человека в цикле» в пайплайнах.

## Требования (инварианты проекта)

Это требования, сформулированные при проектировании. Любое изменение
в коде должно им соответствовать. Если изменение ломает один из
пунктов — это архитектурная ошибка, а не «мелкая правка».

### R1. `lib` — самостоятельная библиотека, как `.dll`

`lib` — это ядро проекта. Он не знает, кто его использует: CLI,
веб, тесты или сторонний код. Следствия:

- В `lib` **нет** `print`, `input`, UI-очередей на внешние каналы,
  WebSocket, ничего из FastAPI-роутов.
- В `lib` **нет** зависимости от конкретного фронта
  (терминал, веб, telegram, что угодно).
- `lib` можно скопировать в другой проект и импортировать без
  доработок. Он должен остаться работоспособным, даже если
  `cli/`, `rest/`, `control/`, `server/` удалить целиком.

Исключение — `lib/runtime.py` (`RuntimeState`). Он использует
`asyncio.Queue` как in-memory очередь и остаётся framework-free:
никаких `fastapi`, `starlette`, `websockets`. Это чистый
`asyncio` + `time` + `uuid`.

### R2. `cli` и `control` — равноправные потребители `rest`

Ни один из них не «выше» другого. Оба сидят на одном уровне, оба
собирают `build_rest_app` из `rest/server.py`. Не существует
ситуации, когда `cli` импортирует `control` или наоборот.

### R3. `control` — над `rest`

`control` — это UI поверх REST-слоя. Он не обращается к внутренностям
`lib` (`lib.api`, `lib.primitives`, `lib.transport`) напрямую. Он
собирает `rest`-приложение и навешивает сверху WebSocket и статику.

Исключения:

- `lib.config.Settings` — разделяемая настройка entry point'ов.
- `lib.runtime.RuntimeState` — общий стейт процесса; используется
  и как `Transport` для `rest`, и как источник данных для control
  REST-ручек (`/status`, `/history`). Это не «внутренность ядра»,
  а сервис уровня приложения.

### R4. `rest` — и сервер, и клиент

`rest/server.py` + `rest/routes.py` — это HTTP-фасад.
`rest/client.py` — это HTTP-клиент к тому же фасаду. Оба
принадлежат слою `rest` и могут использоваться независимо.

### R5. Строгая слоистость

Зависимости идут только сверху вниз:

```
server
  │
cli │ control
  │
rest
  │
lib
  │
stdlib
```

`server` — композиционный корень верхнего уровня: собирает и
запускает `cli`/`control`/`rest`. Никаких обратных стрелок. `lib`
не может импортировать `rest`/`cli`/`control`/`server`. `rest` не
может импортировать `cli`/`control`/`server`.

Проверяется автоматически контрактом `.importlinter`
(см. «Проверка инвариантов»).

### R6. Служебные скрипты — на Python в `scripts/`

Любая автоматизация (дампы, миграции, подготовка окружения)
живёт в `scripts/` и пишется на Python. Никаких `.bat`, `.sh`,
`.ps1` — только `.py`, запускаемые через `uv run`.

Причины:

- Один язык для кода проекта и для инструментов.
- Кроссплатформенность без правок.
- Читаемость: нет `^`, `>>`, `!VAR!`, `%~dp0`.
- Тестируемость: модули `scripts/` можно импортировать в pytest.

Bootstrap решается сам собой: `uv run scripts/foo.py` собирает venv,
если его нет, и потом выполняет скрипт.

### R7. Дампы разделены по назначению

- `scripts/dump_tree.py` — структура с размерами файлов + все
  конфиги проекта целиком + git status. Для «что изменилось».
- `scripts/dump_full.py [path...]` — исходники по списку путей
  (файлы и папки вперемешку). Без аргументов — разумный набор
  по умолчанию (`src`, `tests`, `scripts`, `docs`, конфиги).

Оба пишут в `scripts/`, не в корень проекта. Оба игнорируют
`.venv`, `.git`, `__pycache__`, `.import_linter_cache`, `dist`,
`build`, `state_*.txt`.

Полный дамп всего проекта не нужен: он линейно разрастается и
перестаёт быть читаемым.

### R8. Никаких мёртвых файлов

Если файл никем не импортируется — он удаляется сразу. Если
модуль переехал — старый путь исчезает, а не остаётся «на всякий
случай». Бэкапы (`.bak`) — временные, удаляются после того, как
изменение проверено и закоммичено.

## Структура

```
manual-gpt-server/
├── pyproject.toml            метаданные, зависимости, entry points
├── uv.lock                   lock-файл uv
├── pytest.ini                настройки pytest
├── .importlinter             контракты слоёв (R5)
├── README.md
├── docs/
│   └── ARCHITECTURE.md       этот файл
│
├── scripts/                  служебные скрипты (R6, R7)
│   ├── _common.py            find_project_root, iter_all, is_text
│   ├── dump_tree.py          дерево + конфиги + git
│   └── dump_full.py          исходники по путям
│
├── src/manual_gpt_server/    основной пакет
│   ├── __init__.py           entry point `manual-gpt-server`
│   │
│   ├── lib/                  ЯДРО (R1)
│   │   ├── __init__.py
│   │   ├── config.py         Settings (env)
│   │   ├── transport.py      Protocol Transport — контракт
│   │   ├── runtime.py        RuntimeState — in-memory очередь
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── low.py        сборка чанков OpenAI-формата
│   │   │   └── mid.py        оркестрация SSE-стрима
│   │   └── primitives/
│   │       ├── __init__.py
│   │       ├── clock.py      now_ts()
│   │       ├── ids.py        new_completion_id()
│   │       └── sse.py        sse_frame(), SSE_DONE
│   │
│   ├── cli/                  ТЕРМИНАЛЬНЫЙ ОПЕРАТОР (R2)
│   │   ├── __init__.py
│   │   ├── main.py           entry point `manual-gpt-server`
│   │   └── terminal.py       TerminalTransport
│   │
│   ├── rest/                 HTTP-СЛОЙ (R2, R4)
│   │   ├── __init__.py       реэкспорт build_rest_app
│   │   ├── server.py         build_rest_app(transport, model_id)
│   │   ├── routes.py         /v1/models, /v1/chat/completions,
│   │   │                     /v1/completions
│   │   └── client.py         RestClient (httpx)
│   │
│   ├── control/              ВЕБ-АДМИНКА (R3)
│   │   ├── __init__.py       реэкспорт build_control_app
│   │   ├── app.py            сборка FastAPI-приложения control
│   │   ├── admin.py          WS-хендлер /admin
│   │   ├── routes.py         REST /status, /history
│   │   └── static/
│   │       ├── admin.html
│   │       └── admin.js
│   │
│   └── server/               КОМПОЗИЦИОННЫЙ КОРЕНЬ (R5)
│       ├── __init__.py
│       └── main.py           entry point `manual-gpt-server-serve`
│                             поднимает API + control одновременно
│
└── tests/                    тесты (pytest)
    ├── conftest.py           FakeTransport, фикстуры app/client
    ├── test_lib.py           формат чанков, SSE, mid
    ├── test_rest.py          HTTP-контракт (chat + legacy)
    ├── test_queue.py         RuntimeState (stream, status, history)
    └── test_web_admin.py     smoke-тесты control (/admin, /status)
```

## Слои

### lib — ядро

Отвечает за:

- Контракт транспорта (`Transport.stream`)
- Формат OpenAI (`low`, `mid`)
- Настройки из env
- Утилиты (время, id, SSE-фреймы)
- In-memory очередь запросов (`RuntimeState`)

Не отвечает ни за:

- Как приходит запрос (HTTP, CLI, WS)
- Как вводится ответ (терминал, браузер)
- Сеть и I/O любого рода

Ключевой контракт:

```python
class Transport(Protocol):
    def stream(self, messages: list[dict]) -> AsyncIterator[str]: ...
```

Любой объект с методом `stream()` может быть транспортом. `lib`
не проверяет, кто это — `TerminalTransport`, `RuntimeState` или
тестовый `FakeTransport`.

### cli — терминальный оператор

Собирает `rest`-приложение с `TerminalTransport`. Отвечает за:

- Чтение ответа оператора через `input()`
- Резку строки на слова и отдачу их пословно (живой стрим)
- Поднятие HTTP-сервера (`build_rest_app`)

Не отвечает за:

- Формат ответа (это `lib`)
- Ввод-вывод за пределами терминала

### rest — HTTP-слой

Отвечает за:

- HTTP-роуты `/v1/models`, `/v1/chat/completions`, `/v1/completions`
- Сборку FastAPI-приложения из транспорта
- HTTP-клиент к тому же API (`client.py`)

Не отвечает за:

- Источник ответа (это `Transport`)
- UI поверх HTTP

### control — веб-админка

Собирает `rest`-приложение, добавляет:

- `/admin` — WebSocket-канал для оператора
- `/` и `/static` — HTML/JS админки
- `/status`, `/history` — REST-ручки наблюдения за состоянием

Работает поверх того же `RuntimeState`, который `rest` использует
как транспорт.

Не отвечает за:

- Логику `/v1/*` (это `rest`)
- Формат ответа (это `lib`)

### server — композиционный корень

Поднимает два FastAPI-приложения в одном процессе:

- API на `MANUAL_GPT_HOST:MANUAL_GPT_PORT` (по умолчанию `127.0.0.1:8000`)
- Control на `127.0.0.1:MANUAL_GPT_CONTROL_PORT` (по умолчанию `8001`,
  хардкод loopback — никогда не открывается наружу через env)

Оба приложения делят один `RuntimeState` в памяти.

## Поток данных

Сценарий: клиент обращается к `serve` в режиме stream, оператор
отвечает через веб-админку.

```
curl
  │ POST /v1/chat/completions {stream: true}
  ▼
rest/routes.py::chat          принимает HTTP, валидирует тело
  │ StreamingResponse(mid.stream_completion(...))
  ▼
lib/api/mid.py::stream_completion
  │ async for piece in source.stream(messages)
  ▼
lib/runtime.py::RuntimeState.stream
  │ pending.put({messages, out})
  ▼
control/admin.py::admin_endpoint   WS-хендлер вытаскивает запрос
  │ ws.send_json({type: "request", ...})
  ▼
браузер → admin.js → оператор печатает
  │ ws.send_json({type: "delta", content: "..."})
  ▼
control/admin.py::admin_endpoint
  │ out.put("...")
  ▼
lib/runtime.py::RuntimeState.stream
  │ yield "..."
  ▼
lib/api/mid.py::stream_completion
  │ sse_frame(low.content_chunk(...))
  ▼
lib/primitives/sse.py
  ▼
клиент видит SSE-чанки
```

Каждый слой отдаёт наверх ровно то, что обещал по своему контракту.

## Что запрещено

Эти импорты — ошибка, если появились:

```
lib     →  cli, rest, control, server   (нарушает R1, R5)
rest    →  cli, control, server         (нарушает R5)
cli     →  control, server              (нарушает R2)
control →  cli, server                  (нарушает R2)
lib     →  fastapi, starlette           (нарушает R1)
lib     →  httpx                        (нарушает R1)
lib     →  uvicorn, websockets          (нарушает R1)
```

В `lib` допустимы только `stdlib` и типизация. Всё остальное —
уровнем выше.

## Проверка инвариантов

Проект использует две автоматические проверки. Обе запускаются
через `uv run`.

### Слои (R5) — `.importlinter`

```cmd
uv run lint-imports
```

Четыре контракта:

| Контракт | Что проверяет |
|---|---|
| `Layered architecture (R5)` | `server` → `cli`/`control` → `rest` → `lib`, обратных стрелок нет |
| `lib stays framework-free (R1)` | `lib` не импортирует fastapi/starlette/httpx/uvicorn/websockets |
| `control stays out of lib internals (R3)` | `control` не импортирует `lib.api`/`lib.primitives`/`lib.transport` напрямую |
| `cli only touches rest (R2)` | `cli` не импортирует `lib.api`/`lib.primitives`/`lib.transport` напрямую |

Контракты R2 и R3 используют `allow_indirect_imports = True` —
они запрещают **прямые** импорты из `control`/`cli` в `lib`, но
разрешают транзитивные (через `rest`).

Ожидаемый вывод при чистом проекте:

```
Layered architecture (R5)                    KEPT
lib stays framework-free (R1)                KEPT
control stays out of lib internals (R3)      KEPT
cli only touches rest (R2)                   KEPT

Contracts: 4 kept, 0 broken.
```

Кеш `import-linter` пишется в `.import_linter_cache/` (в
`.gitignore`).

### Тесты — `pytest`

```cmd
uv run pytest
```

Покрытие:

| Файл | Что проверяет |
|---|---|
| `test_lib.py` | формат чанков, SSE-фреймы, `mid.stream_completion`, `created` фиксирован, legacy completions |
| `test_rest.py` | `/v1/models`, `/v1/chat/completions` (full + stream), `/v1/completions` (full + stream) |
| `test_queue.py` | `RuntimeState.stream`, ленивая инициализация `_pending`, `status()`, `history()` |
| `test_web_admin.py` | `control` принимает WS-подключение на `/admin`, `/status` отвечает |

`conftest.py` определяет `FakeTransport` и фикстуры `app`/`client`,
чтобы тесты не зависели от `input()` и реального WebSocket.

## Рабочий процесс

### Разработка

1. Внести правку.
2. `uv run pytest` — все тесты зелёные.
3. `uv run lint-imports` — все контракты KEPT.
4. `git commit`.

### Запуск

```cmd
uv run manual-gpt-server-serve
```

Поднимает API на `:8000` и control на `:8001`. Открой
`http://127.0.0.1:8001/` — это админка.

Для терминального режима (без веб-админки):

```cmd
uv run manual-gpt-server
```

### Дампы для обсуждения

Когда нужно показать состояние проекта (код-ревью, отладка):

```cmd
uv run scripts/dump_tree.py
```

→ `scripts/state_tree.txt`: дерево с размерами, все конфиги проекта,
git status.

```cmd
uv run scripts/dump_full.py                     # разумный набор по умолчанию
uv run scripts/dump_full.py src/manual_gpt_server/lib
uv run scripts/dump_full.py tests scripts
uv run scripts/dump_full.py pyproject.toml .importlinter
```

→ `scripts/state_dump.txt`: только указанные пути, только текстовые
файлы.

Оба выходных файла начинаются с `state_` и исключены из `.gitignore`.

### Миграции

Крупные перестройки структуры (переезды модулей, изменения
контрактов) оформляются отдельным коммитом с явным сообщением.
Формат — `vN: <суть>`, например `v3: clean lib, layered architecture`.

## История решений

- **v1** — три слоя: `api/`, `lib/`, `server.py` в корне. `cli`
  зависел от `server.py`, `web` тоже. Не было разделения на
  HTTP-фасад и точку входа.
- **v2** — разделили `cli` и `web` как равноправные entry points,
  оба собирают `server.py`. Появились `rest/`, но `lib` всё ещё
  содержал `terminal.py` и `queue.py` — UI-код протекал в ядро.
- **v3** — `api/` и `primitives/` переехали внутрь `lib`, транспорты
  переехали к своим потребителям (`cli/terminal.py`, `web/queue.py`).
  `lib` стал чистым ядром.
- **v3.1** — служебные скрипты переписаны с `.bat` на Python,
  переехали в `scripts/`. Добавлены `tests/`, `.importlinter`,
  `pytest.ini`. `created` в SSE-чанках зафиксирован на весь ответ.
- **v3.2 (текущая)** — `web/` расформирован. Появились `control/`
  (веб-админка) и `server/` (композиционный корень с двумя
  FastAPI-приложениями на двух портах). `QueueTransport` заменён на
  `lib/runtime.RuntimeState` — общий стейт процесса, используется и
  как транспорт для `rest`, и как источник данных для control REST-ручек.
  Добавлен `/v1/completions` (legacy API) для Continue в Edit mode.

## Что дальше

Не сделано, но планируется:

### Разделение `serve` и операторов

Сейчас `server/main.py` поднимает **два приложения в одном процессе**:
API и control. По факту control — это админка, а `serve` — не должно
быть админкой. Планируется:

- `serve` — только API на `:8000`. Ни статики, ни `/admin`.
- `web` — отдельное приложение с админкой (HTML + JS + WS + REST).
- `cli` — терминальный оператор без порта.
- **Вариант 1 с задел на 2:** всё в одном процессе с флагами
  `--with-cli`, `--with-web`. Задел — на разнесение по процессам
  через IPC (named pipe / Unix socket), когда появится потребность
  в «оператор на другой машине».

### UI админки

Счётчик очереди (видно, сколько запросов ждёт), история ответов
(не пропадает после Send), индикатор прогресса стрима, сворачивание
длинных системных промптов (Continue в agent mode шлёт стены текста).

### Multi-model

Несколько `model_id`, маршрутизация в `rest/routes.py`. Сейчас
`/v1/models` всегда возвращает один элемент, `model` в запросе
игнорируется.

### Auth

`MANUAL_GPT_API_KEY` реально проверяется на `/v1/*` и `/admin`.
Сейчас ключ читается в `Settings`, но нигде не валидируется.

### Ruff

Линтер кода (`ruff check`, `ruff format`). Добавить в
dev-зависимости и прогнать первый раз.

### Мелочи

- `.gitignore` — расширить: `.import_linter_cache/`,
  `scripts/__pycache__/`, `scripts/state_*.txt`.
- `pyproject.toml` — обновить `description`.
- `lib/primitives/ids.py` — PEP 8: пустая строка после `import uuid`.