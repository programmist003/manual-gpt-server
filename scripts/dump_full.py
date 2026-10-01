from __future__ import annotations

import sys
from pathlib import Path

from _common import find_project_root, is_text, iter_all

# Что дампить по умолчанию (когда аргументов нет)
DEFAULT_TARGETS = [
    "pyproject.toml",
    ".importlinter",
    "pytest.ini",
    ".gitignore",
    "README.md",
    "docs",
    "src",
    "tests",
    "scripts",
]


def collect(root: Path, targets: list[str]) -> tuple[list[Path], list[str]]:
    files: list[Path] = []
    missing: list[str] = []
    for t in targets:
        p = root / t
        if not p.exists():
            missing.append(t)
            continue
        if p.is_file():
            files.append(p)
        else:
            files.extend(f for f in iter_all(p) if is_text(f))
    return sorted(set(files)), missing


def main(argv: list[str]) -> int:
    targets = argv[1:] or DEFAULT_TARGETS
    root = find_project_root()

    out = Path(__file__).resolve().parent / "state_dump.txt"
    files, missing = collect(root, targets)

    if missing:
        print(f"[!] Не найдено: {', '.join(missing)}")
    if not files:
        print("[X] Нечего дампить.")
        return 1

    total = sum(f.stat().st_size for f in files)
    print(f"Корень проекта: {root}")
    print(f"Куда пишу:      {out}")
    print(f"Файлов:         {len(files)}")
    print(f"Размер:         {total} байт (~{total // 1024} КБ)")

    lines = ["=== FILE LIST ==="]
    for f in files:
        lines.append(str(f.relative_to(root)))

    lines.append("")
    lines.append("=== CONTENTS ===")
    for f in files:
        rel = f.relative_to(root)
        lines.append("")
        lines.append(f"----- {rel} -----")
        try:
            content = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            content = "(binary or non-utf8)"
        lines.append(content)
        lines.append("")

    out.write_text("\n".join(lines), encoding="utf-8")
    print()
    print(f"Готово. {out} ({out.stat().st_size} байт)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))