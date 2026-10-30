#!/usr/bin/env bash
# =============================================================================
#  agent.sh  —  AGENT IN THE WORLD · Agentic (InterEmbodied Labs)
#
#  An agent wakes up in a world made of folders. Somewhere there is a room
#  whose clue reads 0. Every room's clue.txt says how many moves away it is.
#
#  One command, three ways to play:
#
#     bash agent.sh              YOU are the agent's brain. Type the commands.
#     bash agent.sh --auto       watch an agent that follows the clues on its own
#     bash agent.sh --random     watch an agent that wanders at random
#
#  World options (add to any of the above):
#     --new          build a fresh world instead of reusing the current one
#     --seed N       build the world with seed N (same seed = same world)
#     --level 2      some clues are hidden   (--level 3: some rooms are locked)
#     --fast         no pauses between the agent's steps
#     --help         show this text
#
#  Clean slate:
#     bash agent.sh --clean      delete the world, the agent's memory and your journal
#
#  Environment variables (change with  export NAME=value):
#     AGENT_SENSES     files the agent can read as clues           (clue.txt)
#     AGENT_MAX_STEPS  budget: give up after this many moves       (60)
#     AGENT_DELAY      seconds between steps, so humans can watch  (0.6)
#
#  Runs with bash 3.2+ on macOS, Linux, WSL and Git Bash. Always start it
#  with `bash agent.sh …`, even if your terminal uses zsh.
# =============================================================================

HOME_DIR="$(cd "$(dirname "$0")" && pwd)"        # the folder this script lives in
WORLD="$HOME_DIR/world"
MEMORY="$HOME_DIR/agent-memory.txt"
JOURNAL="$HOME_DIR/journal-human.txt"
AGENT_SENSES="${AGENT_SENSES:-clue.txt}"
AGENT_MAX_STEPS="${AGENT_MAX_STEPS:-60}"
AGENT_DELAY="${AGENT_DELAY:-0.6}"

MODE="manual"; NEW="no"; BUILD_ARGS=""
usage() { awk 'NR>2 && /^# =+$/ {exit} NR>2 {sub(/^# ?/, ""); print}' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --auto)   MODE="auto"; shift ;;
    --random) MODE="random"; shift ;;
    --clean)  MODE="clean"; shift ;;
    --new)    NEW="yes"; shift ;;
    --seed|--level|--depth|--branching)
              [ -z "${2:-}" ] && { echo "$1 needs a value"; exit 1; }
              BUILD_ARGS="$BUILD_ARGS $1 $2"; NEW="yes"; shift 2 ;;
    --fast)   AGENT_DELAY=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; echo; usage; exit 1 ;;
  esac
done

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; RD=$'\033[31m'; C=$'\033[36m'; M=$'\033[35m'; N=$'\033[0m'; O=$'\033[38;5;208m'
else B=; D=; G=; Y=; RD=; C=; M=; N=; O=; fi

# =============================================================================
#  THE WELCOME SCREEN
# =============================================================================
banner() {
  local line="──────────────────────────────────────────────────────"
  echo
  echo "${O} █████╗  ██████╗ ███████╗███╗   ██╗████████╗██╗ ██████╗"
  echo "██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██║██╔════╝"
  echo "███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║██║     "
  echo "██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   ██║██║     "
  echo "██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   ██║╚██████╗"
  echo "╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝${N}"
  echo
  echo "${O}╭${line}╮${N}"
  printf "${O}│${N} ${O}✻${N} ${B}%-50s${N} ${O}│${N}\n" "Welcome to Agent in the World"
  printf "${O}│${N}   %-50s ${O}│${N}\n" ""
  printf "${O}│${N}   ${D}%-50s${N} ${O}│${N}\n" "$1"
  printf "${O}│${N}   ${D}%-50s${N} ${O}│${N}\n" "$2"
  echo "${O}╰${line}╯${N}"
  echo
}

# =============================================================================
#  CLEAN SLATE
# =============================================================================
if [ "$MODE" = "clean" ]; then
  echo "This will delete:"
  [ -d "$WORLD" ]   && echo "   $WORLD/   (the world)"
  [ -f "$MEMORY" ]  && echo "   $MEMORY   (the agent's memory)"
  [ -f "$JOURNAL" ] && echo "   $JOURNAL   (your journal)"
  if [ ! -d "$WORLD" ] && [ ! -f "$MEMORY" ] && [ ! -f "$JOURNAL" ]; then echo "   nothing — it's already a clean slate."; exit 0; fi
  if [ -t 0 ]; then
    read -r -p "Delete them? [y/N] " yn
    case "$yn" in y|Y|yes) ;; *) echo "Nothing deleted."; exit 0 ;; esac
  fi
  if [ -d "$WORLD" ]; then
    chmod -R u+rwx "$WORLD" 2>/dev/null       # unlock level-3 rooms first, or rm is refused
    # Guard rail: only delete a world we built (it has our marker, or holds nothing
    # but rooms, clues and a map). Agents that can run rm -rf need rules like this.
    if [ -f "$WORLD/.world" ] || [ -z "$(find "$WORLD" -type f ! -name clue.txt ! -name .clue.txt ! -name map.txt)" ]; then
      rm -rf "$WORLD"
    else
      echo "Not deleting $WORLD: it wasn't built by world-builder.sh."
    fi
  fi
  rm -f "$MEMORY" "$JOURNAL"
  echo "Clean slate. Next game builds a fresh world."
  exit 0
fi

case "$MODE" in
  manual) banner "mode:  manual - you are the agent's brain" "tools: type help  |  options: bash agent.sh --help" ;;
  auto)   banner "mode:  auto - the agent follows the clues" "sit back and watch  |  Ctrl-C to stop" ;;
  random) banner "mode:  random - the agent wanders" "sit back and watch  |  Ctrl-C to stop" ;;
esac

# =============================================================================
#  THE WORLD — reuse the current one, or ask world-builder.sh for a new one
# =============================================================================
if [ "$NEW" = "yes" ] || [ ! -f "$WORLD/.world" ]; then
  WORLD="$WORLD" bash "$HOME_DIR/world-builder.sh" $BUILD_ARGS || exit 1
  : > "$MEMORY"
else
  echo "${D}Using the existing world ($(sed 's/built by world-builder.sh *//' "$WORLD/.world")). Add --new for a fresh one.${N}"
fi

cd "$WORLD" || exit 1
ROOT="$(pwd)"
OPTIMAL="$(tr -d ' \r\n' < "$ROOT/clue.txt")"
MOVES=0

here()  { local p="${PWD#$ROOT}"; echo "world${p}"; }
trap 'echo; echo "${Y}Stopped.${N} The world is still there — play again, or start over with:  bash agent.sh --clean"; exit 130' INT

# =============================================================================
#  MODE 1 — MANUAL: a human is the brain, typing real shell commands
# =============================================================================
play_manual() {
  local LINE cmd arg TURNS=0 MAPS=0
  set -f                        # treat * and ? literally: no filename magic here
  set -o history 2>/dev/null    # up-arrow recalls earlier commands
  log()  { echo "$(date '+%H:%M:%S')  $*" >> "$JOURNAL"; }
  deny() { echo "${Y}✗ $*${N}"; log "DENIED  $LINE"; }
  show_map() {
    if [ -r map.txt ]; then
      cat map.txt; MAPS=$(( MAPS + 1 )); log "cat map.txt (look $MAPS)"
      echo
      read -r -p "${D}Study the map. Press Enter to put it away — you'll have to remember it.${N} " _
      printf '\033[2J\033[3J\033[H'          # clear the screen AND the scroll-back
      echo "${D}The map is gone. What do you remember?${N}"
    else echo "${RD}cat: map.txt: no such file here${N} ${D}(the map is in the first room)${N}"; log "cat map.txt -> not here"; fi
  }

  echo "--- new game $(date)" >> "$JOURNAL"
  cat <<EOF

  You wake up in a world made of folders. Somewhere there is a room whose clue reads 0.
  Every room has a clue.txt: the number of moves between that room and the destination.
  ${D}Your tools: whoami  pwd  ls  ls -a  cd <room>  cd ..  clue  map  cat <file>  help  exit${N}
  ${D}There is a map in this first room. Read it well — once you look away, it's gone.${N}

EOF
  read -r -p "${D}Press Enter to see the map.${N} " _
  show_map

  while :; do
    TURNS=$(( TURNS + 1 ))
    if ! read -e -p "${C}[moves:$MOVES]${N} ${B}agent@$(here)${N} \$ " LINE; then echo; break; fi
    [ -z "$LINE" ] && continue
    history -s "$LINE" 2>/dev/null
    set -- $LINE; cmd="$1"; shift; arg="${1:-}"
    # shortcuts: "clue" is "cat clue.txt", "map" is "cat map.txt"
    case "$cmd" in clue) cmd=cat; arg=clue.txt ;; map) cmd=cat; arg=map.txt ;; esac

    case "$cmd" in
      whoami) whoami; log "whoami" ;;
      pwd)    pwd;    log "pwd" ;;
      ls)
        case "$arg" in ""|-a|-l|-la|-al|-F|-aF) ls $arg; log "ls $arg" ;;
          *) deny "ls only looks at this room (try: ls  or  ls -a)" ;; esac ;;
      cat)
        case "$arg" in
          "")  deny "cat needs a file name, e.g.  cat clue.txt" ;;
          */*) deny "Your senses reach only this room. No / allowed." ;;
          map.txt) show_map ;;
          *)
            if cat -- "$arg" 2>/dev/null; then
              log "cat $arg -> $(head -c 60 "$arg" | tr '\n' ' ')"
              case "$arg" in clue.txt|.clue.txt)
                if [ "$(tr -d ' \r\n' < "$arg")" = "0" ]; then
                  echo
                  echo "${G}✓ The clue reads 0. You have arrived: $(here)${N}"
                  echo "  Moves: $MOVES  ·  Shortest possible: $OPTIMAL  ·  Commands typed: $TURNS  ·  Looks at the map: $MAPS"
                  echo "  ${D}Your journey is in journal-human.txt · Start over: bash agent.sh --clean${N}"
                  log "ARRIVED at $(here) moves=$MOVES optimal=$OPTIMAL maps=$MAPS"
                  return 0
                fi ;;
              esac
            else
              echo "${RD}cat: $arg: No such file or directory${N}"; log "cat $arg -> FAILED"
              [ "$arg" = "clue.txt" ] && echo "${D}  (no clue.txt here… could it be hidden? try: ls -a)${N}"
            fi ;;
        esac ;;
      cd)
        case "$arg" in
          "") deny "cd needs a room name (or .. to step back out)" ;;
          ..)
            if [ "$PWD" = "$ROOT" ]; then deny "This is the edge of the world. There is no way further out."
            else cd .. && MOVES=$(( MOVES + 1 )) && log "cd .. -> $(here)"; fi ;;
          */*|~*|-) deny "You cannot fly. Move one room at a time (no / in the name)." ;;
          .) deny "You are already here." ;;
          *)
            if [ ! -d "$arg" ]; then echo "${RD}cd: $arg: no such room here${N} ${D}(try ls)${N}"; log "cd $arg -> no such room"
            elif cd -- "$arg" 2>/dev/null; then MOVES=$(( MOVES + 1 )); log "cd $arg -> $(here)"
            else echo "${RD}cd: $arg: Permission denied${N}  ${D}(the operating system refused — who owns this room? try: ls -l)${N}"
                 log "cd $arg -> Permission denied"; fi ;;
        esac ;;
      help|\?)
        echo "  whoami        who is this agent acting as?"
        echo "  pwd           where am I? (the full address of this room)"
        echo "  ls  / ls -a   what is in this room? (-a also shows hidden things)"
        echo "  cd <room>     step into a room inside this one"
        echo "  cd ..         step back out to the room that contains this one"
        echo "  clue          read this room's clue (same as: cat clue.txt)"
        echo "  map           look at the map, if it is in this room (same as: cat map.txt)"
        echo "  cat <file>    read any file in this room"
        echo "  exit          give up" ;;
      exit|quit) echo "Agent stopped after $MOVES moves."; log "GAVE UP moves=$MOVES"; return 0 ;;
      *) deny "'$cmd' is not a tool this agent has. Type help to see your tools." ;;
    esac
  done
}

# =============================================================================
#  MODES 2 & 3 — AUTO and RANDOM: a script is the brain. You sit back and watch.
#
#  The BODY (senses and moves) is the same for every agent.
#  The BRAIN (how it decides) is what changes between --auto and --random.
# =============================================================================
remember() { echo "$*" >> "$MEMORY"; }                   # write to memory
recalls()  { grep -qxF "$*" "$MEMORY"; }                  # is this in memory?
say()      { printf "  %s%-6s%s %s\n" "$1" "$2" "$N" "$3"; }
pause()    { [ "$AGENT_DELAY" != "0" ] && sleep "$AGENT_DELAY"; }

# ---- THE BODY ---------------------------------------------------------------

# SEE: read a clue in THIS room. Sets CLUE (empty if the agent senses nothing).
sense_clue() {
  local f; CLUE=""
  for f in $AGENT_SENSES; do
    if [ -r "$f" ]; then CLUE="$(tr -d ' \r\n' < "$f")"; return; fi
  done
}

# SEE: list the doors (rooms inside this one). Sets DOORS and CAN_GO_UP.
sense_doors() {
  local d; DOORS=""
  for d in */; do [ -d "$d" ] && DOORS="$DOORS ${d%/}"; done
  DOORS="${DOORS# }"
  if [ "$PWD" = "$ROOT" ]; then CAN_GO_UP="no"; else CAN_GO_UP="yes"; fi
}

# DO: move one step. Fails if the rules or the operating system say no.
move() {
  if [ "$1" = ".." ]; then [ "$PWD" = "$ROOT" ] && return 1; cd ..
  else case "$1" in */*|"") return 1 ;; esac; cd -- "$1" 2>/dev/null; fi
}

# ---- THE BRAINS: read the percept, set ACTION (a room or "..") and THOUGHT ----

brain_random() {
  local options="$DOORS" n
  [ "$CAN_GO_UP" = "yes" ] && options="$options .."
  set -- $options; n=$#
  if [ "$n" -eq 0 ]; then ACTION=""; THOUGHT="No doors at all. I am stuck."; return; fi
  eval "ACTION=\${$(( RANDOM % n + 1 ))}"
  THOUGHT="I don't use the clue. Picking one of $n ways at random."
}

brain_auto() {                   # follows the clues
  # The idea: the right neighbour always has a clue exactly ONE smaller.
  # If the last step made the number bigger, go back. Otherwise try a door
  # I haven't tried from here. If every door is used up, go back out.
  local key="${PWD#$ROOT}" d
  if [ -z "$CLUE" ]; then ACTION=""; THOUGHT="I sense no clue here, and my senses are only: $AGENT_SENSES. I can't follow the numbers."; return; fi
  if [ -n "$LAST_CLUE" ] && [ "$CLUE" -gt "$LAST_CLUE" ] && [ "$LAST_ACTION" != ".." ]; then
    ACTION=".."; THOUGHT="The number went UP ($LAST_CLUE → $CLUE). Wrong way — stepping back."; return
  fi
  for d in $DOORS; do
    if ! recalls "tried $key/$d"; then
      remember "tried $key/$d"
      ACTION="$d"; THOUGHT="Clue is $CLUE. I haven't tried '$d' from here yet — trying it."; return
    fi
  done
  if [ "$CAN_GO_UP" = "yes" ]; then ACTION=".."; THOUGHT="Every door here is used up. The way must be back out."
  else ACTION=""; THOUGHT="Every door tried and I can't go further out. I am stuck."; fi
}

# ---- THE LOOP: see → check → think → do → remember ---------------------------
run_agent() {
  local BRAIN="$1" STEPS=0 BLOCKED=0
  LAST_CLUE=""; LAST_ACTION=""
  : > "$MEMORY"                                        # a fresh memory for a fresh run
  echo
  echo "${B}● The agent wakes up in $(here).${N}"
  echo "${D}  acting as user: $(whoami) · budget: $AGENT_MAX_STEPS moves · memory: agent-memory.txt${N}"
  remember "# brain=$BRAIN · started $(date)"

  while :; do
    echo
    sense_clue; sense_doors                                                   # SEE
    say "$C" SEE "in $(here)  ·  clue: ${CLUE:-?}  ·  doors: ${DOORS:-none}$( [ "$CAN_GO_UP" = yes ] && echo '  ·  can go back out' )"
    remember "saw $(here) clue=${CLUE:-?} doors=${DOORS:-none}"

    if [ "$CLUE" = "0" ]; then                                                # CHECK
      echo
      echo "${G}✓ Task complete.${N} The clue in $(here) reads 0."
      echo "  ${B}$STEPS moves${N} (shortest possible: $OPTIMAL)  ·  brain: $BRAIN  ·  blocked doors: $BLOCKED"
      echo "  ${D}Its memory is in agent-memory.txt · Start over: bash agent.sh --clean${N}"
      remember "DONE at $(here) after $STEPS moves"; return 0
    fi
    if [ "$STEPS" -ge "$AGENT_MAX_STEPS" ]; then
      echo "${Y}✗ Budget spent.${N} $STEPS moves and no destination. Stopping, as instructed."
      remember "GAVE UP after $STEPS moves (budget)"; return 2
    fi

    "brain_$BRAIN"                                                            # THINK
    say "$M" THINK "$THOUGHT"
    if [ -z "$ACTION" ]; then
      echo "${Y}✗ The agent stops.${N} Reason: $THOUGHT"; remember "STOPPED: $THOUGHT"; return 3
    fi
    pause

    if move "$ACTION"; then                                                   # DO
      say "$B" DO "cd $ACTION"
      STEPS=$(( STEPS + 1 )); LAST_CLUE="$CLUE"; LAST_ACTION="$ACTION"
      remember "did cd $ACTION"                                               # REMEMBER
    else
      say "$RD" DO "cd $ACTION  →  refused (Permission denied)"
      remember "blocked cd $ACTION from $(here)"; BLOCKED=$(( BLOCKED + 1 ))
    fi
    pause
  done
}

case "$MODE" in
  manual) play_manual ;;
  auto)   run_agent auto ;;
  random) run_agent random ;;
esac
