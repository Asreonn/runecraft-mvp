#!/usr/bin/env bash
# Pull RuneCraft UI texture SHEETS exported from Penpot and cut them into assets/ui/*.png.
# Rendering every "rcui / <name>" board on its own is slow in the plugin (~5 s each), so a whole kit board is
# exported once at 2x with a transparent background and uploaded as media "rcuisheet__<kit>". The board layout
# (piece name, x, y, w, h in 1x design px relative to the kit) is saved next to it as ui_design/sheets/<kit>.json.
#   ui_design/pull_penpot_sheets.sh <kit> [out_dir]      e.g. kit5, runes4
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$1"
OUT="${2:-assets/ui}"
SHEET="ui_design/sheets/$KIT.png"
media=$(docker exec penpot-penpot-postgres-1 psql -U penpot -d penpot -At -c \
  "select media_id from file_media_object where name = 'rcuisheet__$KIT' order by created_at desc limit 1")
[ -z "$media" ] && { echo "no sheet rcuisheet__$KIT in Penpot"; exit 1; }
hex="${media//-/}"
docker cp -q "penpot-penpot-backend-1:/opt/data/assets/${hex:0:2}/${hex:2:2}/${hex:4}" "$SHEET"
python3 - "$SHEET" "ui_design/sheets/$KIT.json" "$OUT" <<'EOF'
import json, subprocess, sys
sheet, layout, out = sys.argv[1:]
n = 0
for p in json.load(open(layout)):
    geo = "%dx%d+%d+%d" % (p["w"] * 2, p["h"] * 2, p["x"] * 2, p["y"] * 2)
    subprocess.run(["magick", sheet, "-crop", geo, "+repage", "%s/%s.png" % (out, p["n"])], check=True)
    n += 1
print("cut %d textures from %s into %s" % (n, sheet, out))
EOF
