"""
Compatibility wrapper for the legacy `.claude/skills/icon` entrypoint.

The icon pipeline now lives under `.claude/skills/image/icon/`.
"""

from __future__ import annotations

import runpy
from pathlib import Path


def main() -> None:
    target = Path(__file__).resolve().parent.parent / "image" / "icon" / "generate.py"
    runpy.run_path(str(target), run_name="__main__")


if __name__ == "__main__":
    main()

