# Realigning the patches with a new upstream canary

`claude-code-candidate.yml` applies two patches to upstream `lobehub/lobehub` `canary`:

1. `scripts/prepare-claude-code.py` runs `scripts/prepare.py` (Dockerfile QQ gate, inbox
   tool trim), then `git apply --3way patches/claude-code-server.patch`, then adds the
   Claude Code migration. The patch was cut against `upstream` in
   `claude-code-baseline.json` **after** `prepare.py` ran there, and its SHA-256 must equal
   `patchSha256` in the same file.
2. `scripts/prepare-ai-comments.py` then applies `patches/ai-comments.patch` on top
   (its 3-way base commit is the `BASE` constant in that script) and adds its migration.

When upstream moves, either step can stop with a conflict. This is how to cut new patches.
`auto-rebase.yml` hands this file to Claude Code in Actions; people can follow it too.

## Layout used below

- `$CFG`: this repository (patches, scripts, baseline).
- `$SRC`: a clone of `https://github.com/lobehub/lobehub.git` with history
  (`git clone --filter=blob:none` is enough).
- `OLD` = `jq -r .upstream $CFG/claude-code-baseline.json`, `NEW` = target canary commit.

## Claude Code patch

```bash
cd $SRC
git config user.name rebase && git config user.email rebase@localhost
# 1. Rebuild the patched tree on its own base. This must apply cleanly.
git checkout -q -B old "$OLD"
python3 $CFG/scripts/prepare.py . && git add -A && git commit -qm "prepare (old)"
git apply --3way $CFG/patches/claude-code-server.patch && git add -A && git commit -qm "claude code"
# 2. Prepare the new base the same way.
git checkout -q -B new "$NEW"
python3 $CFG/scripts/prepare.py . && git add -A && git commit -qm "prepare (new)"
NEWBASE=$(git rev-parse HEAD)
# 3. Carry the patch over and resolve conflicts.
git cherry-pick old          # fix conflicts, git add, git cherry-pick --continue
# 4. Cut the new patch and record it.
git diff --binary "$NEWBASE" HEAD > $CFG/patches/claude-code-server.patch
```

Then in `$CFG/claude-code-baseline.json` set `upstream` to `NEW`, `patchSha256` to
`sha256sum patches/claude-code-server.patch`, and `sourceRevision` to a one-line note
(`auto-rebased <date> onto upstream <short NEW>`). Keep the JSON formatting.

If `prepare.py` itself fails on `NEW` (for example upstream changed the Dockerfile line it
anchors on), fix `prepare.py` first, keeping its intent, and start again.

## AI comments patch

Only if it no longer applies. Continuing on branch `new` after step 3:

```bash
CC=$(git rev-parse HEAD)
git apply --3way $CFG/patches/ai-comments.patch   # resolve conflicts in the files
git add -A && git commit -qm "ai comments"
git diff --binary "$CC" HEAD > $CFG/patches/ai-comments.patch
```

Then set `BASE` in `scripts/prepare-ai-comments.py` to `NEW`.

## Resolving conflicts

- Keep upstream's change **and** the patch's intent. Upstream refactors in the agent runtime
  (`hetero.ts`, `AgentRuntimeService`, gateway client, model pickers) are the usual cause:
  when upstream moved or renamed something, move the patch's addition to the new place.
- If upstream now does what a hunk did, drop the hunk.
- Never touch the migration SQL files or `patches/*-tables.json`; never edit tests to make
  them pass by weakening them.
- Don't change files outside `patches/`, `claude-code-baseline.json`,
  `scripts/prepare*.py` and this doc.

## Checking the result

1. A clean check, exactly as CI does it, must pass:

   ```bash
   git -C $SRC worktree add --detach /tmp/check "$NEW"
   python3 $CFG/scripts/prepare-claude-code.py /tmp/check
   python3 $CFG/scripts/prepare-ai-comments.py /tmp/check
   ```

2. In that tree, `pnpm install --no-frozen-lockfile` (via `corepack enable`), then
   `pnpm run type-check`, then the vitest files under the conflicted areas (the list is in
   the `validate` job of `claude-code-candidate.yml`). The full CI run after the push is
   the final gate.
