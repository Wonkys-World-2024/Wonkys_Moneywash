"""Parse Lua source and item-entry snippets using a local Lua 5.4 compiler."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
compiler = shutil.which("luac5.4") or shutil.which("luac")
if compiler is None:
    raise SystemExit("Install Lua 5.4 and put luac5.4 or luac on PATH.")
for path in sorted(root.rglob("*.lua")):
    source = path.read_text(encoding="utf-8")
    if path.relative_to(root).as_posix() == "install/items.lua":
        source = "return {\n" + source + "\n}"
    result = subprocess.run([compiler, "-p", "-"], input=source, text=True, capture_output=True)
    if result.returncode:
        raise SystemExit(f"{path.relative_to(root)}: {result.stderr.strip()}")
    print(f"Syntax OK: {path.relative_to(root)}")
