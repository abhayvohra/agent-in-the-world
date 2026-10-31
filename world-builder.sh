#!/usr/bin/env bash
# =============================================================================
#  world-builder.sh  —  Agent in the World · Agentic (InterEmbodied Labs)
#
#  Builds a "world": a tree of folders (rooms). Every room holds a clue.txt
#  with ONE number — how many moves (cd one step up or down) separate that
#  room from the destination. The destination's clue reads 0.
#
#  The last rooms on the way to the destination can be named after a haiku
#  (--trail "dream hopes egress" builds .../dream/hopes/egress). agent.sh picks
#  the haiku from .haiku.md and passes its trail here. The last word of the trail
#  is the destination.
#
#  You normally don't run this yourself: agent.sh calls it when it needs a
#  world. It is a separate file because the world and the agent are made by
#  different hands — read it to see how the environment was designed.
#
#  Usage (on its own):
#     bash world-builder.sh                 # level 1, random world
#     bash world-builder.sh --seed 42       # same seed  -> same world
#     bash world-builder.sh --level 2       # some clues are hidden (.clue.txt)
#     bash world-builder.sh --level 3       # ...and some dead-end rooms are locked
#     bash world-builder.sh --depth 5 --branching 3
#     bash world-builder.sh --trail "dream hopes egress"   # the rooms to the destination
#
#  Environment variables it respects:
#     WORLD   where to build the world (default: ./world)
#
#  Written for bash 3.2+ (the bash that ships with macOS), Linux, WSL and
#  Git Bash on Windows (on Git Bash, level-3 locks have no effect).
# =============================================================================

set -u

WORLD="${WORLD:-./world}"
SEED=""
LEVEL=1
DEPTH=4
BRANCHING=3
TRAIL_IN="dream hopes egress"   # the rooms on the way, outermost first; the last is the destination

while [ $# -gt 0 ]; do
  case "$1" in
    --seed)      SEED="$2"; shift 2 ;;
    --level)     LEVEL="$2"; shift 2 ;;
    --depth)     DEPTH="$2"; shift 2 ;;
    --branching) BRANCHING="$2"; shift 2 ;;
    --trail)     TRAIL_IN="$2"; shift 2 ;;
    -h|--help)   awk 'NR>2 && /^# =+$/ {exit} NR>2 {print}' "$0"; exit 0 ;;
    *) echo "Unknown option: $1  (try --help)"; exit 1 ;;
  esac
done

# --- 1. Seed the random number generator ------------------------------------
# A seed makes "random" repeatable. Same seed, same world — for everyone.
# We use our own tiny generator (a "linear congruential generator") instead of
# $RANDOM, so the same seed builds the same world on every computer and bash.
if [ -z "$SEED" ]; then SEED=$(( $(date +%s) % 100000 )); fi
STATE=$SEED
roll() {            # roll N  ->  sets R to a pseudo-random number 0..N-1
  STATE=$(( (STATE * 1103515245 + 12345) % 2147483648 ))
  R=$(( (STATE / 65536) % $1 ))
}

# --- 2. Clear any previous world (safely) ------------------------------------
# We only delete a folder that WE built: it must contain our marker file.
# (Lesson: agents that can run `rm -rf` need guard rails.)
# (A half-deleted world may have lost its marker, so we also accept a folder
#  that holds nothing but rooms, clues and a map.)
ours() {
  [ -f "$1/.world" ] && return 0
  [ -z "$(find "$1" -type f ! -name clue.txt ! -name .clue.txt ! -name map.txt 2>/dev/null)" ]
}
if [ -e "$WORLD" ]; then
  chmod -R u+rwx "$WORLD" 2>/dev/null           # unlock level-3 rooms so we can look inside
  if ours "$WORLD"; then
    rm -rf "$WORLD"
  else
    echo "Refusing to overwrite '$WORLD': it exists but was not built by world-builder."
    exit 1
  fi
fi
mkdir -p "$WORLD" || exit 1

# --- 3. Grow the tree ----------------------------------------------------------
NAMES="archive attic banyan bazaar bridge burrow canal cellar chapel cistern
courtyard delta dune estuary fern forge garden glacier grotto harbour hive
kiln ladder lantern library loom marsh meadow mill moss nest oasis orchard
quarry reef river sanctum spring stair steppe stupa terrace tunnel vault well"
set -- $NAMES; NAME_COUNT=$#
# The trail, destination first. Its names are reserved, so no other room takes them.
TRAIL=$(echo "$TRAIL_IN" | awk '{for (j=NF; j>=1; j--) printf "%s ", $j}')
USED=" $TRAIL "  # every room gets a name no other room has, so maps are readable
pick_name() {
  local tries=0
  set -- $NAMES
  while :; do
    roll "$NAME_COUNT"; eval "NAME=\${$(( R + 1 ))}"
    [ "$tries" -ge 40 ] && NAME="$NAME-$R$tries"          # ran out of fresh names
    case "$USED" in *" $NAME "*) tries=$(( tries + 1 )) ;; *) break ;; esac
  done
  USED="$USED$NAME "
}

ROOMS=""        # newline-separated list of room paths, relative to the world root
add_room() { ROOMS="$ROOMS$1
"; }

grow() {            # grow <relative-path> <depth>
  local here="$1" depth="$2" kids i name child
  [ "$depth" -ge "$DEPTH" ] && return
  if [ "$depth" -lt 2 ]; then roll "$BRANCHING"; kids=$(( R + 1 ))
  else                        roll $(( BRANCHING + 1 )); kids=$R; fi
  [ "$depth" -eq 0 ] && [ "$kids" -lt 2 ] && kids=2
  i=0
  while [ "$i" -lt "$kids" ]; do
    pick_name; name=$NAME
    if [ -z "$here" ]; then child="$name"; else child="$here/$name"; fi
    mkdir "$WORLD/$child"
    add_room "$child"
    grow "$child" $(( depth + 1 ))
    i=$(( i + 1 ))
  done
}
grow "" 0

# depth of a relative path = number of path components
depth_of() { [ -z "$1" ] && { echo 0; return; }; echo "$1" | awk -F/ '{print NF}'; }

# --- 4. Choose the destination: a dead-end room, 3 steps deep if possible ----------
dead_ends() {       # dead_ends <minimum depth>  ->  every dead-end room at least that deep
  local r d has_kids out=""
  for r in $ROOMS; do
    d=$(depth_of "$r")
    has_kids=$(find "$WORLD/$r" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ "$d" -ge "$1" ] && [ -z "$has_kids" ]; then out="$out $r"; fi
  done
  echo "$out"
}
CANDIDATES=$(dead_ends 3)
[ -z "$CANDIDATES" ] && CANDIDATES=$(dead_ends 2)
set -- $CANDIDATES
if [ $# -eq 0 ]; then echo "World too small — try a bigger --depth."; exit 1; fi
roll $#; eval "DEST=\${$(( R + 1 ))}"

# --- 4b. Lay the haiku's trail --------------------------------------------------
# Rename the destination and the rooms just above it, so the player who remembers
# the haiku can follow, e.g.  dream -> hopes -> egress. (A small world gets a shorter trail.)
IFS=/ read -r -a PARTS <<< "$DEST"
N=${#PARTS[@]}
head_path() {       # head_path <m>  ->  the first m folders of DEST, joined with /
  local out="" j=0
  while [ "$j" -lt "$1" ]; do out="${out:+$out/}${PARTS[$j]}"; j=$(( j + 1 )); done
  echo "$out"
}
set -- $TRAIL
K=$#; [ "$N" -lt "$K" ] && K=$N         # a small world gets a shorter trail
i=$N
for word in "$@"; do                    # work upwards from the destination
  [ "$i" -le $(( N - K )) ] && break
  above=$(head_path $(( i - 1 )))
  mv "$WORLD/$(head_path "$i")" "$WORLD/${above:+$above/}$word"
  i=$(( i - 1 ))
done
DEST=$(head_path $(( N - K )))
for word in $(echo "$TRAIL" | awk -v k="$K" '{for (j=k; j>=1; j--) printf "%s ", $j}'); do
  DEST="${DEST:+$DEST/}$word"
done
ROOMS=$(cd "$WORLD" && find . -mindepth 1 -type d | sed 's|^\./||' | sort)   # names changed, so list them again

# --- 5. Write a clue in every room ---------------------------------------------
# Distance in a tree = steps up to the shared ancestor + steps down from it.
distance() {        # distance <pathA> <pathB>
  awk -v a="$1" -v b="$2" 'BEGIN{
    na = (a=="") ? 0 : split(a, A, "/"); nb = (b=="") ? 0 : split(b, B, "/");
    c = 0; while (c < na && c < nb && A[c+1] == B[c+1]) c++;
    print (na - c) + (nb - c) }'
}
echo "$(distance "" "$DEST")" > "$WORLD/clue.txt"
for r in $ROOMS; do distance "$r" "$DEST" > "$WORLD/$r/clue.txt"; done

# --- 6. Draw the map (names only — the map does NOT mark the destination) -----
draw() {            # draw <relative-path> <prefix>
  local here="$1" prefix="$2" kids n i k
  if [ -z "$here" ]; then kids=$(cd "$WORLD" && ls -d */ 2>/dev/null)
  else kids=$(cd "$WORLD/$here" && ls -d */ 2>/dev/null); fi
  set -- $kids; n=$#; i=0
  for k in $kids; do
    k="${k%/}"; i=$(( i + 1 ))
    if [ "$i" -eq "$n" ]; then echo "${prefix}└── $k"; next="${prefix}    "
    else                      echo "${prefix}├── $k"; next="${prefix}│   "; fi
    if [ -z "$here" ]; then draw "$k" "$next"; else draw "$here/$k" "$next"; fi
  done
}
{
  echo "MAP OF THE WORLD  (every name is a room; rooms inside rooms are one step apart)"
  echo
  echo "world"
  draw "" ""
} > "$WORLD/map.txt"

# --- 7. Level 2: hide some clues ------------------------------------------------
# A file whose name starts with a dot is "hidden": plain `ls` skips it, `ls -a` shows it.
HIDDEN=0
if [ "$LEVEL" -ge 2 ]; then
  for r in $ROOMS; do
    roll 3
    if [ "$R" -eq 0 ]; then
      mv "$WORLD/$r/clue.txt" "$WORLD/$r/.clue.txt"; HIDDEN=$(( HIDDEN + 1 ))
    fi
  done
fi

# --- 8. Level 3: lock some dead ends that are NOT on the way ---------------------
# chmod 000 removes read/write/enter permission. The kernel will refuse `cd`.
LOCKED=0
if [ "$LEVEL" -ge 3 ]; then
  for r in $ROOMS; do
    [ "$r" = "$DEST" ] && continue
    case "$DEST/" in "$r"/*) continue ;; esac              # an ancestor of DEST
    has_kids=$(find "$WORLD/$r" -mindepth 1 -maxdepth 1 -type d | head -1)
    roll 2
    if [ -z "$has_kids" ] && [ "$R" -eq 0 ]; then
      chmod 000 "$WORLD/$r"; LOCKED=$(( LOCKED + 1 ))
    fi
  done
fi

# --- 9. Marker + summary -----------------------------------------------------------
echo "built by world-builder.sh  seed=$SEED level=$LEVEL" > "$WORLD/.world"
COUNT=$(echo "$ROOMS" | grep -c .)
echo "World built in '$WORLD'  ·  seed $SEED  ·  level $LEVEL"
echo "  $COUNT rooms  ·  starting distance $(cat "$WORLD/clue.txt")  ·  $HIDDEN hidden clues  ·  $LOCKED locked rooms"
echo "  Same world again:  --seed $SEED --level $LEVEL"
