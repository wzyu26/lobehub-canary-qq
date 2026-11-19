#!/usr/bin/env python3
"""Prepare the upstream tree: QQ test gate in the Dockerfile, trimmed inbox tools."""
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).resolve()
qq = source / 'packages/chat-adapter-qq/src'
# Our QQ mention and passive-reply patches landed upstream in lobehub/lobehub#22921
# (isMention from the event type, msg_id/msg_seq passive window, active fallback).
# Stop if that code disappears, rather than ship without the fix.
if not (qq / 'passive.ts').exists() or 'isMention' not in (qq / 'adapter.ts').read_text(encoding='utf-8'):
    raise SystemExit('Upstream QQ adapter lost the mention/passive-reply fix. Review before publishing.')
QQ_TESTS = 'src/adapter.test.ts src/adapter.mention.test.ts src/adapter.passive.test.ts src/passive.test.ts'

# Use the upstream Dockerfile, adding a mandatory QQ test gate before application build.
dockerfile = (source / 'Dockerfile').read_text(encoding='utf-8')
anchor = 'RUN pnpm exec tsx scripts/dockerPrebuild.mts'
if dockerfile.count(anchor) != 1:
    raise SystemExit('Upstream Dockerfile changed: review test insertion point.')
test = f'''RUN set -eu; cd packages/chat-adapter-qq; \\
    pnpm exec vitest run --config vitest.config.mts {QQ_TESTS}
'''
(source / 'Dockerfile.qq').write_text(dockerfile.replace(anchor, test + anchor), encoding='utf-8')

# The default (inbox) assistant also mounts the standalone User Interaction tool, whose
# askUserQuestion is already part of the always-on Lobe Agent tool (same card UI). Drop
# the duplicate so every inbox turn stops paying for its manifest and system prompt.
# This is a token saving only, so upstream drift warns instead of stopping the build.
inbox = source / 'packages/builtin-agents/src/agents/inbox/index.ts'
text = inbox.read_text(encoding='utf-8')
# Upstream later dropped AgentDocumentsIdentifier from this list; accept both shapes.
pluginVariants = {
    'plugins: [AgentDocumentsIdentifier, UserInteractionIdentifier, ...(ctx.plugins || [])],':
        'plugins: [AgentDocumentsIdentifier, ...(ctx.plugins || [])],',
    'plugins: [UserInteractionIdentifier, ...(ctx.plugins || [])],':
        'plugins: [...(ctx.plugins || [])],',
}
plugins = next((p for p in pluginVariants if text.count(p) == 1), None)
importLine = "import { UserInteractionIdentifier } from '@lobechat/builtin-tool-user-interaction';\n"
if plugins and text.count(importLine) == 1 and text.count('UserInteractionIdentifier') == 2:
    text = text.replace(plugins, pluginVariants[plugins])
    inbox.write_text(text.replace(importLine, ''), encoding='utf-8', newline='\n')
    print('Removed the duplicate User Interaction tool from the inbox assistant')
elif 'UserInteractionIdentifier' not in text:
    print('Inbox assistant already omits User Interaction')
else:
    print('WARNING: inbox assistant changed upstream; User Interaction left in place')
