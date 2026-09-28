@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM === Найти корень проекта ===
cd /d "%~dp0"
set "LAST="
:walk
if exist "pyproject.toml" goto :found
if "!CD!"=="!LAST!" (
    echo [X] pyproject.toml не найден.
    pause
    exit /b 1
)
set "LAST=!CD!"
cd ..
goto :walk
:found
echo Корень проекта: %CD%
echo.

if not exist ".importlinter" (
    echo [X] .importlinter не найден.
    pause
    exit /b 1
)

copy /y ".importlinter" ".importlinter.bak2" >nul

echo Перезаписываю .importlinter ...

>  ".importlinter" echo [importlinter]
>> ".importlinter" echo root_package = manual_gpt_server
>> ".importlinter" echo include_external_packages = True
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R5: строгая слоистость ---------------------------------
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
>> ".importlinter" echo # ---- R3: web не лезет в lib НАПРЯМУЮ -----------------------
>> ".importlinter" echo [importlinter:contract:web-via-rest]
>> ".importlinter" echo name = web only touches rest ^(R3^)
>> ".importlinter" echo type = forbidden
>> ".importlinter" echo source_modules =
>> ".importlinter" echo     manual_gpt_server.web
>> ".importlinter" echo forbidden_modules =
>> ".importlinter" echo     manual_gpt_server.lib.api
>> ".importlinter" echo     manual_gpt_server.lib.primitives
>> ".importlinter" echo     manual_gpt_server.lib.transport
>> ".importlinter" echo allow_indirect_imports = True
>> ".importlinter" echo.
>> ".importlinter" echo # ---- R2: cli не лезет в lib НАПРЯМУЮ -----------------------
>> ".importlinter" echo [importlinter:contract:cli-via-rest]
>> ".importlinter" echo name = cli only touches rest ^(R2^)
>> ".importlinter" echo type = forbidden
>> ".importlinter" echo source_modules =
>> ".importlinter" echo     manual_gpt_server.cli
>> ".importlinter" echo forbidden_modules =
>> ".importlinter" echo     manual_gpt_server.lib.api
>> ".importlinter" echo     manual_gpt_server.lib.primitives
>> ".importlinter" echo     manual_gpt_server.lib.transport
>> ".importlinter" echo allow_indirect_imports = True

echo Запускаю проверку...
echo.
uv run lint-imports

echo.
echo ============================================
echo  Готово. Backup: .importlinter.bak2
echo  Повторный запуск: uv run lint-imports
echo ============================================
pause