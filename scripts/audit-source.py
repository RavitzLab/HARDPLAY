#!/usr/bin/env python3
"""Audit tracked source (or the curated export) without printing matched values."""
import argparse
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--history', action='store_true', help='Also scan reachable historical text blobs for common secret patterns')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
manifest = set((root/'scripts/public-files.txt').read_text().splitlines())
tracked = subprocess.run(['git','ls-files','-z'],cwd=root,capture_output=True,check=True).stdout.decode().split('\0')
files = [p for p in tracked if p and (root/p).is_file()]
# A fresh exported tree can include new, not-yet-staged files.
files = sorted(set(files) | {p for p in manifest if (root/p).is_file()})
findings = [(p,"required public file missing") for p in manifest if not (root/p).is_file()]
secret_patterns = {
    'private key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'GitHub token': re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{35,})\b'),
    'API token': re.compile(rb'\b(?:sk-(?:proj-)?[A-Za-z0-9_-]{32,}|AIza[A-Za-z0-9_-]{30,}|AKIA[A-Z0-9]{16})\b'),
    'credential URL': re.compile(rb'https?://[^\s/:]+:[^\s/@]+@'),
}
personal = re.compile(rb'(?:/Users/[^/\s]+/|[A-Z]:\\Users\\[^\\\s]+\\)')
for relative in files:
    path=root/relative
    if relative not in manifest:
        findings.append((relative,'not in public source manifest'))
    if not path.is_file():
        findings.append((relative,'tracked file missing')); continue
    data=path.read_bytes()
    if b'\0' in data[:8192]: continue
    for label,pattern in secret_patterns.items():
        if pattern.search(data): findings.append((relative,label))
    if relative != 'scripts/audit-source.py' and personal.search(data): findings.append((relative,'personal absolute path'))
if args.history:
    objects=subprocess.check_output(['git','rev-list','--objects','--all'],cwd=root).decode().splitlines()
    blobs={}
    for row in objects:
        oid,_,path=row.partition(' ')
        if subprocess.check_output(['git','cat-file','-t',oid],cwd=root).strip()!=b'blob': continue
        data=subprocess.check_output(['git','cat-file','blob',oid],cwd=root)
        if b'\0' in data[:8192]: continue
        for label,pattern in secret_patterns.items():
            if pattern.search(data): findings.append((f'history:{oid[:10]}:{path}',label))
    print(f'History inspected: {len(objects)} reachable objects')
for path,label in findings: print(f'CHECK {path}: {label}')
if findings: raise SystemExit(1)
print(f'PASS: {len(files)} public files; no unexpected tracked artifacts, personal paths or common credential patterns')
