#!/usr/bin/env bash
# Pull RuneCraft UI textures exported from Penpot into the game.
# In Penpot (page "HUD v3 · Stone"), every board named "rcui / <name>" is exported at 2x and uploaded as a
# file media object "rcui__<name>". This script reads the newest object per name from Penpot's database
# (read-only SELECT) and copies the stored PNG out of the backend's asset storage.
#   ui_design/pull_penpot_exports.sh [out_dir]      (default: assets/ui)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-assets/ui}"
mkdir -p "$OUT"
n=0
while IFS='|' read -r name media; do
  [ -z "$name" ] && continue
  hex="${media//-/}"
  docker cp -q "penpot-penpot-backend-1:/opt/data/assets/${hex:0:2}/${hex:2:2}/${hex:4}" "$OUT/${name#rcui__}.png"
  n=$((n + 1))
done < <(docker exec penpot-penpot-postgres-1 psql -U penpot -d penpot -At -c \
  "select distinct on (name) name, media_id from file_media_object where name like 'rcui\_\_%' order by name, created_at desc")
echo "pulled $n textures into $OUT"
