from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from _common import find_project_root, iter_all


def main() -> int:
    root = find_project_root()
    out = Path(__file__).resolve().parent / "state_tree.txt"

    print(f"Корень проекта: {root}")
    print(f"Куда пишу:      {out}")

    files = iter_all(root)

    lines = ["=== TREE ==="]
    lines.append(f"{'size':>10}  path")
    lines.append("-" * 70)
    for f in files:
        rel = f.relative_to(root)
        lines.append(f"{f.stat().st_size:>10}  {rel}")
    lines.append("")
    lines.append(f"Всего файлов: {len(files)}")

    # Конфиги проекта — маленькие, полезно видеть их целиком
    for name in ("pyproject.toml", ".gitignore", ".importlinter", "pytest.ini", "README.md"):
        p = root / name
        if not p.exists():
            continue
        lines.append("")
        lines.append(f"=== {name} ===")
        lines.append(p.read_text(encoding="utf-8"))

    lines.append("")
    lines.append("=== GIT ===")
    if (root / ".git").exists():
        for cmd in (
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            ["git", "log", "--oneline", "-n", "5"],
            ["git", "status", "--short"],
        ):
            r = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
            lines.append(r.stdout.rstrip())
            lines.append("")
    else:
        lines.append("(no git repo)")

    out.write_text("\n".join(lines), encoding="utf-8")
    print()
    print(f"Готово. {out} ({out.stat().st_size} байт)")
    return 0


if __name__ == "__main__":
    sys.exit(main())