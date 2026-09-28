from __future__ import annotations

import sys
from pathlib import Path

from _common import find_project_root, iter_files


def main(argv: list[str]) -> int:
    sub = argv[1] if len(argv) > 1 else ""
    root = find_project_root()
    src = root / "src" / "manual_gpt_server"
    scan_root = src / sub if sub else src

    if not scan_root.exists():
        print(f"[X] Не найдено: {scan_root}")
        print()
        print("Использование:")
        print("    dump_full.py             — весь src/manual_gpt_server")
        print("    dump_full.py lib         — только lib")
        print("    dump_full.py cli         — только cli")
        print("    dump_full.py rest        — только rest")
        print("    dump_full.py web         — только web")
        return 1

    out = Path(__file__).resolve().parent / "state_dump.txt"
    title = f"src/manual_gpt_server/{sub}" if sub else "весь src/manual_gpt_server"

    print(f"Корень проекта: {root}")
    print(f"Куда пишу:      {out}")
    print(f"Сканирую:       {title}")

    files = iter_files(scan_root)

    lines = [f"=== TREE ({title}) ==="]
    for f in files:
        lines.append(str(f.relative_to(root)))

    lines.append("")
    lines.append("=== SOURCE FILES ===")
    for f in files:
        if f.suffix == ".py":
            lines.append("")
            lines.append(f"----- {f.relative_to(root)} -----")
            lines.append(f.read_text(encoding="utf-8"))
            lines.append("")

    lines.append("")
    lines.append("=== pyproject.toml ===")
    pyproject = root / "pyproject.toml"
    if pyproject.exists():
        lines.append(pyproject.read_text(encoding="utf-8"))
    else:
        lines.append("(not found)")

    out.write_text("\n".join(lines), encoding="utf-8")
    print()
    print(f"Готово. {out} ({out.stat().st_size} байт)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))