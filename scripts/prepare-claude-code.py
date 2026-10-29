#!/usr/bin/env python3
"""Build the opt-in worker candidate from the verified production source + QQ fixes."""
import hashlib
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path(sys.argv[1]).resolve()
baseline = json.loads((root / 'claude-code-baseline.json').read_text(encoding='utf-8'))
revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
if revision != baseline['upstream']:
    raise SystemExit(f'Expected verified production source {baseline["upstream"]}; found {revision}')

subprocess.run([sys.executable, str(root / 'scripts/prepare.py'), str(source)], check=True)
patch = root / 'patches/claude-code-server.patch'
if not patch.is_file():
    raise SystemExit('Candidate patch has not been exported; no image may be published.')
digest = hashlib.sha256(patch.read_bytes()).hexdigest()
if digest != baseline['patchSha256']:
    raise SystemExit('Candidate patch differs from the recorded, validated source.')
subprocess.run(['git', '-C', str(source), 'apply', '--check', str(patch)], check=True)
subprocess.run(['git', '-C', str(source), 'apply', str(patch)], check=True)
print(f'Applied Claude Code candidate SHA256 {digest}')
