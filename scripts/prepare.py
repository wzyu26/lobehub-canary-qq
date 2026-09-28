#!/usr/bin/env python3
"""Apply pinned QQ fixes; stop on upstream drift rather than guessing."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = pathlib.Path(sys.argv[1]).resolve()
for name in ('qq-routing.patch', 'qq-tests.patch', 'qq-passive-tests.patch', 'qq-passive-reply.patch'):
    patch = root / 'patches' / name
    def check(*args):
        return subprocess.run(['git', '-C', str(source), 'apply', *args, str(patch)],
                              capture_output=True, text=True)
    if check('--check').returncode == 0:
        if name == 'qq-passive-reply.patch':
            (source / 'scripts/qq-adapter-before.ts').write_text(
                (source / 'packages/chat-adapter-qq/src/adapter.ts').read_text(encoding='utf-8'), encoding='utf-8')
        subprocess.run(['git', '-C', str(source), 'apply', str(patch)], check=True)
        print(f'Applied {name}')
    elif check('--reverse', '--check').returncode == 0:
        print(f'Already upstream: {name}')
    else:
        raise SystemExit(f'{name} no longer applies cleanly. Review upstream before publishing.')

# Use the upstream Dockerfile, adding a mandatory test gate before application build.
dockerfile = (source / 'Dockerfile').read_text(encoding='utf-8')
anchor = 'RUN pnpm exec tsx scripts/dockerPrebuild.mts'
if dockerfile.count(anchor) != 1:
    raise SystemExit('Upstream Dockerfile changed: review test insertion point.')
test = '''RUN set -eu; cd packages/chat-adapter-qq; \\
    if [ -f ../../scripts/qq-adapter-before.ts ]; then \\
      cp src/adapter.ts /tmp/qq-adapter-fixed.ts; \\
      cp ../../scripts/qq-adapter-before.ts src/adapter.ts; \\
      if pnpm exec vitest run --config vitest.config.mts src/passive-reply.test.ts; then \\
        echo 'Regression gate failed: unpatched adapter unexpectedly passed'; exit 1; \\
      fi; \\
      cp /tmp/qq-adapter-fixed.ts src/adapter.ts; \\
    fi; \\
    pnpm exec vitest run --config vitest.config.mts src/adapter.test.ts src/passive-reply.test.ts
'''
(source / 'Dockerfile.qq').write_text(dockerfile.replace(anchor, test + anchor), encoding='utf-8')
