# gfd (Git For Dumbs)

Because saving code should not require a degree in graph theory.

`gfd` is a zero-friction workflow engine and code-native task manager designed for game developers and small teams who want to focus on shipping software instead of wrestling with Git CLI bureaucracy.

`gfd` uses standard Git as an invisible, low-level database. You write code, hit save, and collaborate continuously, while `gfd` handles history, background synchronization, and task tracking under the hood.

Written in Odin for zero-dependency, high-performance execution.

---

## The Philosophy: Hot vs. Cold Layers

Traditional Git forces you to manage daily working states and long-term history using the same complex set of commands. `gfd` splits version control into two simple, distinct layers:

```
+-------------------------------------------------------------+
|                     Developer Workspace                     |
|    - Automatic file saves                                   |
|    - Inline task comments: // TODO(name): fix bug           |
+------------------------------+------------------------------+
                               |
                               | Continuous Sync (Hot Layer)
                               v
+-------------------------------------------------------------+
|                Remote Git Relay Server                      |
|    - Background diffs stored in refs/sync/<username>        |
+------------------------------+------------------------------+
                               |
                               | On `gfd milestone "<msg>"`
                               v
+-------------------------------------------------------------+
|                Clean Git History (Cold Layer)               |
|    - Human-readable, linear commits on `main`               |
+-------------------------------------------------------------+

```

1. **Hot Layer (Live Sync):** File saves are continuously pushed to hidden background sync references (`refs/sync/<username>`). Teammates receive live updates and task notifications automatically.
2. **Cold Layer (Milestones):** When a feature or playtest build is ready, running a single command squashes active development state into a clean, readable commit on `main`.

---

## Features

* **Zero-CLI Git Plumbing:** No manual `add`, `commit`, `rebase`, `fetch`, or `merge` during daily development.
* **Code-Native Task Management:** Skip web-based issue trackers. Write `// TODO(username): description` in your source files. `gfd tasks` scans your codebase in milliseconds.
* **Immaculate Git History:** Your `main` branch stays clean and readable, containing only stable, compilation-verified milestone commits.
* **Non-Blocking Conflicts:** Incoming changes never lock your working directory or halt your editor.
* **Zero Cloud Lock-in:** Works with any standard Git remote (GitHub, GitLab, Gitea, or a private SSH server).

---

## Installation

### Prerequisites

* [Odin Compiler](https://odin-lang.org/)
* System `git` binary installed and available in `PATH`

### Build from Source

```bash
git clone https://github.com/your-username/gfd.git
cd gfd
odin build src -out:gfd -opt:2

```

Move the resulting `gfd` binary into your system's `PATH`.

---

## Quickstart

### 1. Onboard a Project

Clone your repository using `gfd`. This automatically configures shadow refspecs and scans for initial tasks:

```bash
gfd clone git@github.com:your-team/game-project.git
cd game-project

```

### 2. Daily Workflow

Write code normally. Save files. Run `gfd sync` (or keep the background watcher active):

```bash
gfd sync

```

### 3. Track Tasks

Assign work directly inside your code:

```cpp
// TODO(alex): Fix spatial hash grid bounds checking on chunk load
void update_physics_chunk(Chunk *chunk) {
    // ...
}

```

Check open tasks assigned to you:

```bash
gfd tasks

```

### 4. Ship a Milestone

When a feature is tested and working, publish a clean milestone commit:

```bash
gfd milestone "Added player locomotion and jump physics"

```

---

## Command Reference

| Command | Action |
| --- | --- |
| `gfd clone <url>` | Clones repo, initializes shadow refspecs, and displays active tasks. |
| `gfd sync` | Pushes local working state to `refs/sync/<user>` and pulls peer updates. |
| `gfd tasks` | Scans workspace for open `// TODO(your_name)` comments. |
| `gfd tasks -a` | Scans workspace for all open tasks assigned across the entire team. |
| `gfd milestone "<msg>"` | Squashes active development into a clean, readable commit on `main`. |
| `gfd rollback` | Resets working directory to the last stable milestone commit on `main`. |
| `gfd status` | Displays daemon health, active peers, and sync status. |

---

## Task Syntax

Tasks are declared directly inside source files (`.cpp`, `.h`, `.c`, `.odin`, `.hlsl`, etc.):

```odin
// TODO(casey): Optimize particle allocation buffer to eliminate alloc thrashing
update_particles :: proc(sys: ^Particle_System) {
    // ...
}

```

```c
// BLOCKER(john): Player clips through slope geometry at angles > 45 deg
void check_terrain_collision(Entity *player) {
    // ...
}

```

Supported tags:

* `TODO(name)`: General task or feature assignment.
* `FIX(name)`: Bug fix assignment.
* `BLOCKER(name)`: High-priority issue (prevents milestone generation if unfixed).

---

## License

MIT License. Free for open-source and commercial use.
