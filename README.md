# Agent in the World

*A small game for learning the command line, played by you and then by an agent.*
Module 1 of **Agentic**, a course by InterEmbodied Labs.

An agent wakes up in a world made of folders. One room is the destination. Every room has a `clue.txt` with a single number: how many moves away the destination is. The destination's clue reads **0**.

```
[moves:2] agent@world/grotto/harbour $ cat clue.txt
1
```

## What you need

A terminal with **bash**:

- **macOS:** open Terminal. Your terminal probably runs zsh, which is fine. Just type `bash agent.sh …`.
- **Linux:** any terminal.
- **Windows:** WSL (recommended) or Git Bash.

There is nothing to install.

## Get the game

Open a terminal and paste this one line. It downloads the game, unpacks it into a folder, and moves you into that folder:

```bash
curl -L https://github.com/abhayvohra/agent-in-the-world/archive/refs/heads/main.tar.gz | tar xz && cd agent-in-the-world-main
```

<sub>`curl` fetches a file from the internet and `tar` unpacks it. Both come with macOS and Linux. On Windows, paste the line into WSL or Git Bash, not PowerShell.</sub>

**Or, without the terminal:** on the GitHub page, click **Code → Download ZIP**, unzip it, and open a terminal in that folder.

## Play

```bash
bash agent.sh              # you are the agent's brain: type the commands yourself
bash agent.sh --auto       # watch an agent that follows the clues on its own
bash agent.sh --random     # watch an agent that wanders at random
```

The first game builds a world. Later games reuse the **same world**, so you can compare how you, the auto agent and the random agent do on it.

### In manual mode you have these tools

| Command | What it does |
|---|---|
| `whoami` | shows who this agent is acting as |
| `pwd` | shows where you are (the full address of this room) |
| `ls`, `ls -a` | shows what is in this room (`-a` also shows hidden things) |
| `cd <room>` | steps into a room inside this one |
| `cd ..` | steps back out |
| `cat <file>` | reads a file in this room |

The world's rules: one step at a time, no flying (no `/` in names), and your senses reach only the room you are in. The **map** (`cat map.txt` in the first room) disappears when you press Enter, so you have to remember it.

## Options

```bash
bash agent.sh --auto --new          # a fresh random world
bash agent.sh --auto --seed 42      # a specific world: same seed, same world, on every computer
bash agent.sh --auto --level 2      # some clues are hidden… can the agent still find its way?
bash agent.sh --auto --level 3      # some rooms are locked
bash agent.sh --auto --fast         # no pauses
bash agent.sh --clean               # delete the world and all records: a clean slate
```

**Stuck on level 2?** The agent can only read the files it knows about. Give it a new sense:

```bash
export AGENT_SENSES="clue.txt .clue.txt"
bash agent.sh --auto
```

## What gets created

| Path | What it is |
|---|---|
| `world/` | the world: folders (rooms), `clue.txt` files and `map.txt` |
| `agent-memory.txt` | what the agent saw, tried and did, one line per event |
| `journal-human.txt` | every command you typed in manual mode |

These files are material for the post-session exercise, so they are kept until you run `bash agent.sh --clean`. Deleting `world/` by hand after a level-3 game fails with "Permission denied", because the locked rooms stay locked. `--clean` unlocks them first.

## Read the code

The two scripts are meant to be read. `cat agent.sh` shows the agent: its body (how it senses and moves), its two brains (auto and random), and its loop of **see → check → think → do → remember**. `cat world-builder.sh` shows how its world was made.

## License

*(to be decided)*
