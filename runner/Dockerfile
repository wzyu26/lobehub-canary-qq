# A self-hosted GitHub Actions runner that drives the host Docker daemon for
# `docker run`/`docker pull` and a shared BuildKit daemon for builds.
FROM ubuntu:24.04

ARG RUNNER_VERSION=2.338.2
ARG RUNNER_SHA256=baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40

ENV RUNNER_ALLOW_RUNASROOT=1

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl git jq python3; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    echo 'deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable' \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin; \
    mkdir /runner; \
    curl -fsSL -o /tmp/runner.tar.gz \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"; \
    echo "${RUNNER_SHA256}  /tmp/runner.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/runner.tar.gz -C /runner; \
    /runner/bin/installdependencies.sh; \
    rm -rf /tmp/runner.tar.gz /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
