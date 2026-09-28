#!/usr/bin/env bash
# Run on the deployment host from its existing Compose directory.
set -Eeuo pipefail
umask 077
cd "$(dirname "$(readlink -f "$0")")"
exec 9>.update.lock
flock -n 9 || { echo 'Another update is running.'; exit 1; }

SERVICE=lobe
CONTAINER=lobehub
IMAGE=$(docker compose config --format json | jq -er --arg s "$SERVICE" '.services[$s].image')
case "$IMAGE" in
  ghcr.io/wzyu26/lobehub-canary-qq:canary) ;;
  *) echo "Unexpected image: $IMAGE; review Compose before updating."; exit 1 ;;
esac

echo "Pulling $IMAGE ..."
docker compose pull "$SERVICE"
old_id=$(docker inspect --format '{{.Image}}' "$CONTAINER")
new_id=$(docker image inspect --format '{{.Id}}' "$IMAGE")
if [[ "$old_id" == "$new_id" ]]; then
  echo 'Already running the latest successfully built image.'
  exit 0
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="backups/qq-canary-$stamp"
mkdir -p "$backup"
chmod 700 "$backup"
cp -p docker-compose.yml docker-compose.override.yml .env "$backup/"
cp -p "$0" "$backup/update.sh"
old_tag="lobehub-local-rollback:$stamp"
docker tag "$old_id" "$old_tag"
printf '%s\n' "$old_tag" > "$backup/previous-image.txt"
printf '%s\n' "$new_id" > "$backup/new-image-id.txt"
echo "Backing up PostgreSQL to $backup/postgres.sql.gz ..."
docker exec lobe-postgres pg_dumpall -U postgres | gzip > "$backup/postgres.sql.gz"
gzip -t "$backup/postgres.sql.gz"
test -s "$backup/postgres.sql.gz"

echo 'Recreating only the application service ...'
docker compose up -d --no-deps --pull never "$SERVICE"
deadline=$((SECONDS + 240))
ok=0
while (( SECONDS < deadline )); do
  running=$(docker inspect --format '{{.State.Running}}' "$CONTAINER")
  actual=$(docker inspect --format '{{.Image}}' "$CONTAINER")
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3210/ || true)
  if [[ "$running" == true && "$actual" == "$new_id" && "$code" =~ ^[23][0-9][0-9]$ ]]; then
    ok=$((ok + 1))
    if (( ok >= 3 )); then
      echo "Update verified. Backup and previous image: $backup"
      echo 'Verify one QQ group @ and one private message to confirm real bot behavior.'
      exit 0
    fi
  else
    ok=0
  fi
  sleep 5
done
echo "Application did not become ready. Backup: $backup; previous image: $old_tag" >&2
echo 'Do not blindly restore an old image after database migrations. Inspect the failure first.' >&2
exit 1
