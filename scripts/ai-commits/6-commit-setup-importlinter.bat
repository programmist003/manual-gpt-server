@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM === Найти корень проекта (walk-up по pyproject.toml) ===
cd /d "%~dp0"
set "LAST="
:walk
if exist "pyproject.toml" goto :found
if "!CD!"=="!LAST!" (
    echo [X] pyproject.toml не найден ни в "%CD%", ни выше.
    pause
    exit /b 1
)
set "LAST=!CD!"
cd ..
goto :walk
:found
echo Корень проекта: %CD%
echo.

REM === 1. Добавить import-linter в dev-зависимости ===
echo [1/3] Добавляю import-linter в dev-зависимости...
uv add --dev import-linter
if errorlevel 1 (
    echo [X] uv add не сработал.
    pause
    exit /b 1
)

REM === 2. Записать .importlinter ===
echo [2/3] Пишу .importlinter ...

>  ".importlinter" echo [importlinter]
>> ".importlinter" echo root_package = manual_gpt_server
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R5: строгая слоистость ---------------------------------
>> ".importlinter" echo # cli и web — один уровень, независимы друг от друга.
>> ".importlinter" echo # rest — посередине. lib — внизу, ни на кого не смотрит.
>> ".importlinter" echo [importlinter:contract:layers]
>> ".importlinter" echo name = Layered architecture (R5)
>> ".importlinter" echo type = layers
>> ".importlinter" echo layers =
>> ".importlinter" echo     manual_gpt_server.cli ^| manual_gpt_server.web
>> ".importlinter" echo     manual_gpt_server.rest
>> ".importlinter" echo     manual_gpt_server.lib
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R1: lib не тянет веб-фреймворки ------------------------
>> ".importlinter" echo [importlinter:contract:lib-purity]
>> ".importlinter" echo name = lib stays framework-free (R1)
>> ".importlinter" echo type = forbidden
>> ".importlinter" echo source_modules =
>> ".importlinter" echo     manual_gpt_server.lib
>> ".importlinter" echo forbidden_modules =
>> ".importlinter" echo     fastapi
>> ".importlinter" echo     starlette
>> ".importlinter" echo     httpx
>> ".importlinter" echo     uvicorn
>> ".importlinter" echo     websockets
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R3: web собирает rest, а не лезет в lib сам -----------
>> ".importlinter" echo [importlinter:contract:web-via-rest]
>> ".importlinter" echo name = web only touches rest (R3)
>> ".importlinter" echo type = forbidden
>> ".importlinter" echo source_modules =
>> ".importlinter" echo     manual_gpt_server.web
>> ".importlinter" echo forbidden_modules =
>> ".importlinter" echo     manual_gpt_server.lib.api
>> ".importlinter" echo     manual_gpt_server.lib.primitives
>> ".importlinter" echo     manual_gpt_server.lib.transport
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R2: cli собирает rest, а не лезет в lib сам -----------
>> ".importlinter" echo [importlinter:contract:cli-via-rest]
>> ".importlinter" echo name = cli only touches rest (R2)
>> ".importlinter" echo type = forbidden
>> ".importlinter" echo source_modules =
>> ".importlinter" echo     manual_gpt_server.cli
>> ".importlinter" echo forbidden_modules =
>> ".importlinter" echo     manual_gpt_server.lib.api
>> ".importlinter" echo     manual_gpt_server.lib.primitives
>> ".importlinter" echo     manual_gpt_server.lib.transport

REM === 3. Запустить проверку ===
echo [3/3] Запускаю проверку...
echo.
uv run lint-imports

echo.
echo ============================================
echo  Готово.
echo  Конфиг: .importlinter
echo  Повторный запуск: uv run lint-imports
echo ============================================
pause