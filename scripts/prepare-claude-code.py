#!/usr/bin/env python3
"""Apply the Claude Code patch, then place its migration after upstream's newest one."""
import hashlib
import json
import pathlib
import subprocess
import sys
import uuid

root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path(sys.argv[1]).resolve()
baseline = json.loads((root / 'claude-code-baseline.json').read_text(encoding='utf-8'))

subprocess.run([sys.executable, str(root / 'scripts/prepare.py'), str(source)], check=True)
patch = root / 'patches/claude-code-server.patch'
digest = hashlib.sha256(patch.read_bytes()).hexdigest()
if digest != baseline['patchSha256']:
    raise SystemExit('Candidate patch differs from the recorded, validated source.')
subprocess.run(['git', '-C', str(source), 'apply', '--check', str(patch)], check=True)
subprocess.run(['git', '-C', str(source), 'apply', str(patch)], check=True)

# drizzle runs only migrations newer than the database's latest timestamp. Taking the
# next millisecond after upstream, rather than the build time, keeps later upstream
# migrations from being skipped. Renumbering re-runs the SQL, which is idempotent.
migrations = source / 'packages/database/migrations'
meta = migrations / 'meta'
journal_path = meta / '_journal.json'
journal = json.loads(journal_path.read_text(encoding='utf-8'))
last = journal['entries'][-1]
index = last['idx'] + 1
tag = f'{index:04d}_claude_code_server_backend'

snapshot = json.loads((meta / f"{last['idx']:04d}_snapshot.json").read_text(encoding='utf-8'))
tables = json.loads((root / 'patches/claude-code-tables.json').read_text(encoding='utf-8'))
if tables.keys() & snapshot['tables'].keys():
    raise SystemExit('Upstream now defines a Claude Code table. Review before publishing.')
snapshot['prevId'] = snapshot['id']
snapshot['id'] = str(uuid.uuid5(uuid.NAMESPACE_OID, f"{snapshot['prevId']}:{digest}"))
snapshot['tables'] = dict(sorted({**snapshot['tables'], **tables}.items()))
(meta / f'{index:04d}_snapshot.json').write_text(
    json.dumps(snapshot, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')
(migrations / f'{tag}.sql').write_bytes((root / 'patches/claude-code-migration.sql').read_bytes())
journal['entries'].append({
    'idx': index, 'version': last['version'], 'when': last['when'] + 1, 'tag': tag,
    'breakpoints': True,
})
journal_path.write_text(json.dumps(journal, indent=2, ensure_ascii=False) + '\n',
                        encoding='utf-8', newline='\n')
print(f'Applied Claude Code candidate SHA256 {digest} with migration {tag}')
