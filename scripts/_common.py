from __future__ import annotations

from pathlib import Path

EXCLUDE_DIRS = {
    ".venv", ".git", "__pycache__", ".ruff_cache",
    ".mypy_cache", ".pytest_cache", "dist", "build",
    ".idea", ".vscode",
}

EXCLUDE_SUFFIXES = {".pyc", ".bak"}


def find_project_root(start: Path | None = None) -> Path:
    """Поднимается вверх от start, пока не найдёт pyproject.toml."""
    here = start or Path(__file__).resolve().parent
    for candidate in [here, *here.parents]:
        if (candidate / "pyproject.toml").exists():
            return candidate
    raise RuntimeError(f"pyproject.toml not found above {here}")


def iter_files(root: Path, extra_exclude_dirs: set[str] = frozenset()) -> list[Path]:
    """Все файлы под root, кроме мусорных папок и расширений.

    Родительские компоненты пути (parts[:-1]) проверяются на вхождение
    в excluded — это отсекает целые поддеревья, не заходя в них.
    """
    excluded = EXCLUDE_DIRS.union(extra_exclude_dirs)
    result: list[Path] = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        parts = p.relative_to(root).parts
        if any(part in excluded for part in parts[:-1]):
            continue
        if p.suffix in EXCLUDE_SUFFIXES:
            continue
        if p.name.startswith("state_") and p.suffix == ".txt":
            continue
        result.append(p)
    return sorted(result)