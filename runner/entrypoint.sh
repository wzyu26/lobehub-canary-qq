#!/bin/bash
# Registers once, on the first start of a fresh volume; the volume keeps the identity after that.
set -euo pipefail
cd /runner

if [[ ! -f .runner ]]; then
  : "${RUNNER_TOKEN:?Run register.ps1 with a fresh registration token}"
  ./config.sh --unattended --replace \
    --url "$REPO_URL" --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" --labels lobehub-build --work _work
fi
unset RUNNER_TOKEN

exec ./run.sh
