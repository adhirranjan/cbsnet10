# Git with Gitea — from zero to your first pull request

> A complete working reference for git as used on this project, written for someone who has
> never used it. Read sections 0–3, do the labs, then keep sections 4–7 open in a tab forever.
>
> Budget: **~30 minutes to your first commit**, ~90 minutes to finish all the labs.
>
> Our git server is **Gitea** (self-hosted), not GitHub. Every command here is plain `git`
> and works against any server. §6 is what is specific to our Gitea server, and §7 is
> Visual Studio 2026. Every tutorial you find online will reach for `gh`, the **GitHub**
> CLI — it does not work here; §6.6 explains why and names the Gitea equivalent.

---

## Your server details

Fill these in once — every example below uses them.

| Thing | Value |
|---|---|
| Gitea URL | `http://192.168.0.22:3000` |
| Your username | `Adhir` |
| Commit email | `adhirranjan@softtrust.com` |
| Practice repo | `http://192.168.0.22:3000/Adhir/git-practice.git` |

Your account password is **not** written down anywhere in this document, and it should not be:
git never needs it. You authenticate with a **Personal Access Token** you generate yourself in
the Gitea UI (§6.1), which Windows then stores encrypted on your behalf.

---

## Contents

- [0. Before you start](#0-before-you-start)
- [1. The model, in five minutes](#1-the-model-in-five-minutes)
- [2. The daily loop](#2-the-daily-loop)
  - [2.1 Commit message prefixes](#21-commit-message-prefixes)
- [3. Branching and pull requests](#3-branching-and-pull-requests)
  - [3.1 Make the branch and push it](#31-make-the-branch-and-push-it)
  - [3.2 What a pull request actually is](#32-what-a-pull-request-actually-is)
  - [3.3 Opening one in Gitea](#33-opening-one-in-gitea)
  - [3.4 The PR page, tab by tab](#34-the-pr-page-tab-by-tab)
  - [3.5 When you are the reviewer](#35-when-you-are-the-reviewer)
  - [3.6 Merging, and cleaning up](#36-merging-and-cleaning-up)
  - [3.7 PR troubleshooting](#37-pr-troubleshooting)
  - [3.8 Branch naming](#38-branch-naming)
- [4. Section A — Practical reference](#4-section-a-practical-reference)
  - [4.1 Starting a repo](#41-starting-a-repo)
  - [4.2 Looking around — do this before every action](#42-looking-around-do-this-before-every-action)
  - [4.3 Staging and committing](#43-staging-and-committing)
  - [4.4 Branching](#44-branching)
  - [4.5 Syncing with Gitea](#45-syncing-with-gitea)
  - [4.6 Undoing things](#46-undoing-things)
  - [4.7 Conflicts](#47-conflicts)
  - [4.8 Ignoring files](#48-ignoring-files)
- [5. Section B — Exhaustive reference](#5-section-b-exhaustive-reference)
  - [5.1 Create and configure](#51-create-and-configure)
  - [5.2 Inspect](#52-inspect)
  - [5.3 Change the working tree and index](#53-change-the-working-tree-and-index)
  - [5.4 Commit and rewrite](#54-commit-and-rewrite)
  - [5.5 Branch, merge, and combine](#55-branch-merge-and-combine)
  - [5.6 Talk to Gitea (or any server)](#56-talk-to-gitea-or-any-server)
  - [5.7 Temporary storage](#57-temporary-storage)
  - [5.8 Debugging and forensics](#58-debugging-and-forensics)
  - [5.9 Multiple checkouts and nested repos](#59-multiple-checkouts-and-nested-repos)
  - [5.10 Maintenance](#510-maintenance)
  - [5.11 Things that are not commands, but you must know](#511-things-that-are-not-commands-but-you-must-know)
- [6. Gitea specifics](#6-gitea-specifics)
  - [6.1 Log in with a token, never your password](#61-log-in-with-a-token-never-your-password)
  - [6.2 SSH instead (optional, nicer once set up)](#62-ssh-instead-optional-nicer-once-set-up)
  - [6.3 The Gitea web UI, mapped to git concepts](#63-the-gitea-web-ui-mapped-to-git-concepts)
  - [6.4 Merge styles Gitea offers on a PR](#64-merge-styles-gitea-offers-on-a-pr)
  - [6.5 Branch protection — expect main to reject you](#65-branch-protection-expect-main-to-reject-you)
  - [6.6 tea — Gitea's official CLI (optional)](#66-tea-giteas-official-cli-optional)
- [7. Git in Visual Studio 2026](#7-git-in-visual-studio-2026)
  - [7.1 One-time setup](#71-one-time-setup)
  - [7.2 The two windows you will live in](#72-the-two-windows-you-will-live-in)
  - [7.3 Command → Visual Studio, side by side](#73-command-visual-studio-side-by-side)
  - [7.4 Resolving a conflict — this part VS genuinely does better](#74-resolving-a-conflict-this-part-vs-genuinely-does-better)
  - [7.5 Visual Studio gotchas](#75-visual-studio-gotchas)
  - [7.6 The one workflow you cannot do in the IDE](#76-the-one-workflow-you-cannot-do-in-the-ide)
- [8. "Oh no" — the recovery section](#8-oh-no-the-recovery-section)
- [9. Hands-on labs](#9-hands-on-labs)
  - [Lab 0 — Identity and an empty repo on Gitea](#lab-0-identity-and-an-empty-repo-on-gitea)
  - [Lab 1 — Your first repository and commit](#lab-1-your-first-repository-and-commit)
  - [Lab 2 — Connect to Gitea and push](#lab-2-connect-to-gitea-and-push)
  - [Lab 3 — The staging area, properly](#lab-3-the-staging-area-properly)
  - [Lab 4 — A branch and a real pull request](#lab-4-a-branch-and-a-real-pull-request)
  - [Lab 5 — Make a conflict on purpose, then fix it](#lab-5-make-a-conflict-on-purpose-then-fix-it)
  - [Lab 6 — Undo, four different ways](#lab-6-undo-four-different-ways)
  - [Lab 7 — Destroy work, then get it back](#lab-7-destroy-work-then-get-it-back)
  - [Lab 8 — Stash: "I need to switch branches right now"](#lab-8-stash-i-need-to-switch-branches-right-now)
  - [Lab 9 — Be your own colleague](#lab-9-be-your-own-colleague)
  - [Lab 10 — .gitignore, and the mistake it does not fix](#lab-10-gitignore-and-the-mistake-it-does-not-fix)
  - [Lab 11 — Tags and a Gitea release](#lab-11-tags-and-a-gitea-release)
  - [Lab 12 — Two more worth knowing](#lab-12-two-more-worth-knowing)
  - [Lab 13 — Do it all again, in Visual Studio 2026](#lab-13-do-it-all-again-in-visual-studio-2026)
  - [Lab 14 — Resolve a conflict in the Merge Editor](#lab-14-resolve-a-conflict-in-the-merge-editor)
  - [Lab 15 — The two commit buttons, and staging individual lines](#lab-15-the-two-commit-buttons-and-staging-individual-lines)
  - [Lab 16 — Undo from the history graph, and the one thing the UI cannot do](#lab-16-undo-from-the-history-graph-and-the-one-thing-the-ui-cannot-do)
  - [Lab 17 — Gitea housekeeping from Visual Studio](#lab-17-gitea-housekeeping-from-visual-studio)
- [10. Make git comfortable](#10-make-git-comfortable)
  - [Aliases — worth 30 seconds, saves them back daily](#aliases-worth-30-seconds-saves-them-back-daily)
  - [Other settings worth having](#other-settings-worth-having)
  - [Where settings live](#where-settings-live)
- [11. Graduating: the real repository](#11-graduating-the-real-repository)
- [12. Rules of thumb](#12-rules-of-thumb)
- [13. Glossary](#13-glossary)
- [Where to go next](#where-to-go-next)

---

## 0. Before you start

Check git is there:

```bash
git --version        # 2.54.0 on this machine — anything 2.30+ is fine
```

**Set your identity. Do this first, before anything else.** Git stamps every commit with a
name and email; it refuses to commit without them, and commits made under the wrong name
cannot be relabelled later without rewriting history.

```bash
git config --global user.name  "Adhir Ranjan"
git config --global user.email "adhirranjan@softtrust.com"

# Use the SAME email as your Gitea account, or Gitea won't link commits to your profile.
git config --global --list      # verify
```

Three settings that will save you real pain, set them now:

```bash
# Windows checks out CRLF line endings and commits LF. Without this, whole files
# show as "changed" when nobody touched them.
git config --global core.autocrlf true

# When your commits and the server's have DIVERGED, `git pull` can reconcile them two
# ways — merge or rebase — and since git 2.34 it refuses to guess: "fatal: Need to
# specify how to reconcile divergent branches." (A plain fast-forward pull, where you
# have no local commits, works fine unconfigured — which is why you can meet this for
# the first time weeks in.) "merge" is the beginner-safe answer: it adds a merge commit
# and never rewrites your commits, whereas rebase replays them with new SHAs — painful
# if you had already pushed them. See §4.5.
git config --global pull.rebase false

# Name the first branch `main` instead of the older `master`. Gitea defaults to main.
git config --global init.defaultBranch main
```

---

## 1. The model, in five minutes

Almost every git confusion comes from not knowing **which of four places** your file is in.

```
   ┌──────────────┐  git add   ┌──────────────┐  git commit  ┌──────────────┐  git push  ┌──────────────┐
   │ Working tree │ ─────────► │   Staging    │ ───────────► │ Local repo   │ ─────────► │    Gitea     │
   │ (your files, │            │    area      │              │  (.git dir,  │            │  (the server,│
   │  as edited)  │ ◄───────── │  ("index")   │ ◄─────────── │ your history)│ ◄───────── │  shared)     │
   └──────────────┘ git restore└──────────────┘  git reset   └──────────────┘  git pull  └──────────────┘
```

- **Working tree** — the actual files on disk. Edit freely; git doesn't care yet.
- **Staging area** — the shortlist of changes that will go into the *next* commit. This is the
  step people find strange; it exists so you can commit *some* of your edits and not others.
- **Local repo** — the `.git` folder. Your full history. Everything works offline.
- **Gitea** — the shared copy. Nothing you do reaches your colleagues until you `push`.

**`git status` tells you where everything is.** Run it constantly. It is not a stupid question;
experienced developers run it more often than beginners do.

A **commit** is a snapshot of the whole project plus a message, an author and a parent commit.
A **branch** is a sticky note pointing at one commit — that's genuinely all it is, which is why
creating and deleting branches is instant and cheap.

---

## 2. The daily loop

Nine commands cover ~95% of your day.

```bash
git status                        # 1. where am I, what's changed?      ← run this constantly
git pull                          # 2. get everyone else's work first
git switch -c feature/add-taluka  # 3. new branch for your work
                                  # 4. ... edit files in your editor ...
git diff                          # 5. review what you changed, before staging
git add Ledger.cs                 # 6. stage the files you want to commit
git commit -m "Add taluka lookup" # 7. snapshot them, with a message
git push -u origin feature/add-taluka  # 8. send the branch to Gitea
                                  # 9. open a Pull Request in the Gitea web UI
```

Then repeat 4–8 as many times as you like. Small commits are better than big ones — they are
easier to review, and easier to undo when one of them turns out to be wrong.

**Commit messages.** First line ≤ 72 characters, imperative mood ("Add taluka lookup", not
"Added" or "Adding"), explaining **why** if it isn't obvious. Start it with one of this repo's
`CHANGELOG.md` type words (§2.1):

```
fix: reference cache ignored Cache:Provider

AddControllersWithViews registers a default MemoryDistributedCache before
AddCbsFramework runs, so the provider switch short-circuited on every startup.
```

---

### 2.1 Commit message prefixes

`feat` / `fix` / `docs` / `refactor` / `test` are **Conventional Commits** — a convention, not a
git feature. Git will happily accept any message; this is a habit the team keeps because
[`CHANGELOG.md`](../../CHANGELOG.md) already uses these words across 231 entries. Match them and
your commit message and your changelog line become the same sentence, written once.

| Prefix | Means | The question it answers |
|---|---|---|
| `feat` | A new capability that did not exist | Can someone now do something they could not before? |
| `fix` | Something was broken; now it is not | Was there a defect? Would you write "the bug where…"? |
| `docs` | Documentation only | Did any shipping code change? If no → `docs` |
| `refactor` | Code changed, behaviour did not | Would a user notice? If no → `refactor` |
| `test` | Tests added or changed | Only test projects touched |
| `chore` | Housekeeping that is none of the above | Deleting a stale file, bumping a package. The honest bucket — not a way to avoid choosing |

Real examples from this repo's changelog:

```
feat:     `_DatePicker` gains a calendar
fix:      `_DatePicker` with HideDay now renders the hidden ISO value with day = 1
docs:     corrected an over-broad claim in git-with-gitea.md §0
refactor: routecutover.json retired — a_Menus.NavigateURL is now the single source of truth
test:     Playwright E2E suite TflCbs.E2E
chore:    deleted the stale TflCbs.Host.Main/TflCbs.Host.Main.slnx
```

**The two that get confused:**

- **`fix` vs `refactor`** — did behaviour change? `refactor` means the code looks different and does
  *exactly* the same thing. The moment output changes it is `fix` or `feat`.
- **`feat` vs `fix`** — was it ever supposed to work? A screen that never had a calendar getting one
  is `feat`. A calendar that renders the wrong date is `fix`.

**The optional part in brackets is a scope** — which area of the system:

```
feat(security):         ...
fix(docker-multi):      ...
refactor(core-modules): ...
```

About a fifth of this repo's entries carry one, always where the area is not obvious from the
sentence. Add a scope when it helps someone scanning; skip it when the summary already says where.
Do not force one onto every commit.

**Why bother**, in the order it will actually matter to you:

1. **It is greppable.** `git log --oneline --grep "^fix"` gives you every bug fix; release notes
   write themselves.
2. **It forces a decision.** If you cannot tell whether your commit is `feat` or `refactor`, it is
   usually *both* — which means it should have been two commits. The prefix catches unfocused work
   before a reviewer has to.
3. **Commits and changelog stop drifting**, because you write the sentence once.

Standard types this repo does not use — `perf`, `style`, `build`, `ci` — and the breaking-change
markers `feat!:` / a `BREAKING CHANGE:` footer are all noise until you need them. Six words is
plenty.


---

## 3. Branching and pull requests

**Never commit directly to `main`.** Branch, push, open a PR, get it reviewed, merge. That is the
whole workflow, and it is the same on every team you will ever join.

### 3.1 Make the branch and push it

```bash
git switch main                     # start from main
git pull                            # make sure it's current
git switch -c fix/locker-penal-label   # branch off it

# ... work, add, commit ... (as many commits as you like)

git push -u origin fix/locker-penal-label   # -u only needed the FIRST push of a branch
```

**Pushing a branch changes nothing about `main`.** Your branch now sits on the server *beside*
main, and the two are unrelated until something merges them. That something is the pull request.

### 3.2 What a pull request actually is

**A pull request is not a git feature.** Git — the program on your machine — knows about commits,
branches and remotes, and has no idea what a PR is. `git help -a` will never list one. Pull
requests were invented by the web platforms (GitHub first, then Gitea, GitLab, Azure DevOps) and
live entirely on the **server**.

A PR is a page on Gitea that says *"please merge my branch into `main`"*, wrapped around three
things:

1. **A diff** — Gitea has both branches, so it computes exactly what changes if the merge happens.
2. **A conversation** — comments on the change as a whole, and on individual lines of code.
3. **A merge button** — which performs the merge *on the server*.

That is the entire concept: a branch, a computed diff, a comment thread, and a button.

**Why it exists.** Without a PR, "merging your work" means running `git merge` locally and pushing
to `main`. Nobody saw it, nobody could object, and there is no record of why. The PR inserts a
deliberate pause between *"I have finished"* and *"it is in main"* — a place for a second pair of
eyes, for automated checks to run, and for a written reason that outlives everyone's memory.

**The name is backwards, and it confuses everybody.** You are not pulling anything. *You* are
asking *the maintainer* to pull from your branch — the name survives from the original email-based
workflow (`git request-pull`, still listed in §5.6). GitLab calls it a **Merge Request**, which is
what it actually is. Read "PR" as "merge request" and it stops being strange.

Where the work lives at each step:

```
git switch -c feature/x        LOCAL ONLY   Gitea knows nothing about this yet
    ...commits...              LOCAL ONLY   still nothing
git push -u origin feature/x   ON GITEA     your branch now exists, beside main.
                                            main is UNCHANGED.
open a PR in the browser       ON GITEA     "compare these two branches for me"
    review, discussion
    more commits pushed        ON GITEA     the PR updates itself, automatically
click Merge                    ON GITEA     the server merges; main moves
git switch main && git pull    LOCAL        you bring the result back down
```

**Do them even when you are the only developer.** Solo, a PR costs thirty seconds and still gives
you one readable view of everything you are about to make permanent in `main`. That is how you
catch the committed password.

### 3.3 Opening one in Gitea

**There is no CLI for this, and there is no Visual Studio button for it** (§7) — Gitea's pull
requests live behind its own web API, which neither `git` nor Visual Studio speaks. The browser is
the way.

1. Go to `http://192.168.0.22:3000/Adhir/git-practice`
2. Gitea shows a banner: *"fix/locker-penal-label had recent pushes — Compare & Pull Request"*.
   Click it. (Or: the **Pull Requests** tab → **New Pull Request**.)
3. **Check the direction: base `main` ← compare `your-branch`.** Getting these backwards is the
   single most common PR mistake, and it produces a confusing empty or enormous diff.
4. **Title** — the same rules as a commit subject (§2): short, imperative, specific.
   *"Fix penal-interest label on locker type screen"*, not *"changes"*.
5. **Description** — what changed, **why**, and how you know it works. If it touches a screen, say
   which. If it fixes an issue, write `Fixes #12` and Gitea closes issue 12 automatically when the
   PR merges.
6. Assign a **reviewer**. A PR nobody is assigned to is a PR nobody reads.
7. **Create Pull Request**.

**Not ready for review yet?** Start the title with `WIP:` — Gitea treats it as a work-in-progress
and blocks merging until you remove the prefix. Useful for showing someone a direction early
without risking an accidental merge.

### 3.4 The PR page, tab by tab

| Tab | What it holds |
|---|---|
| **Conversation** | The description, all comments, and the merge button. The narrative record |
| **Commits** | Your commits in order. This is why messages matter — a reviewer reads this list first |
| **Files Changed** | The diff. Where line-by-line review happens |

In **Files Changed**, hover any line and click the **+** to comment on exactly that line. That is
the whole mechanism of code review: specific comments attached to specific lines, which stay
attached as the code changes.

**Responding to review is just more commits:**

```bash
# still on your branch, in the same folder
# ... make the requested changes ...
git commit -am "fix: address review — clamp the rate at 100%"
git push                      # no -u; the branch is already linked
```

Refresh the PR — the new commit is in it. **Never close a PR and open a new one** to incorporate
feedback; you would throw away the entire discussion. The PR tracks the *branch*, so anything you
push to that branch is in the PR automatically.

### 3.5 When you are the reviewer

You will be on this side too, so know what is expected:

- Read the **description** first, then **Commits**, then **Files Changed**. In that order — you
  need the intent before the diff means anything.
- Comment on lines, not on people. *"This throws if the list is empty"* — not *"you forgot"*.
- Distinguish blocking from optional. Prefix nits: *"nit: spelling"* — the author then knows what
  must change and what is taste.
- **Approve** / **Request changes** / **Comment** are the three verdicts. Choosing "Comment" when
  you mean "Request changes" leaves the author guessing.
- Pull it down and run it when the change is non-trivial:
  ```bash
  git fetch
  git switch fix/locker-penal-label   # tracks origin's branch automatically
  dotnet build && dotnet test
  ```

### 3.6 Merging, and cleaning up

Gitea offers four merge styles — see §6.4 for which does what. Ask the team which one to use and
be consistent.

Two things Gitea may stop you with, both normal:

- **"This branch has conflicts that must be resolved"** — `main` moved under you. Fix it locally:
  ```bash
  git switch main && git pull
  git switch fix/locker-penal-label
  git merge main            # resolve conflicts here, as in §4.7
  git push                  # the PR re-checks itself and goes green
  ```
- **"Required approvals not met"** — branch protection (§6.5). Get the review.

Once merged:

```bash
git switch main
git pull                                     # bring the merge down
git branch -d fix/locker-penal-label         # delete local branch (-d refuses if unmerged)
git fetch --prune                            # drop the stale remote-tracking ref
```

Gitea can delete the remote branch for you at merge time — take the offer. Stale branches pile up
fast and nobody ever cleans them later.

### 3.7 PR troubleshooting

| Symptom | Cause and fix |
|---|---|
| The diff is empty | Base and compare are the same branch, or you never pushed. `git push` and re-check the direction |
| The diff is enormous and full of files you never touched | Base and compare are backwards, or you branched off the wrong branch. Re-open with the right base |
| "Nothing to compare, branches are identical" | Your commits are still local. `git push` |
| Your branch is not in the dropdown | Not pushed yet, or pushed to a different remote. `git push -u origin <branch>` |
| The PR shows commits that are not yours | You branched off someone else's branch instead of `main`. Rebase onto main, or re-branch and cherry-pick (§5.4) |
| "Merge conflicts" | See §3.6 |
| Cannot merge, no button | Branch protection, unmet approvals, or a `WIP:` title |
| You closed the PR by accident | Reopen it on the same page — the branch and discussion are intact |
| You force-pushed and the review comments now point at nothing | Comments on rewritten commits become "outdated". Avoid force-pushing a branch that is under review |

### 3.8 Branch naming

Pick a convention and stick to it:

| Prefix | For |
|---|---|
| `feature/` | new functionality |
| `fix/` | bug fixes |
| `refactor/` | no behaviour change |
| `docs/` | documentation only |
| `spike/` | throwaway experiments |

One branch, one purpose. A branch that fixes a bug *and* renames a folder *and* adds a feature is
a PR nobody can review properly.

---

## 4. Section A — Practical reference

The commands you will actually type. Every one has a purpose, an example, and the gotcha that
bites people.

### 4.1 Starting a repo

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git init` | Turn the current folder into a repo | `git init` | Creates `.git/`. Run it in the project root, never in your home folder. |
| `git clone <url>` | Copy an existing repo from Gitea | `git clone http://192.168.0.22:3000/Adhir/git-practice.git` | Creates a *new subfolder*. Do not `mkdir` first. |
| `git clone <url> <dir>` | Clone into a named folder | `git clone <url> practice` | — |
| `git remote -v` | Show which server this repo talks to | `git remote -v` | Two lines (fetch + push) is normal, not a duplicate. |
| `git remote add origin <url>` | Point a local repo at Gitea | `git remote add origin http://192.168.0.22:3000/Adhir/git-practice.git` | `origin` is just a nickname, not a keyword. |
| `git remote set-url origin <url>` | Change the server URL | `git remote set-url origin https://new-host/x.git` | Use this after a server move — do not remove and re-add. |

### 4.2 Looking around — do this before every action

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git status` | What changed, what is staged, which branch | `git status` | The single most useful command. Its hints name the exact command to undo things. |
| `git status -s` | Same, one line per file | `git status -s` | `M`=modified `A`=added `??`=untracked. Left column = staged, right = unstaged. |
| `git diff` | Unstaged changes (working tree vs staging) | `git diff` | Shows **nothing** for files you already added. That confuses everyone once. |
| `git diff --staged` | Staged changes (what will be committed) | `git diff --staged` | Run this right before committing. `--cached` is a synonym. |
| `git diff main` | Your branch vs main | `git diff main -- Ledger.cs` | `--` separates paths from branch names. |
| `git log` | History | `git log` | Press `q` to quit the pager. |
| `git log --oneline --graph --all` | Readable history with branches | `git log --oneline --graph --all -20` | Alias this (§10). You will want it hourly. |
| `git log -p <file>` | History of one file, with diffs | `git log -p Ledger.cs` | — |
| `git show <commit>` | One commit in full | `git show a1b2c3d` | `git show HEAD` = the last commit. |
| `git blame <file>` | Who last changed each line, and when | `git blame Ledger.cs` | For understanding, not for blaming. Use `-w` to ignore whitespace churn. |

### 4.3 Staging and committing

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git add <file>` | Stage one file | `git add Ledger.cs` | — |
| `git add .` | Stage everything under the current folder | `git add .` | **Check `git status` first.** This is how secrets and `bin/` folders get committed. |
| `git add -p` | Stage selected *hunks* of a file | `git add -p Ledger.cs` | `y`/`n`/`s` (split)/`q`. Excellent for separating two unrelated edits. |
| `git commit -m "msg"` | Commit what is staged | `git commit -m "Add taluka lookup"` | Commits **only staged** changes. Unstaged edits stay put. |
| `git commit` | Commit, writing the message in an editor | `git commit` | Needed for multi-line messages. Set `core.editor` if the default is unfamiliar. |
| `git commit -am "msg"` | Stage all *tracked* files and commit | `git commit -am "Fix typo"` | Does **not** add new/untracked files. A frequent surprise. |
| `git commit --amend` | Fix the last commit (message or content) | `git commit --amend -m "Better message"` | **Only if you have not pushed.** It rewrites the commit. |
| `git commit --amend --no-edit` | Add a forgotten file to the last commit | `git add missed.cs && git commit --amend --no-edit` | Same rule: unpushed only. |

### 4.4 Branching

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git branch` | List local branches | `git branch` | `*` marks the current one. |
| `git branch -a` | List local + remote branches | `git branch -a` | `remotes/origin/x` is a *cached* view; refresh with `git fetch`. |
| `git switch <name>` | Move to an existing branch | `git switch main` | Modern replacement for `git checkout <branch>`. |
| `git switch -c <name>` | Create a branch and move to it | `git switch -c feature/x` | Branches off wherever you are — `git switch main` first if you mean main. |
| `git switch -` | Back to the previous branch | `git switch -` | Like `cd -`. |
| `git branch -d <name>` | Delete a merged branch | `git branch -d feature/x` | Refuses if unmerged — that refusal is a feature. |
| `git branch -D <name>` | Force-delete a branch | `git branch -D spike/junk` | Recoverable via `git reflog` for ~90 days. |
| `git branch -m <new>` | Rename the current branch | `git branch -m fix/better-name` | If already pushed, delete the old remote branch and push again. |
| `git merge <branch>` | Bring another branch's work into this one | `git switch main && git merge feature/x` | Merge *into* where you are standing. |
| `git merge --abort` | Undo a merge that hit conflicts | `git merge --abort` | Puts everything back exactly as it was. Safe. |

### 4.5 Syncing with Gitea

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git fetch` | Download new commits, change nothing locally | `git fetch` | The safe way to look before you leap. |
| `git fetch --prune` | Fetch, and drop refs for branches deleted on the server | `git fetch --prune` | Run occasionally or `git branch -a` fills with ghosts. |
| `git pull` | Fetch **and** integrate into your branch | `git pull` | Equals `fetch` + `merge` — or `fetch` + `rebase` if `pull.rebase` says so (§0). Merge adds a merge commit and leaves your commits alone; rebase replays them with new SHAs, so never rebase commits you have already pushed. Conflicts here are normal. |
| `git push` | Send your commits to Gitea | `git push` | Rejected? Someone else pushed — pull first, then push again. |
| `git push -u origin <branch>` | First push of a new branch | `git push -u origin feature/x` | `-u` links them, so later `git push`/`git pull` need no arguments. |
| `git push origin --delete <branch>` | Delete a branch on the server | `git push origin --delete feature/x` | Gitea can do this for you when a PR merges. |
| `git push --force-with-lease` | Overwrite the remote branch, safely | `git push --force-with-lease` | **Never on `main`.** Only your own branch, after a rebase or amend. It refuses if someone else pushed meanwhile — which is exactly why it is not plain `--force`. |

**Look before you pull.** `git pull` is `fetch` + `merge` in one go, so it changes your branch
before you have seen what arrived. Split it in two whenever you care what is coming:

```bash
git fetch                    # download the server's commits. Your branch, tree and index are NOT touched

git status -sb               # the one-line answer: "## main...origin/main [behind 1]"
git log --oneline HEAD..origin/main   # commits THEY have that you do not  <- exactly what pull will bring in
git log --oneline origin/main..HEAD   # commits YOU have that they do not  <- exactly what push would send
git diff --stat HEAD origin/main      # which files differ, and by how much
git diff HEAD origin/main             # the actual line-by-line difference
git log --oneline --graph --all -10   # the shape of both sides at once

git pull                     # now merge it in, knowing what you are getting
```

**`A..B` means "commits reachable from B but not from A".** Read `HEAD..origin/main` as *"what is
on the server that is not on me"*, and flip the order to ask the opposite. It is the same syntax a
pull request uses to build its diff (§3). Three dots — `git log --oneline --left-right
HEAD...origin/main` — lists **both** directions at once, marking each commit `<` yours or `>` theirs.

None of this can cost you anything: `fetch`, `status`, `log` and `diff` only ever read, and `fetch`
writes only to `refs/remotes/origin/*` — the cache, never your work.

### 4.6 Undoing things

The most important table in this document. **Nothing committed is ever really lost** — see §8.

| Command | Purpose | Example | Gotcha |
|---|---|---|---|
| `git restore <file>` | Throw away unstaged edits to a file | `git restore Ledger.cs` | **Destructive and unrecoverable** — those edits were never in git. |
| `git restore --staged <file>` | Unstage, keeping your edits | `git restore --staged Ledger.cs` | The exact opposite of `git add`. Perfectly safe. |
| `git restore --source=HEAD~2 <file>` | Get a file back as it was N commits ago | `git restore --source=HEAD~2 Ledger.cs` | Does not move your branch, only the file. |
| `git revert <commit>` | Undo a commit by making a new, opposite commit | `git revert a1b2c3d` | **The safe undo for anything already pushed.** History is added to, never rewritten. |
| `git reset --soft HEAD~1` | Undo last commit, keep changes staged | `git reset --soft HEAD~1` | Great for "I committed too early". |
| `git reset HEAD~1` | Undo last commit, keep changes unstaged | `git reset HEAD~1` | The default mode (`--mixed`). |
| `git reset --hard HEAD~1` | Undo last commit and **destroy the changes** | `git reset --hard HEAD~1` | The one genuinely dangerous command. Uncommitted work is gone for good. Commit first, always. |
| `git clean -nd` | *Preview* deleting untracked files | `git clean -nd` | Always run the `-n` preview first. |
| `git clean -fd` | Delete untracked files and folders | `git clean -fd` | Unrecoverable. Respects `.gitignore` unless you add `-x`. |
| `git stash` | Park uncommitted work temporarily | `git stash` | For "I need to switch branch right now". |
| `git stash pop` | Bring parked work back | `git stash pop` | `pop` removes it from the stash; `apply` keeps a copy. |
| `git stash list` | See what you parked | `git stash list` | Easy to forget things here. Check before assuming work is lost. |

### 4.7 Conflicts

A conflict means two branches changed the *same lines* and git will not guess. It is routine,
not a failure.

```text
<<<<<<< HEAD                                    <- what is on YOUR current branch
    public const string Version = "1.1";
=======                                         <- divider
    public const string Version = "2.0";
>>>>>>> feature/x                               <- what is on the branch coming in
```

To resolve: **open the file, delete all three marker lines, leave the code you want** (which may
be one side, or a mix, or something new), then:

```bash
git add Ledger.cs        # "I have resolved this file"
git status               # any files left conflicted? repeat.
git commit               # completes the merge (git pre-fills the message)
```

Escape hatches, if it turns into a mess:

| Command | Purpose |
|---|---|
| `git merge --abort` | Cancel the whole merge, back to exactly before |
| `git checkout --ours <file>` | Keep your branch's version of that file entirely |
| `git checkout --theirs <file>` | Keep the incoming version entirely |
| `git diff --name-only --diff-filter=U` | List just the still-conflicted files |

### 4.8 Ignoring files

`.gitignore` lists what git should pretend does not exist — build output, secrets, local config.
This repo already has a well-considered one at [.gitignore](../../.gitignore).

```gitignore
bin/                                     # a folder, at any depth
obj/
*.user                                   # by extension
**/appsettings.Development.json          # local DB credentials — never commit
!appsettings.Development.json.example    # ! un-ignores an exception
```

**The catch:** `.gitignore` only affects files git is not *already* tracking. If `bin/` was
committed once, ignoring it later changes nothing. Fix it with:

```bash
git rm -r --cached bin/     # stop tracking, keep the files on disk
git commit -m "Stop tracking build output"
```

---

## 5. Section B — Exhaustive reference

Every user-facing ("porcelain") git command, grouped by what it is for. You will not need most
of these — they are here so that when you meet one in a Stack Overflow answer you know what it
does before you paste it. Plumbing commands (`cat-file`, `update-ref`, `hash-object`, …) are
deliberately excluded: they are for writing tools, not for using git.

**Legend:** ★ = in §4, you will use it constantly · ☆ = occasional · ○ = rare/specialist.

### 5.1 Create and configure

| Command | What it does |
|---|---|
| ★ `git init` | Create a new repository in the current folder |
| ★ `git clone` | Copy a repository (and its whole history) from a server |
| ★ `git config` | Read/write settings. `--global` = you, `--local` = this repo, `--system` = machine |
| ☆ `git help <cmd>` | Full manual page for any command. `git help -a` lists everything |
| ○ `git init --bare` | Create a repo with no working files — what a *server* holds |

### 5.2 Inspect

| Command | What it does |
|---|---|
| ★ `git status` | Working tree and staging summary |
| ★ `git diff` | Line-by-line changes between any two of: working tree, index, commits |
| ★ `git log` | Commit history, filterable a hundred ways |
| ★ `git show` | Show one object (commit, tag, blob) in full |
| ★ `git blame` | Annotate each line with the commit that last touched it |
| ☆ `git shortlog` | History grouped by author — `-sn` gives a contribution count |
| ☆ `git describe` | Human-readable name for a commit, based on the nearest tag |
| ☆ `git grep` | Search tracked files. Faster than plain grep and can search *old commits* |
| ☆ `git reflog` | **Log of where HEAD has been.** Your safety net — see §8 |
| ○ `git count-objects -vH` | Repository size on disk |
| ○ `git fsck` | Check the object database for corruption / find dangling commits |
| ○ `git whatchanged` | Older, rougher `git log --stat`. Superseded |

### 5.3 Change the working tree and index

| Command | What it does |
|---|---|
| ★ `git add` | Stage changes for the next commit |
| ★ `git restore` | Restore files from the index or a commit (modern, split out of `checkout`) |
| ★ `git rm` | Delete a file *and* stage the deletion. `--cached` = untrack but keep on disk |
| ☆ `git mv` | Rename/move a file and stage it. Git detects renames anyway — this is convenience |
| ☆ `git clean` | Delete untracked files. Preview with `-n` first, always |
| ○ `git sparse-checkout` | Check out only part of a huge repo |
| ○ `git update-index --skip-worktree` | Tell git to ignore local changes to a *tracked* file |

### 5.4 Commit and rewrite

| Command | What it does |
|---|---|
| ★ `git commit` | Record the staged snapshot |
| ★ `git revert` | Create a new commit that undoes an old one — safe after pushing |
| ★ `git reset` | Move the branch pointer. `--soft` keeps staged, `--mixed` keeps unstaged, `--hard` destroys |
| ☆ `git rebase` | Replay your commits on top of another branch — a linear history instead of a merge |
| ☆ `git rebase -i` | *Interactive*: reorder, squash, reword, drop commits before sharing them |
| ☆ `git cherry-pick` | Copy one specific commit from another branch onto this one |
| ○ `git commit --fixup` / `git rebase --autosquash` | Mark a commit as a fix for an earlier one, then fold them together automatically |
| ○ `git filter-repo` | Rewrite the entire history (e.g. purge a leaked secret). Not built in; replaces the old `filter-branch` |
| ○ `git replace` | Graft a substitute object over another without rewriting |

### 5.5 Branch, merge, and combine

| Command | What it does |
|---|---|
| ★ `git branch` | List, create, rename, delete branches |
| ★ `git switch` | Change which branch you are on |
| ★ `git merge` | Join two histories together |
| ☆ `git checkout` | The old command that did `switch` **and** `restore`. Still works; still in every old answer online. Prefer the two new ones |
| ☆ `git tag` | Mark a commit permanently — releases, versions. `-a` for an annotated tag |
| ☆ `git range-diff` | Compare two versions of a branch (e.g. before/after a rebase) |
| ○ `git merge --squash` | Combine a branch into a single un-committed change set |
| ○ `git rerere` | "Reuse recorded resolution" — remembers how you solved a conflict and redoes it next time |

### 5.6 Talk to Gitea (or any server)

| Command | What it does |
|---|---|
| ★ `git fetch` | Download refs and objects; change nothing you are working on |
| ★ `git pull` | `fetch` + integrate (`merge` by default, `rebase` with `--rebase`) |
| ★ `git push` | Upload your commits, and create/update/delete remote branches |
| ★ `git remote` | Manage the named URLs (`origin`, and any others) |
| ☆ `git ls-remote` | List a server's branches/tags without cloning anything |
| ○ `git bundle` | Pack a repo into one file, to move history over a USB stick / air gap |
| ○ `git archive` | Export a tree as a `.zip`/`.tar` with no `.git` history |
| ○ `git request-pull` | Generate a plain-text PR summary. Predates web PRs |

### 5.7 Temporary storage

| Command | What it does |
|---|---|
| ★ `git stash` | Park uncommitted work and clean the tree |
| ★ `git stash pop` / `apply` / `list` / `drop` | Retrieve, inspect, discard parked work |
| ○ `git stash -u` | Include untracked files (they are otherwise left behind) |

### 5.8 Debugging and forensics

| Command | What it does |
|---|---|
| ☆ `git bisect` | Binary-search the history for the commit that introduced a bug. Genuinely magical on a 5000-commit repo — `start` / `bad` / `good`, then test what it checks out, `git bisect reset` at the end |
| ☆ `git reflog` | Recover "lost" commits, branches, and bad resets |
| ○ `git log -S "text"` | Find the commit that added or removed a specific string ("pickaxe") |
| ○ `git log -L 10,20:file` | History of just those lines of that file |
| ○ `git notes` | Attach notes to a commit after the fact, without rewriting it |

### 5.9 Multiple checkouts and nested repos

| Command | What it does |
|---|---|
| ☆ `git worktree` | Check out a second branch into a second folder, sharing one `.git`. Better than cloning twice |
| ○ `git submodule` | Embed another repo at a fixed commit. Powerful, and a well-known source of pain |
| ○ `git subtree` | Merge another repo's history into a subfolder. The alternative to submodules |
| ○ `git lfs` | Large File Storage — keeps big binaries out of the history. An add-on, not built in |

### 5.10 Maintenance

| Command | What it does |
|---|---|
| ○ `git gc` | Garbage-collect and compress. Runs automatically; rarely needed by hand |
| ○ `git prune` | Delete unreachable objects (this is what finally removes reflog-recoverable commits) |
| ○ `git repack` | Repack objects for size/speed |
| ○ `git maintenance` | Schedule background upkeep on large repos |

### 5.11 Things that are not commands, but you must know

| Thing | Meaning |
|---|---|
| `HEAD` | Where you are right now — normally the tip of the current branch |
| `HEAD~1`, `HEAD~3` | 1 / 3 commits *back* from here |
| `HEAD^` | The first parent (matters only at merge commits) |
| `origin` | The default nickname for your Gitea server |
| `origin/main` | Your *cached* copy of the server's `main`. Only updates on `fetch`/`pull` |
| `A..B` | Commits reachable from `B` but not from `A`. `HEAD..origin/main` = what the server has that you do not |
| `A...B` | Commits on *either* side but not both — with `--left-right`, `<` marks yours and `>` theirs |
| `main` | The mainline branch. Older repos call it `master` |
| detached HEAD | You checked out a commit, not a branch. Commits made here belong to no branch — `git switch -c name` to keep them |
| fast-forward | A merge with nothing to merge: git just slides the pointer forward |
| `.git/` | The whole repository. Delete it and you have deleted your history |

---

## 6. Gitea specifics

Everything so far is universal git. This section is about our server.

### 6.1 Log in with a token, never your password

Gitea will prompt for a username and password on your first `push`. **Do not type your account
password** — generate a Personal Access Token (PAT) instead. A token can be scoped and revoked
without changing your login, and it is what Gitea expects.

1. Gitea → click your avatar → **Settings** → **Applications**
2. **Generate New Token**. Name it after the machine (`work-laptop`)
3. Select scopes — `repo` is enough for normal work (read/write code, issues, PRs)
4. **Generate Token**, then **copy it now**. Gitea shows it exactly once.

Then store it so you are not asked every time:

```bash
# Windows: uses the built-in Windows Credential Manager (encrypted, per-user)
git config --global credential.helper manager

# Next push prompts once: username = your Gitea username, password = PASTE THE TOKEN.
# It is saved from then on.
```

To replace a token later: Windows **Credential Manager** → *Windows Credentials* → find the
`git:http://192.168.0.22:3000` entry → edit or remove it.

**Never** put the token in the remote URL (`http://user:token@host/...`) — it lands in
`.git/config` in clear text and leaks into any log that echoes the remote.

> **This server is plain HTTP, not HTTPS.** `http://192.168.0.22:3000` sends your token, and every
> byte you push and pull, unencrypted across the LAN. That is normally acceptable for an internal
> server on a trusted network, and it is what we have today — but be aware of it, and treat the
> token as LAN-visible: scope it to `repo`, never reuse it elsewhere, and revoke it (Gitea →
> Settings → Applications) the moment a machine is retired. **§6.2 (SSH) avoids this entirely**
> and is the better option if the server has SSH enabled — the traffic is encrypted even though
> the web UI is not. Worth raising with whoever administers the server: a TLS certificate on
> Gitea would close this properly.

### 6.2 SSH instead (optional, nicer once set up)

```bash
ssh-keygen -t ed25519 -C "adhirranjan@softtrust.com"     # Enter x3 accepts the defaults
cat ~/.ssh/id_ed25519.pub                          # copy this whole line
# Gitea → Settings → SSH / GPG Keys → Add Key → paste
ssh -T git@192.168.0.22                               # verify

git remote set-url origin git@192.168.0.22:Adhir/git-practice.git
```

No tokens, no prompts. Use HTTPS+token if your network blocks SSH.

### 6.3 The Gitea web UI, mapped to git concepts

| In Gitea | Is | Notes |
|---|---|---|
| **Code** | your files at the tip of the selected branch | The branch dropdown top-left |
| **Issues** | to-do items / bug reports | Say `Fixes #12` in a commit or PR to auto-close issue 12 on merge |
| **Pull Requests** | a request to merge branch A into branch B | Reviewed and merged here. There is no CLI for this |
| **Releases** | annotated tags, with files attached | Built on `git tag` |
| **Wiki** | a second git repo, for prose | Cloneable separately |
| **Activity / Insights** | commit graphs, contributors | Reads your commit *email* — see §0 |
| **Settings → Branches** | branch protection | Where "you cannot push to main" is configured |
| **Settings → Webhooks** | fire an HTTP call on push/PR | The CI hook-up point |

### 6.4 Merge styles Gitea offers on a PR

| Style | Result | When |
|---|---|---|
| **Merge** | Keeps every commit, adds a merge commit | Default. Full, honest history |
| **Rebase and merge** | Replays your commits onto main, no merge commit | Linear history, if the team wants that |
| **Squash and merge** | All your commits collapse into one | Great when your branch has 14 "wip" commits |
| **Fast-forward only** | Refuses unless the branch is already up to date | Strictest |

Ask which one this team uses and be consistent. Squash is the friendliest default for a learner —
your messy branch history never reaches `main`.

### 6.5 Branch protection — expect `main` to reject you

If an admin enabled protection on `main`, a direct `git push` to it fails by design:

```
! [remote rejected] main -> main (protected branch hook declined)
```

That is not a bug and not a permissions problem to escalate. Branch, push, PR.

---

### 6.6 `tea` — Gitea's official CLI (optional)

Every git tutorial you find online will sooner or later type `gh`. **`gh` is the GitHub CLI** — a
separate program from git, which does the things that live on GitHub's *website* rather than in
git itself (`gh pr create`, `gh issue list`, `gh pr checkout 42`). It talks to github.com and
nowhere else. Run it here and you get "command not found" or an authentication failure against a
server that has nothing to do with us. That is not you doing something wrong.

**`tea` is the Gitea equivalent.** Same idea, our server: pull requests, issues and releases from
the terminal instead of the browser.

> **You do not need this.** Nothing in this guide requires `tea`, and the labs in §9 never use it.
> Learn git first. Come back here when opening the browser for every PR starts to annoy you.

**Install** — a single binary, no runtime:

1. Download the Windows build from the releases page: <https://gitea.com/gitea/tea/releases>
   (`tea-<version>-windows-amd64.exe`).
2. Rename it to `tea.exe` and put it in a folder that is on your `PATH`.
3. `tea --version` to confirm.

**Log in** — with the same Personal Access Token from §6.1, never your password:

```bash
tea login add --name trustbank --url http://192.168.0.22:3000 --token <YOUR-PAT>
tea login list                      # confirm it is there
```

**What it can do** — run from inside a cloned repo, which is how it knows which project you mean:

| Command | Does |
|---|---|
| `tea pr create --base main --head feature/x --title "..."` | Open a pull request without leaving the terminal |
| `tea pr list` | Open PRs on this repo |
| `tea pr <number>` | Show one PR — title, state, branches |
| `tea pr checkout <number>` | Check out someone else's PR branch locally to test it |
| `tea pr merge <number>` | Merge it (if you have the rights) |
| `tea issue list` / `tea issue create` | Issues |
| `tea release create --tag v1.0` | A Gitea release from a tag |
| `tea notifications` | Your Gitea notification inbox |
| `tea open` | Open the current repo's Gitea page in the browser |
| `tea <command> --help` | The authoritative flag list — trust this over any doc, including this one |

**What it does not do.** `tea` is not a git replacement. Cloning, branching, staging, committing,
pushing — all still plain `git`, exactly as in §4. `tea` only covers the layer *above* git, the
same layer the web UI covers.

**Two cautions:**

- **Your token lands in a config file** (`%USERPROFILE%\.config\tea\config.yml`) in readable form.
  That is a file on your disk holding write access to our source. Treat it like a password file,
  and revoke the token in Gitea (**Settings → Applications**) if the machine is ever lost or handed on.
- **Reviewing code in a terminal is worse than reviewing it in a browser.** `tea pr create` is a
  genuine convenience — you are already in the terminal, you just pushed. But reading a diff,
  commenting on line 47 and having a conversation about it are things the Gitea web UI does far
  better. Most people end up creating PRs with `tea` and reviewing them in the browser.

---

## 7. Git in Visual Studio 2026

Visual Studio's Git tooling is a **skin over the same git you have been typing** — every button
runs one of the commands from §4. Nothing in this section is a different system, and nothing you
do in the UI is invisible from the command line.

Two honest framings before the tables:

- **Learn the commands first.** The UI hides which of the four places (§1) your change is in, which
  is exactly the thing beginners need to see. Do the labs in §9 at the command line, then switch to
  the UI once you can predict what each button will do.
- **Visual Studio does not know what Gitea is.** Its Pull Request features light up only for GitHub
  and Azure DevOps. To Visual Studio our server is just a generic HTTPS remote — which works
  perfectly for clone/fetch/pull/push/branch/merge, and not at all for PRs. **Pull requests are
  created and reviewed in the Gitea web UI, always** (§3, §6.3).

---

### 7.1 One-time setup

**Identity** — already set on this machine (§0), and Visual Studio reads the same global config.
To check or change it: **Git → Settings → Git Global Settings** (name and email at the top).
It is the same file as `git config --global`; there is no separate VS identity.

**Built-in terminal** — **View → Terminal** (`` Ctrl+` ``). Every lab in §9 can be typed here
without leaving the IDE. Keep it open: when the UI does something you did not expect, `git status`
and `git log --oneline --graph --all` will tell you what actually happened.

**Credentials** — the first push prompts for a username and password. Enter `Adhir` and **paste
your Personal Access Token** as the password (§6.1), not your account password. Windows Credential
Manager stores it, and Visual Studio never asks again.

---

### 7.2 The two windows you will live in

| Window | Where | What it is |
|---|---|---|
| **Git Changes** | **View → Git Changes** | Your working tree and the staging area. This is `git status` + `git add` + `git commit` in one panel. |
| **Git Repository** | **View → Git Repository** | The history graph, all branches, remotes and tags. This is `git log --graph`, `git branch` and `git merge`. |
| Branch picker | bottom-right of the status bar | Current branch. Click it to switch, create, merge, rebase. Also shows ↑↓ counts — commits you have not pushed / not pulled. |
| **Git** menu | main menu bar | Everything else: Clone, Fetch, Pull, Push, Manage Branches, Manage Remotes, Settings. |

In **Git Changes**, files are listed under **Changes** (unstaged) and **Staged Changes**. The
`+` on a file stages it; the `−` unstages it. That divide *is* the staging area from §1 — if the
model ever stops making sense, look at this window while you read §1 again.

---

### 7.3 Command → Visual Studio, side by side

| Command (§4) | In Visual Studio 2026 |
|---|---|
| `git status` | The **Git Changes** window, continuously |
| `git diff` | Double-click any file under *Changes* → side-by-side diff |
| `git diff --staged` | Double-click a file under *Staged Changes* |
| `git add <file>` | The **+** beside the file (tooltip: *Stage*) |
| `git add .` | **+** on the *Changes* header |
| `git add -p` | Select lines in the diff → right-click → **Stage Selected Lines** |
| `git restore --staged` | The **−** beside a staged file (*Unstage*) |
| `git restore <file>` | Right-click the file → **Undo Changes**. **Destructive** — those edits were never in git |
| `git commit -m` | Type the message, click **Commit Staged** |
| `git commit -am` | **Commit All** — note this is the *default* button, and it stages every tracked file. Know which one you are clicking |
| `git commit --amend` | Tick **Amend** above the message box before committing. Unpushed commits only |
| `git push` | The **↑** arrow, or **Git → Push** |
| `git pull` | The **↓** arrow, or **Git → Pull** |
| `git fetch` | The **⟳** arrow, or **Git → Fetch**. Safe — look before you leap |
| `git log HEAD..origin/main` | After a Fetch, **Git Repository** → the **Incoming** / **Outgoing** lists. The ↑↓ counts on the branch picker are the same thing in miniature |
| `git switch <branch>` | Branch picker (status bar) → double-click the branch |
| `git switch -c <name>` | Branch picker → **New Branch…**, or **Git → New Branch…** |
| `git merge <branch>` | **Git Repository** → right-click the branch → **Merge \<branch\> into current** |
| `git branch -d` | **Git Repository** → right-click the branch → **Delete** |
| `git push -u origin <b>` | Just **Push** a new branch — VS offers to publish it and sets the upstream for you |
| `git stash` | **Git Changes** → the **Stash** dropdown → *Stash All* |
| `git stash pop` | **Git Repository** → **Stashes** node → right-click → *Pop* |
| `git log` | **Git Repository** window — the graph on the left, commit details on the right |
| `git blame` | Right-click in the editor → **Git → Blame (Annotate)**. CodeLens above each method shows the same thing inline |
| `git revert <sha>` | **Git Repository** → right-click the commit → **Revert**. The safe undo for pushed work |
| `git reset --soft/--mixed` | Right-click the commit → **Reset → Keep Changes** |
| `git reset --hard` | Right-click the commit → **Reset → Delete Changes**. Read §7.5 before you touch this |
| `git cherry-pick` | Right-click a commit on another branch → **Cherry-Pick** |
| `git tag` | Right-click a commit → **New Tag…**; push it from the **Tags** node |
| `git remote -v` / `set-url` | **Git → Manage Remotes** |
| `git clone` | **Git → Clone Repository…** |
| `git init` | **Git → Create Git Repository…** — read §7.5 first, it writes its own `.gitignore` |
| `git reflog` | **No UI.** Use the terminal. This is why §7.1 says keep it open |
| `git bisect` | **No UI.** Terminal |
| Open a PR | **No UI for Gitea.** Push, then the browser (§3) |

---

### 7.4 Resolving a conflict — this part VS genuinely does better

When a merge or pull conflicts, Visual Studio opens the **Merge Editor**, and it beats reading
`<<<<<<<` markers by hand.

1. **Git Changes** lists the conflicted files under **Unmerged Changes**. Double-click one.
2. Three panes: **Incoming** (left), **Current** (right), **Result** (bottom).
3. Tick the checkbox on the side you want, per conflict — or edit the **Result** pane directly
   when the answer is a mix of both.
4. **Accept Merge** when the file has no conflicts left. Repeat for each file.
5. Commit the merge (VS pre-fills the message).

**Then build and run it.** A conflict resolved so it compiles is not the same as a conflict
resolved correctly — the Merge Editor happily produces code that builds and is wrong. This is
exactly Lab 5's `dotnet run` step.

To bail out entirely: **Git → Abort Merge** (= `git merge --abort`, and equally safe).

---

### 7.5 Visual Studio gotchas

- **"Commit All" is the default button.** It stages every tracked file first, so an unrelated
  half-finished edit rides along into your commit. If you want a focused commit, stage
  deliberately and use **Commit Staged**. Glance at *Staged Changes* before every commit.
- **"Reset → Delete Changes" is `git reset --hard`.** A destructive command, two clicks deep in a
  context menu, with no scary confirmation. Commit before you experiment (§8) and it cannot hurt
  you.
- **"Undo Changes" on a file is unrecoverable** — the edits were never committed, so `reflog`
  cannot help. The only genuinely irreversible operations in git are the ones on work git never saw.
- **Do not let "Create Git Repository" write the `.gitignore` for this solution.** It generates its
  own generic one, and [this repo's `.gitignore`](../../.gitignore) is deliberately written to catch
  `appsettings.Development.json`, `*.pfx`, `App_Data/` and `docker-data/`. Keep ours. (`.vs/` and
  `*.user` are already covered by it — VS's own scratch files will not be committed.)
- **The branch picker is the fastest thing in the UI.** Bottom-right, always visible, and the ↑↓
  counts tell you at a glance that you have unpushed commits — the thing people most often forget.
- **VS finds `.git` by walking upward**, so it works whether you open the `.slnx`, a `.csproj`, or
  the folder. One repo, many solutions is fine.
- **Copilot commit messages** (the ✨ icon on the message box) read your staged diff and work
  against any server, Gitea included. Treat the result as a first draft — it describes *what*
  changed; §2 asks you to say *why*.
- **Multi-repo:** VS can have several repositories active at once (**Git → Local Repositories**).
  Useful later if `libs/` becomes separate repos; irrelevant today.

---

### 7.6 The one workflow you cannot do in the IDE

```
In Visual Studio          →   branch, commit, push
In the Gitea web UI       →   create the PR, review it, merge it
In Visual Studio          →   switch to main, pull, delete the branch
```

That middle step never moves into the IDE for Gitea, no matter which extension you find. Budget
for the browser tab; it is where code review happens anyway.

---

## 8. "Oh no" — the recovery section

Read this once now, so you remember it exists at 3am.

**The rule: if it was ever committed, it is still there for ~90 days, even if you cannot see it.**
`git reflog` records every position `HEAD` has held — including ones you "destroyed".

```bash
git reflog                    # a numbered list: HEAD@{0}, HEAD@{1}, ...
git reset --hard HEAD@{3}     # go back to how things were 3 moves ago
```

| Situation | Fix |
|---|---|
| Wrong message on the last commit | `git commit --amend -m "Right message"` (unpushed only) |
| Forgot a file in the last commit | `git add f.cs && git commit --amend --no-edit` (unpushed only) |
| Committed too early | `git reset --soft HEAD~1` — the changes come back, staged |
| Staged the wrong file | `git restore --staged f.cs` |
| Wrecked a file, not yet staged | `git restore f.cs` (this one is genuinely unrecoverable) |
| Committed to `main` by mistake | `git branch feature/x` then `git reset --hard origin/main`, then work on `feature/x` |
| Need to undo a **pushed** commit | `git revert <sha>` then push. Never `reset` shared history |
| `git reset --hard` and regretted it | `git reflog`, find the commit, `git reset --hard <sha>` |
| Deleted a branch by mistake | `git reflog`, find its last commit, `git switch -c <name> <sha>` |
| Merge went wrong, mid-conflict | `git merge --abort` |
| Rebase went wrong, mid-rebase | `git rebase --abort` |
| Pull rejected: "non-fast-forward" | `git pull` (merge theirs in), resolve, then push |
| "detached HEAD" | `git switch -c keep-this` to save the commits, or `git switch main` to abandon them |
| Committed a secret | Rotate the secret **first** — assume it is compromised. Then purge with `git filter-repo`, force-push, and tell everyone to re-clone |
| Truly, totally lost | `git fsck --lost-found` lists dangling commits |

**Two rules that prevent almost every disaster:**

1. **Commit before you experiment.** A commit is free and makes everything undoable.
2. **Never rewrite history that others have pulled** (`reset --hard`, `rebase`, `--force` on a
   shared branch). On your own unpushed branch, rewrite all you like.

---

## 9. Hands-on labs

These run against the **real Gitea server** using a throwaway C# console app, so you can make
every mistake in a place where mistakes cost nothing.

**Sandbox:** `E:\Adhir\AdWork\GitSandbox\` — already created for you. It is deliberately
*outside* `TflCbsNet10Sol\` so it can never be swept into the real solution or its build.

```
GitSandbox/
  GitPractice.csproj
  Program.cs        # entry point
  Account.cs        # one class
  Ledger.cs         # holds a Version constant — Lab 5 makes two branches fight over it
  README.md
  .gitignore        # bin/ obj/
```

If you ever want a clean start: delete the whole `GitSandbox` folder, re-run
`dotnet new console`, and start again from Lab 1. Nothing of value is in there.

> **How to use these.** Type the commands — do not paste. The muscle memory is the point.
> After every single command, run `git status` and read it. Each lab ends with a **Verify**
> step; if its output does not match, stop and re-read the lab before continuing.
>
> **Labs 0–12 are command line**, in `GitSandbox\`. **Labs 13–17 are Visual Studio 2026**, in a
> second clone (`GitSandbox-vs\`) that Lab 13 makes for you. Do them in order: the UI labs
> assume you can already name what each button is about to run.

---

### Lab 0 — Identity and an empty repo on Gitea

```bash
git config --global user.name  "Adhir Ranjan"              # set your name for every repo on this machine — stamped on every commit you make
git config --global user.email "adhirranjan@softtrust.com"  # set your commit email — must match your Gitea account, or Gitea cannot link commits to you
git config --global core.autocrlf true                      # set a line-ending rule: check out CRLF on Windows, store LF in the repo
git config --global pull.rebase false                       # set what a diverged pull does: merge (safe) rather than rebase (rewrites your commits)
git config --global init.defaultBranch main                 # set the branch name new repos start on: `main`, not the older `master`
git config --global --list                                  # print every global setting — confirm the five above took
```

Now in the Gitea web UI: **+** (top right) → **New Repository**.

- Name: `git-practice`
- Visibility: Private
- **Leave "Initialize repository" UNCHECKED.** You want a genuinely empty repo — Lab 2 pushes
  your own history into it, and an initialised repo would collide.

**Verify:** Gitea shows an empty-repo page with setup instructions and a clone URL.

---

### Lab 1 — Your first repository and commit

```bash
cd E:/Adhir/AdWork/GitSandbox   # change directory into the sandbox — every command below runs here

git init                    # create the .git folder — this folder is now a repository
git status                  # show the state of every file — all "untracked": git can see them but is not watching them

git add .gitignore          # stage ONE file — put it on the shortlist for the next commit
git status                  # show the state again — .gitignore moved to "Changes to be committed"; the rest did not

git add .                   # stage everything else in this folder
git status                  # show the state — all staged, and note bin/ and obj/ are absent: .gitignore works

git commit -m "Initial commit: GitPractice console app"   # record the staged files as a commit, with a message
git log --oneline           # list the commits, one line each — you should see exactly one
```

**Verify:** `git status` says *"nothing to commit, working tree clean"* and `git log --oneline`
shows exactly one commit.

**Understand:** you committed *nothing* until `git commit`. `git add` only built a shortlist.

---

### Lab 2 — Connect to Gitea and push

```bash
git config --global credential.helper manager   # set where git stores passwords: Windows Credential Manager, encrypted per-user

git remote add origin http://192.168.0.22:3000/Adhir/git-practice.git   # register that URL as a remote named "origin"
git remote -v               # list the configured remotes and their URLs — two lines (fetch + push) is normal, not a duplicate

git push -u origin main     # upload branch `main` to origin and set it as upstream (-u), so later pushes need no arguments
                            # you will be prompted: username = Adhir, password = PASTE YOUR TOKEN (§6.1)
```

**Verify:** refresh the repo page in Gitea — your five files are there, with your commit message
and your name against it. If the name is wrong, fix `git config --global user.email` now; it only
applies to *future* commits.

---

### Lab 3 — The staging area, properly

Prove that `add` and `commit` are separate. Make **two unrelated** edits, commit them separately.

```bash
# Edit 1: in README.md, add a line "Practising git."
# Edit 2: in Ledger.cs, change the Version constant from "1.0" to "1.1"

git status                  # show the state — two files modified, neither of them staged
git diff                    # show UNSTAGED changes line by line — both files here

git add README.md           # stage only the README edit
git diff                    # show unstaged changes — only Ledger.cs now; the README left this view...
git diff --staged           # show STAGED changes, i.e. what the next commit will contain — ...and turns up here instead

git commit -m "docs: note that this repo is for practice"   # record the staged snapshot — the STAGED file only
git status                  # show the state — Ledger.cs still modified: never staged, so it stayed behind

git commit -am "feat: bump ledger version to 1.1"   # stage every TRACKED file and commit, in one step (-a)
git log --oneline           # list the commits — three now, one file in each

git push                    # upload both new commits to Gitea — do NOT skip this, see the note below
git status                  # show the state — "Your branch is up to date with 'origin/main'"
```

**Verify:** three commits, each containing exactly one file, and Gitea's repo page shows all three.

> **Why the `git push` matters before Lab 4.** Without it your local `main` sits two commits ahead
> of the server. Lab 4 then branches off that local `main`, so when you push the feature branch it
> carries those two commits with it — and the pull request would show **three** commits and three
> changed files instead of the one you just wrote. It would still work, but Lab 4's whole point is
> reading a small, focused diff the way a reviewer does. **A branch always carries everything your
> local `main` has that the server does not.** Push `main` before branching off it, always.

> **And yes, these labs commit straight to `main`** — which §12 tells you never to do. Labs 1–3,
> and most of 5–12, work directly on `main` on purpose: you are alone in a throwaway repo with no
> reviewer and no branch protection, and there is nothing to branch *from* until the first commit
> exists. **Lab 4 is the one that shows the real workflow** — branch, push, pull request, merge,
> delete — and that is the one to copy on `TflCbsNet10Sol`. If you had enabled branch protection
> (§6.5) on the practice repo, every direct push to `main` below would be rejected; leave it off
> here.

---

### Lab 4 — A branch and a real pull request

```bash
git switch -c feature/interest-rate   # create a branch and move onto it (-c = create)

# In Ledger.cs, add this method inside the class:
#     public decimal Interest(decimal amount) => amount * 0.04m;

git add Ledger.cs                     # stage the edit
git commit -m "feat: add simple interest calculation"   # record it as a commit on THIS branch — main is untouched
git push -u origin feature/interest-rate   # upload the branch to Gitea and set upstream (-u). main is still unchanged
```

In Gitea: the repo page shows a **Compare & Pull Request** banner → click it. Confirm **base:
`main`** ← **compare: `feature/interest-rate`**. Write a title and a description. **Create Pull
Request.**

Look at the **Files changed** tab — this is exactly what a reviewer sees. Leave a comment on a
line, to feel it. Then respond to your own review:

```bash
# Change 0.04m to 0.045m in Ledger.cs
git commit -am "fix: correct rate to 4.5%"   # stage every tracked edit and commit, in one step
git push                    # upload the new commit — no -u this time, the branch is already linked
```

Refresh the PR: the new commit is in it automatically. Now **Merge Pull Request** — choose plain
**Merge** for this lab; the note after the cleanup explains why. Then clean up:

```bash
git switch main                       # move onto main, leaving the feature branch
git fetch                             # download the merge Gitea made, WITHOUT changing your branch yet
git log --oneline HEAD..origin/main   # list what is about to arrive: the merge commit and your two feature commits
git diff --stat HEAD origin/main      # show which files it will change — Ledger.cs, the Interest method
git pull                              # now merge it in, knowing exactly what you are getting (§4.5)
git branch -d feature/interest-rate   # delete the local branch (-d refuses if it were still unmerged)
git fetch --prune                     # fetch, and drop remote-tracking refs for branches deleted on the server
git log --oneline --graph --all       # draw the commit graph across all branches — the shape of what just happened
```

**Verify:** `main` contains the interest method, and `git branch -a` no longer lists the feature
branch anywhere.

> **Why plain Merge, and what the other styles do to that cleanup.** `git branch -d` deletes a
> branch only when its commits are already reachable from where you stand. **Squash and merge** and
> **Rebase and merge** (§6.4) both rewrite your commits into *new* ones with new SHAs, so git cannot
> see your branch as merged and refuses:
> `error: The branch 'feature/interest-rate' is not fully merged.` That is the safety net doing its
> job with incomplete information, not a bug. On a team that squash-merges you confirm the work
> landed on `main`, then delete with `-D`. Worth trying deliberately on a later branch.

---

### Lab 5 — Make a conflict on purpose, then fix it

The single most feared part of git. Do it deliberately, once, and it stops being scary.

```bash
git switch -c feature/v2    # create branch #1 off main and move onto it
# Ledger.cs: set Version = "2.0"
git commit -am "feat: version 2.0"    # stage tracked edits and commit — this change now exists only on feature/v2

git switch main             # move back onto main, where Ledger.cs still reads "1.1" (Lab 3 set it)
git switch -c hotfix/v11    # create branch #2, also off main — it has never seen "2.0"
# Ledger.cs: set the SAME line to "1.1.1"
git commit -am "fix: version 1.1.1"   # stage and commit — a second, different change to the same line

git switch main             # move onto main, which still has neither change
git merge hotfix/v11        # merge that branch into main — clean: main had no commits of its own, so the pointer just slides (fast-forward)
git merge feature/v2        # merge the other branch in — CONFLICT: both changed the same line, and git will not guess
```

Open `Ledger.cs`. You will see the `<<<<<<<` / `=======` / `>>>>>>>` markers from §4.7.

```bash
git status                            # show the state — names the conflicted file and spells out what to do next
git diff --name-only --diff-filter=U  # list changed file NAMES, filtered to unmerged (= conflicted) ones only
```

Edit the file: **delete all three marker lines**, keep `"2.0"`. Then:

```bash
git add Ledger.cs           # stage the file — staging a conflicted file is how you say "I have resolved this one"
git status                  # show the state — "All conflicts fixed but you are still merging"
git commit                  # record the merge commit, opening an editor — git pre-fills the message, so save and close
dotnet run                  # build and run the app — a conflict resolved so it COMPILES can still be wrong
git log --oneline --graph --all   # draw the graph — the two branches now join at a merge commit
git push                    # upload the merge to Gitea
```

**Verify:** `dotnet run` prints `ledger v2.0`, and the graph shows the two branches joining.

**Now do it again and bail out**, so you know the escape hatch works: create another conflicting
branch, `git merge` it, then `git merge --abort` and confirm `git status` is clean.

---

### Lab 6 — Undo, four different ways

Each undo suits a different situation. Do all four.

```bash
# (a) Wrong message
git commit --allow-empty -m "Fxi typo in ledgre"   # make a commit with no file changes (--allow-empty), purely for practice
git commit --amend -m "fix: correct typo in ledger output"   # replace the last commit with a new one carrying this message
git log --oneline -1        # list the last commit — message fixed, and there is still only one commit

# (b) Forgot a file
# Add a line to README.md
git commit -am "docs: describe the labs"   # stage tracked files and commit — but this change was incomplete
# ...now edit Account.cs too — it belonged in that commit
git add Account.cs          # stage the file you forgot
git commit --amend --no-edit   # replace the last commit, folding this in and reusing its message (--no-edit)

# (c) Committed too early
# Edit any file
git commit -am "wip"        # stage and commit — a commit you regret the moment you press Enter
git reset --soft HEAD~1     # move the branch back one commit; --soft leaves the changes STAGED
git status                  # show the state — your work is still there, staged and ready
git commit -m "feat: a properly described change"   # record it again, this time deliberately

# (d) Undo something already pushed — the safe way
git push                    # upload it — now it is on Gitea, (a)-(c) are off the table: they rewrite commits
git revert HEAD             # create a NEW commit that undoes the last one — nothing is deleted
git log --oneline -3        # list the last three commits — mistake and reversal both visible. History stays honest
git push                    # upload the revert — everyone gets the fix without their history changing under them
```

**Verify:** you can state, in your own words, why (d) must be used instead of (a)–(c) once a
commit has been pushed. (Because (a)–(c) *rewrite* commits, and everyone else's history still
contains the originals.)

---

### Lab 7 — Destroy work, then get it back

This is the lab that makes you unafraid of git.

```bash
git log --oneline -3        # list the last three commits — note them, so you can tell they came back
echo "// something valuable" >> Ledger.cs   # append a line to the file (>> appends; a single > would overwrite it)
git commit -am "feat: valuable work I am about to destroy"   # stage and commit, so git has definitely seen this work
git log --oneline -1        # list the last commit — note this SHA: it is what you are about to "lose"

git reset --hard HEAD~2     # move the branch back 2 commits AND wipe the working files to match. Destructive
git log --oneline -3        # list the last three commits — your two are gone from the branch. Really gone?

git reflog                  # list every position HEAD has held — no: it is all still recorded, for ~90 days
git reset --hard HEAD@{1}   # move the branch to where HEAD was one step ago, i.e. immediately before the reset
git log --oneline -3        # list the commits — everything is back, with the same SHAs
```

Now the same for a deleted branch:

```bash
git switch -c spike/throwaway   # create a branch you are about to abandon, and move onto it
git commit --allow-empty -m "spike: work I will lose"   # make one empty commit on it
git switch main                 # move onto main — you cannot delete the branch you are standing on
git branch -D spike/throwaway   # force-delete the branch (-D) even though it was never merged. That commit is now orphaned

git reflog                      # list every position HEAD has held — find "spike: work I will lose" and copy its SHA
git switch -c spike/recovered <that-sha>   # create a new branch AT that commit and move onto it — the work is back
git log --oneline -1            # list the last commit — recovered: a branch is only a pointer, so re-pointing one restores it
```

**Verify:** you have recovered both. **Remember for life:** anything *committed* is recoverable
for ~90 days via `git reflog`. Anything never committed is not.

---

### Lab 8 — Stash: "I need to switch branches right now"

```bash
git switch main             # move onto main
# Start editing Program.cs — leave it half-finished, do not commit

git switch -c fix/urgent    # try to create a branch — git either refuses, or drags your half-finished mess onto it
git switch main             # move back onto main — neither outcome is what you want, so do it properly
git branch -d fix/urgent    # delete that branch — it points at main, so -d is happy. You recreate it properly below

git stash                   # park every uncommitted change on a shelf; the working tree goes clean
git status                  # show the state — "nothing to commit": your edit is not lost, it is elsewhere
git stash list              # list what is on the shelf — stash@{0}, there it is

git switch -c fix/urgent    # create the branch and move onto it — NOW, from a clean tree
git commit --allow-empty -m "fix: the urgent thing"   # make an empty commit — the urgent job
git switch main             # move back onto main, where you were

git stash pop               # re-apply the newest stash and drop it from the shelf (pop = apply AND remove)
git status                  # show the state — your half-finished edit is back, exactly as you left it

git restore Program.cs      # NOW throw that practice edit away — §4.6's unrecoverable one, fine here: it was scrap
git status                  # show the state — clean. Lab 9 needs Program.cs untouched, see below
```

**Verify:** your half-finished edit came back, `git stash list` is empty, and the final `git restore`
leaves the tree clean.

> **Do not skip that last `git restore`.** Lab 9 has a "colleague" edit `Program.cs`, and it commits
> your side with `git commit -am`, which stages **every** tracked modified file. Leave this practice
> edit lying around and it rides along into that commit, collides with the colleague's change, and
> Lab 9's "different files, so no conflict" stops being true.

---

### Lab 9 — Be your own colleague

Simulate the thing that actually causes trouble: two people editing at once.

```bash
cd E:/Adhir/AdWork/GitSandbox   # change directory to your normal copy
git push                        # upload everything, so both copies start level with Gitea

cd E:/Adhir/AdWork              # change directory out of the repo before cloning
git clone http://192.168.0.22:3000/Adhir/git-practice.git practice-colleague   # copy the whole repo from Gitea into a new folder — a SECOND, independent copy
cd practice-colleague           # change into it — from here on, pretend you are somebody else

# "Colleague" edits Program.cs and pushes
git commit -am "feat: colleague changes the greeting"   # stage tracked files and commit, in the colleague's copy
git push                        # upload it — Gitea's main has now moved forward

# Back in YOUR copy — which knows nothing about that
cd ../GitSandbox                # change back to your copy, which still believes main is where it was
# Edit README.md
git commit -am "docs: my own change"   # stage and commit locally — always fine, no server involved
git push                        # try to upload — REJECTED: the server holds a commit you do not have
```

Read the rejection message; it is telling you exactly what happened.

```bash
git fetch                            # download from origin WITHOUT touching your branch — always safe
git log --oneline HEAD..origin/main  # list commits on origin/main that are not on HEAD (the `a..b` range syntax)
git pull                             # fetch and merge into your branch — you edited different files, so no conflict
git log --oneline --graph -5         # draw the graph — a merge commit now joins the two lines of work
git push                             # upload again — accepted: your branch now contains theirs, so it is a fast-forward
```

**Verify:** both changes are on Gitea. Now repeat the whole lab but have **both** sides edit the
*same line* of `README.md`, so `git pull` produces a conflict — resolve it as in Lab 5. This is
what your real day will look like.

Delete `practice-colleague` when done.

---

### Lab 10 — .gitignore, and the mistake it does not fix

```bash
cd E:/Adhir/AdWork/GitSandbox   # change directory back to your own copy
dotnet build                 # compile the project — produces bin/ and obj/, hundreds of files
git status                   # show the state — they do not appear at all: .gitignore is doing its job

# Now break it deliberately:
git add -f bin/              # stage bin/ even though .gitignore excludes it (-f = force). Never do this for real
git commit -m "oops: committed build output"   # record it — bin/ is now part of the history, permanently
git status                   # show the state — clean, but bin/ is TRACKED now, so .gitignore no longer applies to it
# Rebuild and watch the noise:
dotnet build && git status   # rebuild, then show the state — every rebuilt artefact counts as a modification

git rm -r --cached bin/      # stop tracking bin/ (--cached = remove from git only, leave the files on disk)
git commit -m "Stop tracking build output"   # record the untracking — from this commit on, .gitignore governs bin/ again
dotnet build && git status   # rebuild and show the state — quiet again
```

**Verify:** `bin/` still exists on disk but `git status` ignores it.

**Understand:** `.gitignore` only governs files git is **not already tracking**. This is exactly
how `appsettings.Development.json` (your DB password) ends up in a repo forever.

---

### Lab 11 — Tags and a Gitea release

```bash
git switch main                  # move onto main — a tag marks one commit, so stand on the right one first
git pull                         # fetch and merge, so main is current before you tag it
git push                         # upload Lab 10's two commits first — a tag should point at something the server has
git tag -a v1.0 -m "First practice release"   # create an annotated tag on this commit (-a = carries an author, date and message)
git tag                          # list every tag in this repo
git show v1.0                    # show that object in full — the tag's message, plus the commit it points at
git push origin v1.0             # upload the tag by name — a plain `git push` does NOT send tags
```

In Gitea: **Releases** → **New Release** → pick tag `v1.0`. That is all a release is — a tag
plus a description.

**Verify:** `git ls-remote --tags origin` lists `v1.0`.

---

### Lab 12 — Two more worth knowing

```bash
# Cherry-pick: take ONE commit from another branch
git switch -c experiment                # create a branch that will hold two commits, only one of them wanted
git commit --allow-empty -m "feat: something worth keeping"     # make an empty commit — the one you want
git commit --allow-empty -m "junk: something not worth keeping" # make a second empty commit — the one you do not
git switch main                         # move onto main, which has neither
git cherry-pick <sha-of-the-first>      # copy that ONE commit onto the current branch, as a new commit

# Bisect: find which commit broke something, across a long history
git bisect start                        # begin a binary search through the history for the commit that broke something
git bisect bad                          # mark the commit you are on as broken
git bisect good v1.0                    # mark v1.0 as working — so the culprit is somewhere between the two
#   git checks out a midpoint; test it; then `git bisect good` or `git bisect bad`
#   repeat — each answer halves the range, so ~1000 commits take about 10 tests
git bisect reset                        # end the search and return to where you started. ALWAYS finish with this

git push                                # upload main — Lab 13 clones this repo fresh and should get the cherry-pick
```

**Verify:** after the cherry-pick, `git log --oneline` on `main` shows the kept commit and not
the junk one, and Gitea's repo page agrees.

---

### Lab 13 — Do it all again, in Visual Studio 2026

**Labs 13–17 are the Visual Studio set.** Do them only now, after twelve labs at the command line —
the point is to watch the UI perform commands you can already name, and to find the places where it
stops. Each one ends in **View → Terminal**, checking with git what the clicks actually did.

1. **Git → Clone Repository…** → `http://192.168.0.22:3000/Adhir/git-practice.git` → clone it to a
   *new* folder, e.g. `E:\Adhir\AdWork\GitSandbox-vs`. Credentials: `Adhir` + your PAT.
2. Open **View → Git Changes** and **View → Git Repository**, and dock them where you can see both.
3. Branch picker (bottom-right) → **New Branch…** → `feature/vs-tour`.
4. Edit `Ledger.cs`. Watch the file appear under *Changes*. Double-click it to see the diff.
5. Stage it with **+**, then unstage it with **−**, then stage it again. That is `git add` and
   `git restore --staged`, and now you can see the shortlist being built.
6. Type a message, click **Commit Staged** — deliberately **not** *Commit All*.
7. **↑ Push**. Visual Studio offers to publish the new branch; accept (that is `push -u`).
8. **Now leave the IDE.** Open Gitea in a browser and create the PR. There is no button for this in
   Visual Studio, and there will not be one.
9. Back in VS: branch picker → `main` → **↓ Pull** → right-click `feature/vs-tour` in **Git
   Repository** → **Delete**.

Then open **View → Terminal** in the same window and run:

```bash
git log --oneline --graph --all -10   # draw the graph — the branch, commit and merge you just made through the UI
git reflog -10                        # list the last 10 positions HEAD held — every click, as the git command it really was
```

**Verify:** the reflog lists every step you just performed through the UI — checkout, commit,
push, merge — as ordinary git operations. Nothing the IDE did was special, and nothing it did was
hidden from you.

---

### Lab 14 — Resolve a conflict in the Merge Editor

Lab 5 again, but through the UI — because this is the one job the IDE genuinely does better than
the command line. Work in `GitSandbox-vs` throughout.

1. Branch picker → `main` → **↓ Pull**, so you start level with Gitea.
2. Branch picker → **New Branch…** → `feature/ui-v3`, from `main`.
3. In `Ledger.cs` set `Version = "3.0"`. **Git Changes** → stage it → **Commit Staged**.
4. Branch picker → `main` → **New Branch…** → `hotfix/ui-v21`, again from `main`.
   *(Branching from `main` — not from `feature/ui-v3` — is what makes the histories diverge.)*
5. Set the **same line** to `"2.1"`. Stage → **Commit Staged**.
6. Branch picker → `main`. **Git Repository** → right-click `hotfix/ui-v21` → **Merge
   `hotfix/ui-v21` into `main`**. Clean — `main` had no commits of its own, so it fast-forwards.
7. Right-click `feature/ui-v3` → **Merge into `main`**. **Conflict.** `Ledger.cs` appears under
   **Unmerged Changes** in Git Changes.
8. Double-click it. The **Merge Editor** opens: **Incoming** (left), **Current** (right),
   **Result** (bottom).
9. Take one side with its checkbox, then the other, and watch the *Result* pane change. Then click
   into *Result* and type `"3.0"` by hand — proving the answer does not have to be either side.
10. **Accept Merge**, then **Commit Merge** in Git Changes.
11. **Ctrl+Shift+B** to build, then **Ctrl+F5** to run it.

Then **View → Terminal**:

```bash
git log --oneline --graph --all -8   # draw the graph — the two branches diverging and rejoining at your merge commit
git show --stat HEAD                 # show the last commit, files-changed summary only — two parents, and the file you resolved
```

**Verify:** the app prints `ledger v3.0`, and the graph shows a genuine fork and join — not a
straight line.

**Now prove the escape hatch.** Make one more conflicting branch, merge it, and when the Merge
Editor opens choose **Git → Abort Merge** instead of resolving. Check Git Changes is clean and the
branch pointer has not moved. That is `git merge --abort`, and it is always safe.

**Understand:** the Merge Editor is a better *conflict* tool, not a better *judgement* tool. It
will happily let you accept a resolution that compiles and is wrong — which is why step 11 builds
and runs before you trust it.

---

### Lab 15 — The two commit buttons, and staging individual lines

The Commit All / Commit Staged distinction is where Visual Studio quietly does something you did
not ask for. Meet it deliberately, once.

1. Branch picker → **New Branch…** → `feature/vs-staging`.
2. Make **two unrelated edits in the same file**, `Ledger.cs`:
   - change `Version` to `"3.1"`
   - add a method: `public decimal Fee(decimal amount) => amount * 0.01m;`
3. Also add a stray line to `README.md` — work you are *not* ready to commit.
4. **Git Changes** → double-click `Ledger.cs` to open the diff.
5. Select just the `Version` line in the diff → right-click → **Stage Selected Lines**.
6. **Look at the file list.** `Ledger.cs` now appears under **both** *Changes* **and** *Staged
   Changes* — the same file, in two states at once. This is exactly §1's staging area, and it is
   the single most confusing thing in the window until you have seen it once.
7. Commit message → **Commit Staged**. Only the `Version` line goes in.
8. Now click the **Commit All** dropdown arrow and read the label carefully before clicking it —
   it will sweep up the `Fee` method **and** your unfinished `README.md` edit. Do it anyway, so you
   see it happen.

**View → Terminal:**

```bash
git log --oneline -2         # list the last two commits
git show --stat HEAD~1       # show the previous commit's file summary — Ledger.cs only, and only one line of it
git show --stat HEAD         # show the last commit's file summary — Ledger.cs AND README.md: Commit All took both
```

**Verify:** you can point at the exact commit where *Commit All* included a file you had not
finished. That is the whole lesson.

**Undo the damage**, and practise the fix while you are here:

```bash
git reset --soft HEAD~1      # move the branch back one commit, leaving its changes STAGED — takes that commit apart
```

Then in **Git Changes**, unstage `README.md` with **−**, and **Commit Staged** the `Fee` method
alone. Two focused commits, which is what you wanted from the start.

**Understand:** *Stage Selected Lines* is genuinely better than `git add -p` — you click lines
instead of answering `y`/`n`/`s` per hunk. It is the one place the UI beats the terminal outright
for everyday work.

---

### Lab 16 — Undo from the history graph, and the one thing the UI cannot do

Lab 6 and Lab 7 through the UI — and finding the wall.

**Amend, unstage, discard:**

0. Branch picker → `main`, then **New Branch…** → `feature/vs-undo`. Lab 15 left you on
   `feature/vs-staging`; start this one from a known place.
1. Edit `Ledger.cs`, stage it, commit it with a deliberately bad message (`asdf`).
2. Tick **Amend** above the message box, write a proper message, **Commit Staged**. One commit, new
   message — that is `git commit --amend`.
3. Edit two files. Stage both. Unstage one with **−** (`git restore --staged`).
4. Right-click the still-unstaged file → **Undo Changes** → confirm. **Those edits are gone for
   good** — they were never committed, so nothing in §8 can bring them back. This is the only
   truly irreversible operation in this lab.

**Revert something pushed:**

5. Commit anything, then **↑ Push**.
6. **Git Repository** → right-click that commit in the graph → **Revert**.
7. Look at the graph: **two** commits now — yours and its reversal. Nothing was deleted, which is
   why this is the safe undo for shared history (§8). Push again.

**Reset, both flavours:**

8. Commit something else. Right-click the commit *below* it → **Reset → Keep Changes**. The commit
   disappears, your changes return to Git Changes. That is `git reset --mixed`, and it is
   recoverable in every sense.
9. Commit it again. Now right-click the commit below → **Reset → Delete Changes**. Gone: commit
   *and* content. That is `git reset --hard`, sitting in a context menu with no red warning.

**Now hit the wall:**

10. Try to undo step 9 from the UI. Search the menus. **There is no reflog in Visual Studio** —
    the safety net from §8 has no button anywhere in the IDE.
11. **View → Terminal:**

```bash
git reflog -10               # list the last 10 positions HEAD held, including the one you just left
git reset --hard HEAD@{1}    # move the branch to where HEAD was one step ago — the commit is back
git log --oneline -3         # list the last three commits — recovered
```

**Verify:** the commit destroyed in step 9 is back, and you recovered it with a command that has
no equivalent button. Say out loud which of steps 1–9 the UI can undo and which it cannot; that
distinction is the reason §7.1 tells you to keep the terminal open.

**Understand:** the IDE covers the common path well and stops exactly where things get
interesting. `reflog`, `bisect`, `cherry-pick` from an arbitrary SHA, and anything involving a
range are terminal work — in Visual Studio, in Rider, in every IDE.

---

### Lab 17 — Gitea housekeeping from Visual Studio

Short, and it settles the questions people hit in week one.

1. **Git → Manage Remotes.** `origin` is listed with the Gitea URL. This is `git remote -v`. If the
   server ever moves, **Edit** here rather than removing and re-adding it.
2. **Git → Settings → Git Repository Settings.** Per-repo overrides — a different `user.email` for
   one project, for example. These beat your global settings (§10).
3. Push to a branch, then in **Gitea** delete that branch through the web UI. Back in VS, the
   branch is still listed under `remotes/origin/` — a stale cache. **Git → Fetch** with
   `fetch.prune` set (§10) clears it. Prove it by looking at **Git Repository** before and after.
4. **Replace your token.** Windows **Credential Manager** → *Windows Credentials* → find the
   `git:http://192.168.0.22:3000` entry → **Remove**. Push again in VS: it prompts, and you paste a
   fresh PAT. This is how you rotate a token, and how you fix "VS keeps using the wrong account".
5. **Confirm the boundary for yourself.** Open every Git menu in Visual Studio and look for
   anything that creates a pull request. There is nothing — VS's PR tooling binds to GitHub and
   Azure DevOps only (§7). The browser is not a workaround here; it is the tool.

**Verify:** you can rotate your PAT without help, and you know that a branch deleted on the server
lingers in VS until a pruning fetch.

---

## 10. Make git comfortable

### Aliases — worth 30 seconds, saves them back daily

```bash
git config --global alias.st  status
git config --global alias.co  checkout
git config --global alias.br  branch
git config --global alias.cm  "commit -m"
git config --global alias.lg  "log --oneline --graph --all --decorate -20"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "restore --staged"

git lg          # the one you will use most
```

### Other settings worth having

```bash
git config --global core.editor "code --wait"     # VS Code for commit messages
git config --global diff.tool vscode
git config --global fetch.prune true              # auto-prune dead remote branches
git config --global rerere.enabled true           # remember conflict resolutions
git config --global push.default simple           # push only the current branch
```

### Where settings live

| Scope | File | Wins? |
|---|---|---|
| `--system` | git install dir | lowest priority |
| `--global` | `C:\Users\<you>\.gitconfig` | middle — your personal defaults |
| `--local` | `<repo>\.git\config` | **highest** — per-repo overrides |

Use `--local` to set a different `user.email` for one repo (e.g. work vs personal).

---

## 11. Graduating: the real repository

`TflCbsNet10Sol\` is **not yet a git repo** — but a carefully written [.gitignore](../../.gitignore)
is already sitting in it, which is the hard part. Do this only after the labs, and read every
step before running it.

```bash
cd E:/Adhir/AdWork/TrustBank.Code/TflCbsNet10Sol

git init
git status                # will list THOUSANDS of files — this is why the next step matters

# 1. Confirm the ignores are doing their job BEFORE you add anything.
git status -s | grep -Ei "bin/|obj/|appsettings.Development.json|\.pfx|App_Data|docker-data" 
#    ^ this must print NOTHING. If it prints anything, fix .gitignore first.

# 2. Sanity-check the size of what you are about to commit.
git status -s | wc -l
git add -A
git status -s | wc -l     # same number? good.

# 3. Look for secrets one more time. This is the last cheap moment to catch them.
git diff --staged --name-only | grep -Ei "secret|password|\.env|credential|\.pfx|\.p12"

git commit -m "Initial commit: TrustBank CBS .NET 10 migration"
```

Then create the repo in Gitea (empty, **not** initialised) and:

```bash
git remote add origin http://192.168.0.22:3000/Adhir/TflCbsNet10Sol.git
git push -u origin main
```

**Before that first push, three things are worth settling with your lead:**

1. **Is the dev connection string in a committed file anywhere?** `**/appsettings.Development.json`
   is ignored, but check `compose*.yaml`, `web.config`, and the deploy scripts by hand. A secret
   in commit #1 is a secret in the history forever.
2. **Should `TflCbs.Entities.dll` (bare-DLL HintPath) be committed?** Binaries in git are a known
   smell, but the build genuinely needs it. Decide deliberately, not by accident.
3. **Protect `main` in Gitea** (Settings → Branches) from day one, so nobody — including you —
   can push to it directly. It is far easier to enable now than after bad habits form.

---

## 12. Rules of thumb

- **Run `git status` constantly.** It is free, and it answers most questions before you ask them.
- **Commit small and often.** A commit is a save point; you cannot have too many.
- **Pull before you start work**, and before you push.
- **Never commit to `main`.** Branch, PR, review, merge.
- **Never `--force` a shared branch.** `--force-with-lease` on your own branch, at most.
- **Never commit secrets, build output, or `.user` files.** Check `git status` before `git add .`.
- **Write the commit message for the person who reads it in a year.** That person is you.
- **If you are about to try something risky, commit first.** Then anything is undoable.
- **Read the error message.** Git's errors are unusually good and usually contain the fix.

---

## 13. Glossary

| Term | Meaning |
|---|---|
| repository (repo) | A project plus its entire history — the `.git` folder |
| working tree | The files as they currently sit on your disk |
| index / staging area | The shortlist of changes that will go into the next commit |
| commit | A snapshot + message + author + parent. Identified by a SHA like `a1b2c3d` |
| SHA / hash | A commit's unique id. The first 7 characters are usually enough |
| branch | A movable pointer to a commit. That is all |
| HEAD | Where you are now |
| remote | A named server URL, usually `origin` |
| origin/main | Your cached copy of the server's `main`, as of the last fetch |
| tracking branch | A local branch linked to a remote one (what `-u` sets up) |
| fetch | Download from the server, change nothing local |
| pull | Fetch, then integrate |
| push | Upload your commits |
| merge | Join two histories, possibly creating a merge commit |
| rebase | Replay commits onto a new base — rewrites them |
| fast-forward | A merge that only needs the pointer moved |
| conflict | Two branches changed the same lines; git needs you to decide |
| stash | A shelf for uncommitted work |
| tag | A permanent name for a commit, usually a release |
| detached HEAD | You are on a commit, not a branch |
| reflog | The log of where HEAD has been — your undo history |
| PR | Pull Request: "please merge my branch", reviewed in the Gitea UI. A server feature, not a git one — §3.2 |
| upstream | The branch yours tracks |
| clean tree | No uncommitted changes |

---

## Where to go next

- `git help <command>` — the authoritative manual, offline, for any command here.
- [Pro Git](https://git-scm.com/book) — free, complete, and genuinely well written. Chapters 2, 3 and 6.
- [docs/guides/day-one.md](day-one.md) — getting the CBS app itself running.
