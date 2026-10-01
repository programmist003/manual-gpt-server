# manual-gpt-server

OpenAI-совместимый HTTP-сервер, в котором роль «модели» играет человек.

Клиент (`openai-python`, `langchain`, `chat-ui`, Continue, Cursor) думает,
что говорит с LLM. На самом деле запрос уходит оператору — в терминал или
в веб-админку, — оператор печатает ответ, и он возвращается клиенту
в формате `chat.completion` / SSE-стрима.

## Зачем это

- **Отладка LLM-клиентов без токенов.** Пробуешь новый SDK или chat-UI,
  не тратя деньги на API.
- **Тесты.** Гоняешь e2e-сценарии с детерминированными ответами.
- **Демонстрации.** Показываешь, как работает streaming, tool-calls,
  длинные контексты — без реальной модели.
- **Человек в цикле.** Заготовка под пайплайны, где ответ должен дать
  живой человек.

## Быстрый старт

Нужен [uv](https://docs.astral.sh/uv/). Больше ничего.

```cmd
git clone https://github.com/programmist003/manual-gpt-server
cd manual-gpt-server
uv sync
```

### Запуск с веб-админкой

```cmd
uv run manual-gpt-server-serve
```

Поднимает два приложения в одном процессе:

- **API** на `http://127.0.0.1:8000` — то, что видят клиенты.
- **Control** на `http://127.0.0.1:8001` — веб-админка для оператора.

Открой `http://127.0.0.1:8001/` в браузере. Оставь вкладку открытой.

### Запуск в терминале

```cmd
uv run manual-gpt-server
```

Поднимает только API на `:8000`. Ответы читаются из stdin —
печатай в том же терминале, где запущен сервер.

## Как попробовать

Оставь сервер работать. В другом окне:

```cmd
curl -N -X POST http://127.0.0.1:8000/v1/chat/completions ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"manual\",\"messages\":[{\"role\":\"user\",\"content\":\"привет\"}],\"stream\":true}"
```

`curl` повиснет — ждёт ответа. В админке (или в терминале, если запускал
без веба) появится запрос. Напечатай ответ, отправь.

`curl` раздуплится и получит OpenAI-совместимый SSE-стрим.

## Совместимость

Работает со всем, что умеет говорить на OpenAI API:

- `openai-python` — просто укажи `base_url="http://127.0.0.1:8000/v1"`.
- **Continue** — в `~/.continue/config.yaml`:

  ```yaml
  models:
    - name: Manual GPT
      provider: openai
      model: manual
      apiBase: http://127.0.0.1:8000/v1
      apiKey: dummy
  ```

- **LangChain**, **LlamaIndex**, **chat-ui** и прочие — через тот же
  `base_url`.

Поддерживаемые эндпоинты:

| Метод | Путь | Что |
|---|---|---|
| `GET` | `/v1/models` | Список моделей (всегда одна, `MANUAL_GPT_MODEL_ID`) |
| `POST` | `/v1/chat/completions` | Чат, с `stream: true` и без |
| `POST` | `/v1/completions` | Legacy Completions API (нужен Continue в Edit mode) |

## Настройки

Всё через переменные окружения:

| Переменная | По умолчанию | Что |
|---|---|---|
| `MANUAL_GPT_HOST` | `127.0.0.1` | Хост API |
| `MANUAL_GPT_PORT` | `8000` | Порт API |
| `MANUAL_GPT_CONTROL_PORT` | `8001` | Порт админки (только loopback) |
| `MANUAL_GPT_MODEL_ID` | `manual` | Имя модели в `/v1/models` |
| `MANUAL_GPT_API_KEY` | — | Зарезервировано (пока не проверяется) |

Пример:

```cmd
set MANUAL_GPT_PORT=9000
uv run manual-gpt-server-serve
```

**Порт `8001` (control) всегда слушает `127.0.0.1`** и не открывается
наружу через env. Это сделано специально: админка — локальный инструмент,
не должна торчать в сеть.

## Разработка

```cmd
uv run pytest           # тесты
uv run lint-imports     # проверка слоёв (.importlinter)
```

Обе команды должны быть зелёными перед коммитом.

### Структура

```
src/manual_gpt_server/
├── lib/          ядро: контракт Transport, формат OpenAI, RuntimeState
├── cli/          терминальный оператор
├── rest/         HTTP-фасад (/v1/*)
├── control/      веб-админка (HTML + WS + REST-ручки)
└── server/       композиционный корень (поднимает API + control)
```

Слои строго снизу вверх: `server → control/cli → rest → lib`. Нарушения
ловятся `.importlinter` автоматически.

Полное описание архитектуры, требований и инвариантов —
в [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Служебные скрипты

```cmd
uv run scripts/dump_tree.py
uv run scripts/dump_full.py src/manual_gpt_server/lib
uv run scripts/dump_full.py tests scripts
```

`dump_tree.py` — структура проекта с размерами и конфигами.
`dump_full.py` — исходники по указанным путям. Оба пишут результат
в `scripts/`.

## Ограничения

- **Один оператор за раз.** Очередь линейная, без broadcast. Если
  подключиться к админке с двух вкладок — вторая увидит только новые
  запросы, старые уже разобраны первой.
- **Нет аутентификации.** `/v1/*` открыт всем, кто может достучаться
  до порта API. Не выставляй `MANUAL_GPT_HOST=0.0.0.0` в публичной
  сети без обратного прокси с auth.
- **`usage` всегда нули.** `prompt_tokens` и `completion_tokens`
  не считаются — некоторые клиенты могут ругаться.
- **Один `model_id`.** Multi-model пока не реализован.

## Лицензия

См. `LICENSE` в корне проекта.