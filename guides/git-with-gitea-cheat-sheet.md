# Git cheat sheet — clicks and commands

A short reference to print or keep open (about two printed pages). Every row is explained in the full guide:
[Git with Gitea](git-with-gitea.md). Server: `http://192.168.0.22:3000`. Sign in to git with a
**token**, never your password.

## Getting started

| Task | Visual Studio 2026 | Terminal |
|---|---|---|
| **Put a folder you have on Gitea** (Lab VA / CA) | Gitea: **New Repository**, *Initialize* unticked → add `.gitignore` **first** → **Git → Create Git Repository… → Other → Local** → **Git → Manage Remotes** → `origin` = repo URL → **Push** | `dotnet new gitignore` · `git init` · `git add .` · `git status` (look!) · `git commit -m "Initial commit"` · `git remote add origin <url>` · `git push -u origin main` |
| **Get a copy of a Gitea repo** (Lab VB / CB) | **Git → Clone Repository…** → URL from the repo's **Code** button + a **new** folder → **Clone** | `git clone <url> <new-folder>` |

## The daily loop

| # | Step | Visual Studio 2026 | Terminal |
|---|---|---|---|
| 1 | Where am I, what changed? | Look at **Git Changes** and the **↑↓ out / in** counts in the status bar | `git status` |
| 2 | Get everyone's work first | Branch picker → `main`, then **Git → Pull** | `git switch main` then `git pull` |
| 3 | Start a branch | Branch picker → **New Branch…**, *Based on:* `main` | `git switch -c feature/x` |
| 4 | Review your own diff | Double-click a file under **Changes** | `git diff` |
| 5 | Stage what you mean | **+** on the file (or select lines → right-click → **Git › Stage Selected Range**) | `git add <file>` (lines: `git add -p`) |
| 6 | Commit | Type a message → **Commit Staged**. *Read the button: "Commit All" takes everything* | `git commit -m "feat: …"` |
| 7 | Push | **Git → Push** (a new branch is created on Gitea, no prompt) | `git push -u origin feature/x` the first time, then `git push` |
| 8 | Pull request | **Browser only**: repo page → *You pushed on branch* banner → **New Pull Request** | same — no git command opens a PR |
| 9 | After the merge | Branch picker → `main` → **Pull**, then **Git → Manage Branches** → right-click the branch → **Delete** | `git switch main`, `git pull`, `git branch -d feature/x`, `git fetch --prune` |

**Pull request, in the browser:** check **merge into: `main`** ← **pull from: your branch** · a
specific title · what / why / how tested · **Create Pull Request** · after review, **Create merge
commit** with **Delete Branch** ticked.

## Look before you pull

| Want to know | Visual Studio | Terminal |
|---|---|---|
| What is on the server that I do not have? | **Git → Fetch**, then **Git Repository → Incoming** | `git fetch` then `git log --oneline HEAD..origin/main` |
| What would my push send? | **Git Repository → Outgoing** | `git log --oneline origin/main..HEAD` |
| The whole shape | **Git Repository** graph | `git log --oneline --graph --all -20` |

## Undo

| Mistake | Visual Studio | Terminal |
|---|---|---|
| Staged the wrong file | **−** on the file | `git restore --staged <file>` |
| Want my edits gone (**cannot be undone**) | Right-click → **Undo Changes** | `git restore <file>` |
| Wrong message / forgot a file, **not pushed** | Tick **Amend**, commit again | `git commit --amend` |
| Committed too early, **not pushed** | Right-click the commit **below** → **Reset › Keep Changes** | `git reset HEAD~1` |
| Anything **already pushed** | Right-click the commit → **Revert** | `git revert <sha>` |
| "I destroyed commits" / deleted a branch | **No button** — View → Terminal | `git reflog`, then `git reset --hard HEAD@{1}` or `git switch -c rescued <sha>` |
| Merge went wrong | **Abort** in Git Changes | `git merge --abort` |

## Park work for a moment

| | Visual Studio | Terminal |
|---|---|---|
| Put it on the shelf | Commit button **▾** → **Stash All** | `git stash -u` |
| Bring it back | **Stashes** → right-click → **Pop › Pop All as Unstaged** | `git stash pop` |

## When something goes wrong

- **Read git's own words.** VS: **View → Output** → *Show output from:* **Source Control - Git**.
  Terminal: the error itself, and the `hint:` lines under it.
- **Push rejected / "Git - Push failed"** → someone pushed first: **Pull**, look, then **Push** again.
- **Conflict** → pick or edit the lines (VS **Merge Editor** → **Accept Merge**; terminal: delete the
  `<<<<<<<` `=======` `>>>>>>>` markers, `git add`), commit, **then build and run it**.
- **Keeps asking for a password** → Windows **Credential Manager** → remove the
  `git:http://192.168.0.22:3000` entry → push again and paste a fresh token.
- **Anything committed is recoverable for ~90 days** with `git reflog`. Anything never committed is not.

## Rules of thumb

Pull before you start · one branch, one purpose · never commit to `main` · stage deliberately ·
commit small · push before you branch · never force-push a shared branch · commit before you
experiment.
