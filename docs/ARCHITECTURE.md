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
веб, тесты или сторонний код. Следствия:

- В `lib` **нет** `print`, `input`, UI-очередей, WebSocket,
  ничего из FastAPI-роутов.
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

```
cli    ─┐
        ├──▶ rest ──▶ lib ──▶ stdlib
web ────┘
```

Никаких обратных стрелок. `lib` не может импортировать
`rest`/`cli`/`web`. `rest` не может импортировать `cli`/`web`.

Проверяется автоматически контрактом `.importlinter`
(см. «Проверка инвариантов»).

### R6. Служебные скрипты — на Python в `scripts/`

Любая автоматизация (дампы, миграции, подготовка окружения)
живёт в `scripts/` и пишется на Python. Никаких `.bat`, `.sh`,
`.ps1` — только `.py`, запускаемые через `uv run python`.

Причины:

- Один язык для кода проекта и для инструментов.
- Кроссплатформенность без правок.
- Читаемость: нет `^`, `>>`, `!VAR!`, `%~dp0`.
- Тестируемость: модули `scripts/` можно импортировать в pytest.

Bootstrap решается сам собой: `uv run python scripts/foo.py`
собирает venv, если его нет, и потом выполняет скрипт.

### R7. Дампы разделены по назначению

- `scripts/dump_tree.py` — структура + `pyproject.toml` + git.
  Для «что изменилось». Размер — единицы килобайт.
- `scripts/dump_full.py <layer>` — исходники одного слоя
  (`lib`, `cli`, `rest`, `web`) или всего `src/`. Для «покажи мне
  этот слой».

Оба пишут в `scripts/`, не в корень проекта. Оба игнорируют
`.venv`, `.git`, `__pycache__`, `dist`, `build`, `*.pyc`, `*.bak`,
`state_*.txt`.

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
│   ├── _common.py            find_project_root, iter_files
│   ├── dump_tree.py          дерево + pyproject + git
│   └── dump_full.py          исходники одного слоя
│
├── src/manual_gpt_server/    основной пакет
│   ├── __init__.py           entry point `manual-gpt-server`
│   │
│   ├── lib/                  ЯДРО (R1)
│   │   ├── __init__.py
│   │   ├── config.py         Settings (env)
│   │   ├── transport.py      Protocol Transport — контракт
│   │   ├── api/
│   │   │   ├── low.py        сборка чанков OpenAI-формата
│   │   │   └── mid.py        оркестрация SSE-стрима
│   │   └── primitives/
│   │       ├── clock.py      now_ts()
│   │       ├── ids.py        new_completion_id()
│   │       └── sse.py        sse_frame(), SSE_DONE
│   │
│   ├── cli/                  ТЕРМИНАЛЬНЫЙ ФРОНТ (R2)
│   │   ├── main.py           entry point `manual-gpt-server`
│   │   └── terminal.py       TerminalTransport
│   │
│   ├── rest/                 HTTP-СЛОЙ (R2, R4)
│   │   ├── __init__.py       реэкспорт build_rest_app
│   │   ├── server.py         build_rest_app(transport, model_id)
│   │   ├── routes.py         /v1/models, /v1/chat/completions
│   │   └── client.py         RestClient (httpx)
│   │
│   └── web/                  ВЕБ-АДМИНКА (R3)
│       ├── app.py            entry point `manual-gpt-server-web`
│       ├── queue.py          QueueTransport
│       └── static/
│           ├── admin.html
│           └── admin.js
│
└── tests/                    тесты (pytest)
    ├── conftest.py           FakeTransport, фикстуры app/client
    ├── test_lib.py           формат чанков, SSE, mid
    ├── test_rest.py          HTTP-контракт
    ├── test_queue.py         QueueTransport
    └── test_web_admin.py     smoke-тест /admin WS
```

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

```python
class Transport(Protocol):
    def stream(self, messages: list[dict]) -> AsyncIterator[str]: ...
```

Любой объект с методом `stream()` может быть транспортом. `lib`
не проверяет, кто это — `TerminalTransport`, `QueueTransport` или
тестовый `FakeTransport`.

### cli — терминальный фронт

Собирает `lib`-ядро с `TerminalTransport`. Отвечает за:

- Чтение ответа оператора через `input()`
- Резку строки на слова и отдачу их пословно (живой стрим)
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
```

Каждый слой отдаёт наверх ровно то, что обещал по своему контракту.

## Что запрещено

Эти импорты — ошибка, если появились:

```
lib  →  cli, rest, web         (нарушает R1, R5)
rest →  cli, web               (нарушает R5)
cli  →  rest                   (нарушает R2)
web  →  cli                    (нарушает R3)
lib  →  fastapi, starlette     (нарушает R1)
lib  →  httpx                  (нарушает R1)
```

В `lib` допустимы только `stdlib` и типизация. Всё остальное —
уровнем выше.

## Проверка инвариантов

Проект использует четыре автоматические проверки. Все запускаются
через `uv run`.

### Слои (R5) — `.importlinter`

```cmd
uv run lint-imports
```

Четыре контракта:

| Контракт | Что проверяет |
|---|---|
| `Layered architecture (R5)` | `cli`/`web` → `rest` → `lib`, обратных стрелок нет |
| `lib stays framework-free (R1)` | `lib` не импортирует fastapi/starlette/httpx/uvicorn/websockets |
| `web only touches rest (R3)` | `web` не импортирует `lib.*` напрямую (только через `rest`) |
| `cli only touches rest (R2)` | `cli` не импортирует `lib.*` напрямую |

Контракты R2 и R3 используют `allow_indirect_imports = True` —
они запрещают **прямые** импорты из `web`/`cli` в `lib`, но
разрешают транзитивные (когда `rest` внутри себя импортирует `lib`).

Ожидаемый вывод при чистом проекте:

```
Layered architecture (R5)                    KEPT
lib stays framework-free (R1)                KEPT
web only touches rest (R3)                   KEPT
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
| `test_lib.py` | формат чанков, SSE-фреймы, `mid.stream_completion`, `created` фиксирован |
| `test_rest.py` | `/v1/models`, `/v1/chat/completions` (full + stream) |
| `test_queue.py` | `QueueTransport.stream`, ленивая инициализация `_pending` |
| `test_web_admin.py` | `/admin` принимает WS-подключение |

`conftest.py` определяет `FakeTransport` и фикстуры `app`/`client`,
чтобы тесты не зависели от `input()` и реального WebSocket.

## Рабочий процесс

### Разработка

1. Внести правку.
2. `uv run pytest` — все тесты зелёные.
3. `uv run lint-imports` — все контракты KEPT.
4. `git commit`.

### Дампы для обсуждения

Когда нужно показать состояние проекта (например, для код-ревью,
или отладки с кем-то):

```cmd
uv run python scripts\dump_tree.py
```

Получишь `scripts/state_tree.txt` — структуру + pyproject + git
status. Компактно.

```cmd
uv run python scripts\dump_full.py lib
```

Получишь `scripts/state_dump.txt` — исходники слоя `lib`.
Аргумент — любой из `lib`, `cli`, `rest`, `web`, или без аргумента
для всего `src/manual_gpt_server`.

Оба файла начинаются с `state_` и исключены из `.gitignore`.

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
- **v3 (текущая)** — вариант C: `api/` и `primitives/` переехали
  внутрь `lib`, транспорты переехали к своим потребителям
  (`cli/terminal.py`, `web/queue.py`). `lib` стал чистым ядром.
- **v3.1** — служебные скрипты переписаны с `.bat` на Python,
  переехали в `scripts/`. Добавлены `tests/`, `.importlinter`,
  `pytest.ini`. `created` в SSE-чанках зафиксирован на весь ответ.

## Что дальше

Не сделано, но планируется:

- **UI админки** — счётчик очереди (видно, сколько запросов
  ждёт), история ответов (не пропадает после Send), индикатор
  прогресса стрима.
- **Multi-model** — несколько `model_id`, маршрутизация в
  `rest/routes.py`. Сейчас `/v1/models` всегда возвращает один
  элемент, `model` в запросе игнорируется.
- **Auth** — `MANUAL_GPT_API_KEY` реально проверяется на
  `/v1/*` и `/admin`. Сейчас ключ читается в `Settings`, но
  нигде не валидируется.
- **Ruff** — линтер кода (`ruff check`, `ruff format`).
  Добавить в dev-зависимости и прогнать первый раз.
- **`.gitignore`** — расширить: `.import_linter_cache/`,
  `scripts/__pycache__/`, `scripts/state_*.txt`.
- **Мелочи** — убрать `jinja2` из `pyproject.toml`, обновить
  `description`, поправить PEP 8 в `lib/primitives/ids.py`
  (пустая строка после `import uuid`).