#!/usr/bin/env python3
"""Apply the AI comments patch after the Claude Code one, then place its migration last."""
import hashlib
import json
import pathlib
import subprocess
import sys
import uuid

root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path(sys.argv[1]).resolve()
patch = root / 'patches/ai-comments.patch'
digest = hashlib.sha256(patch.read_bytes()).hexdigest()
# The upstream commit the patch was cut against. Its blobs let a nearby upstream edit merge
# three-way instead of stopping the build; a real conflict still fails here.
BASE = '7134c0bba047e79c69d8844c1578fb868c872d4f'
subprocess.run(['git', '-C', str(source), 'fetch', '--depth', '1', 'origin', BASE], check=True)
subprocess.run(['git', '-C', str(source), 'apply', '--3way', str(patch)], check=True)

# Same placement rule as the Claude Code migration: one millisecond after the
# newest entry, so drizzle never skips it. The SQL is idempotent.
migrations = source / 'packages/database/migrations'
meta = migrations / 'meta'
journal_path = meta / '_journal.json'
journal = json.loads(journal_path.read_text(encoding='utf-8'))
last = journal['entries'][-1]
index = last['idx'] + 1
tag = f'{index:04d}_document_ai_comments'

snapshot = json.loads((meta / f"{last['idx']:04d}_snapshot.json").read_text(encoding='utf-8'))
tables = json.loads((root / 'patches/ai-comments-tables.json').read_text(encoding='utf-8'))
if tables.keys() & snapshot['tables'].keys():
    raise SystemExit('Upstream now defines an AI comments table. Review before publishing.')
snapshot['prevId'] = snapshot['id']
snapshot['id'] = str(uuid.uuid5(uuid.NAMESPACE_OID, f"{snapshot['prevId']}:{digest}"))
snapshot['tables'] = dict(sorted({**snapshot['tables'], **tables}.items()))
(meta / f'{index:04d}_snapshot.json').write_text(
    json.dumps(snapshot, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')
(migrations / f'{tag}.sql').write_bytes((root / 'patches/ai-comments-migration.sql').read_bytes())
journal['entries'].append({
    'idx': index, 'version': last['version'], 'when': last['when'] + 1, 'tag': tag,
    'breakpoints': True,
})
journal_path.write_text(json.dumps(journal, indent=2, ensure_ascii=False) + '\n',
                        encoding='utf-8', newline='\n')
print(f'Applied AI comments patch SHA256 {digest} with migration {tag}')
