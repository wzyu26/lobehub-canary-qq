# LobeHub canary with QQ mentions fixed

Tracks `lobehub/lobehub:canary` source and applies the reviewed code and regression-test hunks from [PR #18187](https://github.com/lobehub/lobehub/pull/18187), pinned to PR head `8d48bcdbd746aa036f0fde9f1ba934cc8ac26a14`.

Also includes a local QQ passive-reply fix: adapter replies carry the incoming `msg_id` and increment `msg_seq`, so group replies are not rejected as unauthorized proactive messages (`40034105`). Context is isolated per bot/thread, bounded, and expires after five minutes. The build verifies the new regression suite fails before this patch and passes afterward. This covers the in-process Chat SDK reply path used by this deployment; separate asynchronous callback or proactive tool-send paths are not covered by this patch.

- Checks upstream every six hours (00:23, 06:23, 12:23, 18:23 UTC); unchanged commits are skipped.
- Builds `linux/amd64` using the upstream Dockerfile, with the QQ adapter test suite as a required build step.
- Publishes `ghcr.io/wzyu26/lobehub-canary-qq:canary` only after tests, image build and a basic runtime/filesystem smoke check succeed.
- Keeps versioned tags and records the upstream commit and image digest in `last-build.json` for traceability.
- If the exact patch is already upstream, it is skipped. Conflicting or differently implemented upstream changes stop the build for review.
- Successful build records also keep this tracking repository active. GitHub may disable scheduled workflows after 60 days without repository activity; check Actions if upstream/builds stop for an extended period.
- Actions never receives deployment SSH keys, database passwords or the production `.env`.

The image is built from public upstream source. Upstream licensing continues to apply. Dependency resolution follows upstream's Dockerfile; this is not a bit-for-bit reproducible build.

## Deployment

Set only the application's Compose image to `ghcr.io/wzyu26/lobehub-canary-qq:canary`; keep the existing environment, networking and dependencies. The GHCR package must be public for anonymous pulls, or the server must have its own read-only registry login.

Pull and recreate only the application service. Back up the database and Compose configuration before upgrading. A previous image alone cannot undo database migrations. A real QQ group mention and private message are still required to confirm end-to-end behavior; the smoke check does not contact QQ or the production database.

Builds are automatic; production deployment remains an explicit update operation.
