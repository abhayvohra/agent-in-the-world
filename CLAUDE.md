# CLAUDE.md: Agent in the World

Notes for Claude Code sessions in this folder. This file ships with the game, so learners' agents read it too. Keep it short and up to date.

## What this is

A terminal game for **Agentic Intelligence**, Module 1 (InterEmbodied Labs / Embodied Intelligence Labs LLP). An agent wakes up in a world made of folders. One room is the destination, named by the haiku (e.g. `egress`); every room has a `clue.txt` with one number, the distance to the destination (0 = arrived). The **body** (senses `ls`, `cat clue.txt`; moves `cd`) stays fixed. Only the **brain** changes: a human, a clue-following rule, or chance. The game teaches shell basics and a systemic view of agents (senses, memory, environment, infrastructure, people).

- Repo: https://github.com/abhayvohra/agent-in-the-world (`origin`, branch `main`)
- License: CC BY-NC-SA 4.0, © InterEmbodied Labs

## Files

| File | Role |
|---|---|
| `agent.sh` | The game. Arg parsing, AGENTIC INTELLIGENCE welcome banner, haiku picker (`haiku_field`), `play_manual` (manual mode), `brain_auto`, `brain_random`, `run_agent` (the loop), `--clean`. |
| `world-builder.sh` | Builds the world tree. Called by `agent.sh`. Options `--seed --level --depth --branching --trail`; env `WORLD`. Its own seeded RNG, so the same seed gives the same world on every computer. |
| `.haiku.md` | The haikus (a hidden file: `ls -a` shows it). Each is three lines plus a `trail:` line (the rooms on the way to the destination, outermost first; the last word is the destination itself), blocks separated by a blank line. Add a haiku by adding a block; no code change. |
| `README.md` | Learner-facing instructions, including the one-line `curl … \| tar xz` download. |
| `world/`, `agent-memory.txt`, `journal-human.txt` | Created when playing; gitignored. Kept on purpose as take-home material until `--clean`. |

## Modes and options

- `bash agent.sh`: manual (human is the brain). `--auto`: follows clues. `--random`: wanders.
- World options with any mode: `--new`, `--seed N`, `--level 2|3`, `--fast`, `--help`. `--clean` deletes the world and records (unlocks level-3 rooms first, lists what it will delete, asks for confirmation, and only deletes a world `world-builder.sh` built).
- Env vars: `AGENT_SENSES` (default `clue.txt`), `AGENT_MAX_STEPS` (60), `AGENT_DELAY` (0.6).
- Levels: 2 hides some clues as `.clue.txt` (auto agent stalls until `export AGENT_SENSES="clue.txt .clue.txt"`); 3 locks some dead ends with `chmod 000` (no effect on Git Bash).

## The haiku

- When `agent.sh` builds a **new** world it picks one haiku from `.haiku.md`: by seed if `--seed N` was given (same seed, same haiku), otherwise at random. It passes the haiku's trail to `world-builder.sh --trail`, which names the destination and the rooms above it after the haiku's words, e.g. `…/dream/hopes/egress`. The destination is the trail's last word, so a haiku that says "egress" gets an `egress` room. The trail words are reserved so no other room uses them.
- The world remembers only **which** haiku (`haiku=N` on the second line of `world/.world`), not its words. Later runs reuse the world and its haiku; `--new` picks again.
- In manual mode the haiku is shown once at the start, then the screen and scroll-back are cleared. It is not written to the journal. The player must remember it and follow the trail. Editing `.haiku.md` renumbers nothing, but it changes what an existing world's number points to; run `--new` after editing.
- If `.haiku.md` is missing or has no haiku, the game builds the default trail (`dream hopes egress`) and starts without a haiku. Worlds built before haiku mode also start without one.
- The haikus are in `.haiku.md`, which is in the download. It is hidden from plain `ls` only; a learner (or their own AI agent) can read it with `ls -a` and `cat`. That is allowed: git and the tar download cannot keep a file unreadable from the person who has it, and learners' agents are meant to be able to read the repo.

## Design rules: keep these

- **Harness rules, not OS rules:** one step at a time, no `/` in `cd` ("you cannot fly"), senses limited to the current room. The player wins only by *reading* a clue of 0, not by being in the room.
- **Manual-mode tools** (the `case "$cmd" in` block in `play_manual`): `whoami pwd ls ls -a cd clue map cat help exit/quit`. `clue` and `map` are shortcuts for `cat clue.txt` and `cat map.txt` (rewritten to `cat` just before the `case`); `cat <file>` still works, which level 2 needs for `cat .clue.txt`. Unknown commands are denied with a hint.
- **The map is a secret to find:** it is a cheat code, so the game never mentions it: not at the start, not in the banner, `help`, README or the arrival summary (the "Looks at the map" count appears only if the player used it). Keep it that way. `map` or `cat map.txt` shows it in the first room; pressing Enter clears the screen and scroll-back. The game counts the looks.
- **Auto rule:** the right neighbour has a clue exactly one smaller; if the number went up, step back; else try an untried door; if all are tried, step out. It needs `agent-memory.txt` (`tried …` lines) or it loops. Loop order: see → check → think → do → remember. Output labels SEE / THINK / DO. Auto and random never see the haiku.
- **Portability:** must run on macOS's bash 3.2 (no associative arrays, `mapfile`, `${var,,}` etc.), Linux, WSL, Git Bash. Always invoked as `bash agent.sh`. Check syntax with `bash -n agent.sh`; quick run `bash agent.sh --seed 42 --fast`.
- **Scripts are teaching material:** learners are told to `cat` them. Keep code readable, commented in plain English, and short.
- **Naming:** "Agentic" throughout the course; the game is "Agent in the World", prompt `agent@world`. Modes are `--auto` and `--random` (not `--greedy`/`--clue`).
- **Download:** pipe into `tar`, never into `bash`.

## Course link (Module 1 slides 3.11–3.16)

The slides describe the game, quote a real auto-mode excerpt, and give the download command. Keep `README.md`, command names and output format consistent with them. The slides, the README and the slide 3.15 learner exercise were written for the older game (map shown at the start, `cat clue.txt`, destination not named); they need updating for `clue` and the haiku.

## Open items

1. Test all three modes on a Mac (bash 3.2). Only Linux bash 5.1/5.2 and a macOS dev machine with piped input were tested.
2. Update the slides for the haiku opening and `clue` (the README is done).
3. Next version ideas: `--llm` brain (cloud or local model, guard rail on moves, visible prompt); wormholes (symlinks); noisy or missing clues; random start room.
