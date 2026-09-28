from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from _common import find_project_root, iter_files


def main() -> int:
    root = find_project_root()
    out = Path(__file__).resolve().parent / "state_tree.txt"

    print(f"Корень проекта: {root}")
    print(f"Куда пишу:      {out}")

    files = iter_files(root, extra_exclude_dirs={"scripts"})

    lines = ["=== TREE ==="]
    for f in files:
        lines.append(str(f.relative_to(root)))

    lines.append("")
    lines.append("=== pyproject.toml ===")
    pyproject = root / "pyproject.toml"
    if pyproject.exists():
        lines.append(pyproject.read_text(encoding="utf-8"))
    else:
        lines.append("(not found)")

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