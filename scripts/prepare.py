#!/usr/bin/env python3
"""Apply reviewed PR #18187 hunks; stop on upstream drift rather than guessing."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path(sys.argv[1]).resolve()
for name in ('qq-routing.patch', 'qq-tests.patch'):
    patch = root / 'patches' / name
    def check(*args):
        return subprocess.run(['git', '-C', str(source), 'apply', *args, str(patch)],
                              capture_output=True, text=True)
    if check('--check').returncode == 0:
        subprocess.run(['git', '-C', str(source), 'apply', str(patch)], check=True)
        print(f'Applied {name}')
    elif check('--reverse', '--check').returncode == 0:
        print(f'Already upstream: {name}')
    else:
        raise SystemExit(f'{name} no longer applies cleanly. Review upstream before publishing.')

# Use the upstream Dockerfile, adding a mandatory test gate before application build.
dockerfile = (source / 'Dockerfile').read_text()
anchor = 'RUN pnpm exec tsx scripts/dockerPrebuild.mts'
if dockerfile.count(anchor) != 1:
    raise SystemExit('Upstream Dockerfile changed: review test insertion point.')
test = 'RUN cd packages/chat-adapter-qq && pnpm exec vitest run --config vitest.config.mts src/adapter.test.ts\n'
(source / 'Dockerfile.qq').write_text(dockerfile.replace(anchor, test + anchor))
