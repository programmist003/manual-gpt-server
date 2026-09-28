@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

REM === Проверка, что мы в корне проекта ===
if not exist "pyproject.toml" (
    echo [X] pyproject.toml не найден. Запусти из корня проекта.
    pause
    exit /b 1
)

echo [1/3] Бэкап pyproject.toml...
copy /y "pyproject.toml" "pyproject.toml.bak" >nul

echo [2/3] Добавляю websockets как основную зависимость...
uv add "websockets>=12"

echo [3/3] Синхронизация окружения...
uv sync

echo.
echo ============================================
echo  Готово.
echo  Backup: pyproject.toml.bak
echo.
echo  Запускай: uv run manual-gpt-server-web
echo  Открывай: http://127.0.0.1:8000/
echo ============================================
pause