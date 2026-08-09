## Complete `gfd` Command Reference

### Project Setup

| Command | Usage | Description |
| --- | --- | --- |
| **`gfd clone`** | `gfd clone <url> [dir]` | Clones a repository, configures hidden `refs/sync/*` refspecs, sets up local user tracking, and scans initial tasks. |
| **`gfd init`** | `gfd init` | Converts an existing local Git repository into a `gfd`-managed workspace without re-cloning. |

---

### Daily Synchronization

| Command | Usage | Description |
| --- | --- | --- |
| **`gfd sync`** | `gfd sync` | Triggers a single manual sync: stages local edits, commits to your local shadow branch, forces-pushes to `refs/sync/<user>`, and fetches peer updates. |
| **`gfd watch`** | `gfd watch` | Runs the continuous background file watcher daemon in the current terminal (or registers it as an OS background worker). Auto-syncs on file saves. |
| **`gfd status`** | `gfd status` | Shows daemon health, uncommitted files, peer sync states, and pending remote shadow changes. |

---

### Code-Native Task Management

| Command | Usage | Description |
| --- | --- | --- |
| **`gfd tasks`** | `gfd tasks` | High-speed scan of source files (`.cpp`, `.h`, `.odin`, `.c`, etc.) for open `// TODO(your_name)` or `// FIX(your_name)` comments assigned to you. |
| **`gfd tasks`** | `gfd tasks -a` | Scans and displays open task assignments across the **entire team**. |

---

### History & Milestone Releases

| Command | Usage | Description |
| --- | --- | --- |
| **`gfd milestone`** | `gfd milestone "<message>"` | Squashes active development from all peer shadow refs into a single clean, human-readable commit on `main`, pushes to remote, and resets shadow refs. |
| **`gfd rollback`** | `gfd rollback` | Discards hot local changes and restores the working directory to the last stable milestone commit on `main`. |

---

## Example Usage Workflow

```bash
# 1. Start a new project workspace
gfd clone git@github.com:team/game.git
cd game

# 2. Start the watcher in the background or run manually
gfd watch &

# 3. Check what you need to work on
gfd tasks

# 4. Code normally in your editor and save...

# 5. Check sync and peer status anytime
gfd status

# 6. Publish a clean build for the team
gfd milestone "Completed character locomotion pass"

```
