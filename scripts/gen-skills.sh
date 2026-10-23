#!/usr/bin/env bash
# gen-skills.sh — génère assets/skills.svg depuis skills.conf
# usage : ./scripts/gen-skills.sh [skills.conf] [sortie.svg]
set -euo pipefail

CONF="${1:-skills.conf}"
OUT="${2:-assets/skills.svg}"

W=1200
PAD=32
COLS=6
TILE_W=178
TILE_H=58
GAP=12
HEAD_H=96
SEC_H=34

[ -f "$CONF" ] || { echo "error: $CONF introuvable" >&2; exit 1; }

xml_escape() {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	printf '%s' "$s"
}

color_of() {
	case "$1" in
		up)      echo "#4ade80" ;;
		syncing) echo "#fbbf24" ;;
		planned) echo "#64748b" ;;
		*)       echo "error: statut inconnu '$1'" >&2; exit 1 ;;
	esac
}

# coupe un texte trop long pour tenir dans une tuile
clip() {
	local s="$1" max="$2"
	if [ "${#s}" -gt "$max" ]; then
		printf '%s…' "${s:0:$((max - 1))}"
	else
		printf '%s' "$s"
	fi
}

label_of() {
	case "$1" in
		up)      echo "UP" ;;
		syncing) echo "SYNCING" ;;
		planned) echo "PLANNED" ;;
	esac
}

# lignes utiles uniquement (pas de commentaires ni de vides)
LINES=$(grep -vE '^[[:space:]]*(#|$)' "$CONF")

n_up=$(printf '%s\n' "$LINES" | awk -F'|' '$3=="up"' | wc -l | tr -d ' ')
n_sync=$(printf '%s\n' "$LINES" | awk -F'|' '$3=="syncing"' | wc -l | tr -d ' ')
n_plan=$(printf '%s\n' "$LINES" | awk -F'|' '$3=="planned"' | wc -l | tr -d ' ')
sections=$(printf '%s\n' "$LINES" | awk -F'|' '!seen[$1]++ {print $1}')

# hauteur totale : en-tête + pour chaque section, son titre + ses rangées de tuiles
H=$HEAD_H
for s in $sections; do
	n=$(printf '%s\n' "$LINES" | awk -F'|' -v s="$s" '$1==s' | wc -l | tr -d ' ')
	rows=$(( (n + COLS - 1) / COLS ))
	H=$(( H + SEC_H + rows * (TILE_H + GAP) + 8 ))
done
H=$(( H + PAD - 8 ))

mkdir -p "$(dirname "$OUT")"
{
	cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <style>
    .mono { font-family: 'JetBrains Mono','Fira Code',Menlo,Consolas,monospace; }
    .tile { fill: #0d1820; stroke: #1b2a36; stroke-width: 1; }
    .name { fill: #e2e8f0; font-size: 14px; font-weight: 600; }
    .note { fill: #64748b; font-size: 11px; }
    .sec  { fill: #22d3ee; font-size: 13px; letter-spacing: 1px; }
    .pulse { animation: pulse 1.6s ease-in-out infinite; }
    @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .25; } }
  </style>
  <rect width="$W" height="$H" rx="14" fill="#0a0f14"/>
  <g class="mono">
    <circle cx="$((PAD + 6))" cy="40" r="5" fill="#f87171"/>
    <circle cx="$((PAD + 24))" cy="40" r="5" fill="#fbbf24"/>
    <circle cx="$((PAD + 42))" cy="40" r="5" fill="#4ade80"/>
    <text x="$((PAD + 64))" y="45" font-size="15" fill="#9fb3c2">skills.monitoring <tspan fill="#64748b">— dashboard</tspan></text>
    <text x="$((W - PAD))" y="45" font-size="13" text-anchor="end" fill="#64748b"><tspan fill="#4ade80">● $n_up up</tspan>   <tspan fill="#fbbf24">● $n_sync syncing</tspan>   <tspan fill="#94a3b8">● $n_plan planned</tspan></text>
    <line x1="$PAD" y1="66" x2="$((W - PAD))" y2="66" stroke="#1b2a36"/>
EOF

	y=$HEAD_H
	for s in $sections; do
		printf '    <text class="sec" x="%d" y="%d">▸ %s</text>\n' "$PAD" "$((y + 14))" "$(xml_escape "$s")"
		y=$(( y + SEC_H ))
		i=0
		while IFS='|' read -r _ name status note; do
			col=$(( i % COLS ))
			row=$(( i / COLS ))
			x=$(( PAD + col * (TILE_W + GAP) ))
			ty=$(( y + row * (TILE_H + GAP) ))
			c=$(color_of "$status")
			cls=""
			[ "$status" = "syncing" ] && cls=' class="pulse"'
			cat <<EOF
    <rect class="tile" x="$x" y="$ty" width="$TILE_W" height="$TILE_H" rx="8"/>
    <rect x="$x" y="$ty" width="3" height="$TILE_H" rx="1.5" fill="$c"/>
    <circle$cls cx="$((x + TILE_W - 16))" cy="$((ty + 18))" r="4" fill="$c"/>
    <text class="name" x="$((x + 14))" y="$((ty + 23))">$(xml_escape "$(clip "$name" 15)")</text>
    <text class="note" x="$((x + 14))" y="$((ty + 43))"><tspan fill="$c">$(label_of "$status")</tspan> · $(xml_escape "$(clip "$note" $(( 19 - ${#status} )))")</text>
EOF
			i=$(( i + 1 ))
		done <<EOF2
$(printf '%s\n' "$LINES" | awk -F'|' -v s="$s" '$1==s')
EOF2
		rows=$(( (i + COLS - 1) / COLS ))
		y=$(( y + rows * (TILE_H + GAP) + 8 ))
	done

	echo '  </g>'
	echo '</svg>'
} > "$OUT"

echo "ok: $OUT ($n_up up, $n_sync syncing, $n_plan planned)"
