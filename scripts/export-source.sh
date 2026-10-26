#!/bin/zsh
# Curated publication only; original working files stay untouched.
set -euo pipefail
cd "${0:A:h:h}"
python3 - <<'PY'
from pathlib import Path
import shutil
root=Path.cwd()
target=root/'build/github-project'
manifest=(root/'scripts/public-files.txt').read_text().splitlines()
allowed=set(manifest)
assert all(p and not p.startswith('/') and '..' not in Path(p).parts for p in allowed)
target.mkdir(parents=True,exist_ok=True)
for path in target.rglob('*'):
    relative=path.relative_to(target)
    if '.git' in relative.parts: continue
    if path.is_file() and str(relative) not in allowed: path.unlink()
for relative in manifest:
    source=root/relative
    if relative=='VALIDATION.md': source=root/'docs/PUBLIC-VALIDATION.md'
    if not source.is_file(): raise SystemExit(f'Missing public source: {relative}')
    destination=target/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,destination)
for path in sorted(target.rglob('*'),key=lambda p:len(p.parts),reverse=True):
    if '.git' not in path.relative_to(target).parts and path.is_dir() and not any(path.iterdir()): path.rmdir()
print('Source checkout: '+str(target))
PY
(cd build/github-project && python3 scripts/audit-source.py)
