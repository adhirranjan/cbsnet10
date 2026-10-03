# Git with Gitea — from zero to your first pull request

> A complete working reference for git as used on this project, written for someone who has
> never used it. Our git server is **Gitea** (self-hosted), not GitHub.
>
> **This guide comes in two halves. Pick the one that matches how you work — you do not need both.**
>
> | Half | What it is |
> |---|---|
> | **[Part 1 — Git in Visual Studio](git-with-gitea-part1.md)** | Everything through the IDE: the two windows, the branch picker, the Merge Editor. **16 labs, all clicks.** Start here if Visual Studio is where you live. |
> | **[Part 2 — Git at the command line](git-with-gitea-part2.md)** | The commands, a practical reference, an exhaustive one, and **15 labs** at the terminal. Start here if you want to understand what the buttons in Part 1 are actually doing. |
>
> Both halves run on **the same sample project, printed in full in [§0.3](git-with-gitea-part0.md#03-the-sample-project-every-file-printed-here)**. You create it by
> copy-pasting out of [Part 0](git-with-gitea-part0.md) — there is nothing to clone and nothing to download. Each half
> builds its own throwaway repo on Gitea, so the two never collide and you can do either first.
>
> Budget: **~30 minutes to your first commit**, ~2 hours to finish one half's labs.
>
> **The guide is five pages:** this one, [Part 0](git-with-gitea-part0.md) (read first),
> [Part 1](git-with-gitea-part1.md) *or* [Part 2](git-with-gitea-part2.md), and [Part 3](git-with-gitea-part3.md)
> for reference — plus a one-page **[cheat sheet](git-with-gitea-cheat-sheet.md)** to print. Every page
> has Previous / Next links at the top and bottom.
>
> Every tutorial you find online will reach for `gh`, the **GitHub** CLI — it does not work here;
> [§14.6](git-with-gitea-part3.md#146-tea-giteas-official-cli-optional) explains why and names the Gitea equivalent.

---

## Your server details

Every example below uses these.

| Thing | Value |
|---|---|
| Gitea URL | `http://192.168.0.22:3000` |
| Your username | `Adhir` |
| Commit email | `adhirranjan@softtrust.com` |
| Practice repo — **Part 1 (VS)** | `http://192.168.0.22:3000/Adhir/git-practice-vs.git` |
| Practice repo — **Part 2 (CLI)** | `http://192.168.0.22:3000/Adhir/git-practice.git` |
| Local folder — **Part 1 (VS)** | `E:\adtemp\hands_on\git\GitSandbox-vs\` |
| Local folder — **Part 2 (CLI)** | `E:\adtemp\hands_on\git\GitSandbox\` |
| Folder labs **VA / VB** | repo `git-practice-folder`; folders `MyFolder`, `MyFolder-copy` |
| Folder labs **CA / CB** | repo `git-practice-folder-cli`; folders `MyFolder-cli`, `MyFolder-cli-copy` |

Your account password is **not** written down anywhere in this guide, and it should not be:
git never needs it. You authenticate with a **Personal Access Token** you generate yourself in
the Gitea UI ([§0.4](git-with-gitea-part0.md#04-your-gitea-account-repo-and-token)), which Windows then stores encrypted
on your behalf.

Both sandbox folders are deliberately *outside* `TflCbsNet10Sol\`, so nothing you do in them can
ever be swept into the real solution or its build.

---

## Contents

Every section and lab, across the four part pages. Each part page opens with its own shorter
list.

**How the lab pages help you:**

- **A tick-box on every lab heading.** Tick it when you finish; your browser remembers it, a
  *Labs done: n of 14* counter sits in the corner, and finished labs get a ✓ in the list below.
  (Nothing is sent anywhere — clear the site data and the ticks are gone.)
- **A "Stuck?" box at the end of every lab**, linking straight to the troubleshooting row for
  the usual ways that lab goes wrong. The row lights up when you land on it.
- **Two short videos**: [opening and merging a pull request](git-with-gitea-part0.md#opening-one)
  on our Gitea, and [resolving a conflict](git-with-gitea-part1.md#5-conflicts-the-merge-editor)
  in Visual Studio.
- **Pictures for the ideas that trip people up** — the three copies of `main`, why a push is
  rejected, the three shapes of a merge, and *which undo?* — in
  [§0.2](git-with-gitea-part0.md#02-the-model-in-five-minutes), [§5](git-with-gitea-part1.md#5-conflicts-the-merge-editor),
  [§11.7](git-with-gitea-part2.md#117-conflicts) and [§15](git-with-gitea-part3.md#15-oh-no-the-recovery-section).

**[Part 0 — Common ground](git-with-gitea-part0.md)** — read this first, whichever half you take

- [0.1 Before you start](git-with-gitea-part0.md#01-before-you-start)
- [0.2 The model, in five minutes](git-with-gitea-part0.md#02-the-model-in-five-minutes)
- [0.3 The sample project — every file, printed here](git-with-gitea-part0.md#03-the-sample-project-every-file-printed-here)
    - [0.3.1 Create the folder and project](git-with-gitea-part0.md#031-create-the-folder-and-project)
    - [0.3.2 The six files](git-with-gitea-part0.md#032-the-six-files)
    - [0.3.3 Prove it works before you commit anything](git-with-gitea-part0.md#033-prove-it-works-before-you-commit-anything)
- [0.4 Your Gitea account, repo, and token](git-with-gitea-part0.md#04-your-gitea-account-repo-and-token)
    - [The token — never your password](git-with-gitea-part0.md#the-token-never-your-password)
    - [The practice repo](git-with-gitea-part0.md#the-practice-repo)
- [0.5 Pull requests — the part that is not git](git-with-gitea-part0.md#05-pull-requests-the-part-that-is-not-git)
    - [Opening one](git-with-gitea-part0.md#opening-one)
    - [The PR page, tab by tab](git-with-gitea-part0.md#the-pr-page-tab-by-tab)
    - [When you are the reviewer](git-with-gitea-part0.md#when-you-are-the-reviewer)
    - [PR troubleshooting](git-with-gitea-part0.md#pr-troubleshooting)
- [0.6 Commit messages and branch names](git-with-gitea-part0.md#06-commit-messages-and-branch-names)
    - [Messages](git-with-gitea-part0.md#messages)
    - [Branch names](git-with-gitea-part0.md#branch-names)

**[Part 1 — Git in Visual Studio](git-with-gitea-part1.md)** — the IDE, end to end. 16 labs

- [1. Orientation — where git lives in Visual Studio](git-with-gitea-part1.md#1-orientation-where-git-lives-in-visual-studio)
    - [1.1 The four places git appears on screen](git-with-gitea-part1.md#11-the-four-places-git-appears-on-screen)
    - [1.2 The Git Changes window, button by button](git-with-gitea-part1.md#12-the-git-changes-window-button-by-button)
    - [1.3 The Git Repository window, pane by pane](git-with-gitea-part1.md#13-the-git-repository-window-pane-by-pane)
    - [1.4 Reading the icons and the counts](git-with-gitea-part1.md#14-reading-the-icons-and-the-counts)
    - [1.5 Where Visual Studio tells you things went wrong](git-with-gitea-part1.md#15-where-visual-studio-tells-you-things-went-wrong)
- [2. One-time setup in Visual Studio](git-with-gitea-part1.md#2-one-time-setup-in-visual-studio)
- [3. The daily loop, in clicks](git-with-gitea-part1.md#3-the-daily-loop-in-clicks)
    - [The commit button renames itself, and that is the whole trick](git-with-gitea-part1.md#the-commit-button-renames-itself-and-that-is-the-whole-trick)
- [4. Branching and pull requests from Visual Studio](git-with-gitea-part1.md#4-branching-and-pull-requests-from-visual-studio)
    - [Making and switching branches](git-with-gitea-part1.md#making-and-switching-branches)
    - [Then leave the IDE](git-with-gitea-part1.md#then-leave-the-ide)
    - [After the merge, clean up](git-with-gitea-part1.md#after-the-merge-clean-up)
- [5. Conflicts — the Merge Editor](git-with-gitea-part1.md#5-conflicts-the-merge-editor)
- [6. Command → Visual Studio, side by side](git-with-gitea-part1.md#6-command-visual-studio-side-by-side)
- [7. Visual Studio gotchas](git-with-gitea-part1.md#7-visual-studio-gotchas)
    - [7.1 "It did not work" — the beginner troubleshooting table](git-with-gitea-part1.md#71-it-did-not-work-the-beginner-troubleshooting-table)
    - [7.2 Keyboard shortcuts worth knowing](git-with-gitea-part1.md#72-keyboard-shortcuts-worth-knowing)
- [8. The Visual Studio labs](git-with-gitea-part1.md#8-the-visual-studio-labs)
    - [Lab VA — Put an existing folder on Gitea](git-with-gitea-part1.md#lab-va-put-an-existing-folder-on-gitea)
    - [Lab VB — Get a local copy of a Gitea repo](git-with-gitea-part1.md#lab-vb-get-a-local-copy-of-a-gitea-repo)
    - [Lab V0 — Identity, and an empty repo on Gitea](git-with-gitea-part1.md#lab-v0-identity-and-an-empty-repo-on-gitea)
    - [Lab V1 — Build the sample project and make your first commit](git-with-gitea-part1.md#lab-v1-build-the-sample-project-and-make-your-first-commit)
    - [Lab V2 — Connect to Gitea and push](git-with-gitea-part1.md#lab-v2-connect-to-gitea-and-push)
    - [Lab V3 — The staging area, properly](git-with-gitea-part1.md#lab-v3-the-staging-area-properly)
    - [Lab V4 — Stage selected lines, and the two commit buttons](git-with-gitea-part1.md#lab-v4-stage-selected-lines-and-the-two-commit-buttons)
    - [Lab V5 — A branch and a real pull request](git-with-gitea-part1.md#lab-v5-a-branch-and-a-real-pull-request)
    - [Lab V6 — Make a conflict on purpose, fix it in the Merge Editor](git-with-gitea-part1.md#lab-v6-make-a-conflict-on-purpose-fix-it-in-the-merge-editor)
    - [Lab V7 — Undo, from the history graph](git-with-gitea-part1.md#lab-v7-undo-from-the-history-graph)
    - [Lab V8 — Destroy work, get it back, and hit the wall](git-with-gitea-part1.md#lab-v8-destroy-work-get-it-back-and-hit-the-wall)
    - [Lab V9 — Stash: "I need to switch branches right now"](git-with-gitea-part1.md#lab-v9-stash-i-need-to-switch-branches-right-now)
    - [Lab V10 — Be your own colleague](git-with-gitea-part1.md#lab-v10-be-your-own-colleague)
    - [Lab V11 — .gitignore, and the mistake it does not fix](git-with-gitea-part1.md#lab-v11-gitignore-and-the-mistake-it-does-not-fix)
    - [Lab V12 — Tags and a Gitea release](git-with-gitea-part1.md#lab-v12-tags-and-a-gitea-release)
    - [Lab V13 — Gitea housekeeping from Visual Studio](git-with-gitea-part1.md#lab-v13-gitea-housekeeping-from-visual-studio)
    - [You have finished Part 1](git-with-gitea-part1.md#you-have-finished-part-1)

**[Part 2 — Git at the command line](git-with-gitea-part2.md)** — the commands, two reference sections, 15 labs

- [9. The daily loop, in commands](git-with-gitea-part2.md#9-the-daily-loop-in-commands)
- [10. Branching and pull requests from the terminal](git-with-gitea-part2.md#10-branching-and-pull-requests-from-the-terminal)
    - [Make the branch and push it](git-with-gitea-part2.md#make-the-branch-and-push-it)
    - [Responding to review is just more commits](git-with-gitea-part2.md#responding-to-review-is-just-more-commits)
    - [Pull it down to test somebody else's branch](git-with-gitea-part2.md#pull-it-down-to-test-somebody-elses-branch)
    - [Two things Gitea may stop you with, both normal](git-with-gitea-part2.md#two-things-gitea-may-stop-you-with-both-normal)
    - [Once merged, clean up](git-with-gitea-part2.md#once-merged-clean-up)
- [11. Section A — Practical reference](git-with-gitea-part2.md#11-section-a-practical-reference)
    - [11.1 Starting a repo](git-with-gitea-part2.md#111-starting-a-repo)
    - [11.2 Looking around — do this before every action](git-with-gitea-part2.md#112-looking-around-do-this-before-every-action)
    - [11.3 Staging and committing](git-with-gitea-part2.md#113-staging-and-committing)
    - [11.4 Branching](git-with-gitea-part2.md#114-branching)
    - [11.5 Syncing with Gitea](git-with-gitea-part2.md#115-syncing-with-gitea)
    - [11.6 Undoing things](git-with-gitea-part2.md#116-undoing-things)
    - [11.7 Conflicts](git-with-gitea-part2.md#117-conflicts)
    - [11.8 Ignoring files](git-with-gitea-part2.md#118-ignoring-files)
- [12. Section B — Exhaustive reference](git-with-gitea-part2.md#12-section-b-exhaustive-reference)
    - [12.1 Create and configure](git-with-gitea-part2.md#121-create-and-configure)
    - [12.2 Inspect](git-with-gitea-part2.md#122-inspect)
    - [12.3 Change the working tree and index](git-with-gitea-part2.md#123-change-the-working-tree-and-index)
    - [12.4 Commit and rewrite](git-with-gitea-part2.md#124-commit-and-rewrite)
    - [12.5 Branch, merge, and combine](git-with-gitea-part2.md#125-branch-merge-and-combine)
    - [12.6 Talk to Gitea (or any server)](git-with-gitea-part2.md#126-talk-to-gitea-or-any-server)
    - [12.7 Temporary storage](git-with-gitea-part2.md#127-temporary-storage)
    - [12.8 Debugging and forensics](git-with-gitea-part2.md#128-debugging-and-forensics)
    - [12.9 Multiple checkouts and nested repos](git-with-gitea-part2.md#129-multiple-checkouts-and-nested-repos)
    - [12.10 Maintenance](git-with-gitea-part2.md#1210-maintenance)
    - [12.11 Things that are not commands, but you must know](git-with-gitea-part2.md#1211-things-that-are-not-commands-but-you-must-know)
- [13. The command-line labs](git-with-gitea-part2.md#13-the-command-line-labs)
    - [Lab CA — Put an existing folder on Gitea](git-with-gitea-part2.md#lab-ca-put-an-existing-folder-on-gitea)
    - [Lab CB — Get a local copy of a Gitea repo](git-with-gitea-part2.md#lab-cb-get-a-local-copy-of-a-gitea-repo)
    - [Lab C0 — An empty repo on Gitea](git-with-gitea-part2.md#lab-c0-an-empty-repo-on-gitea)
    - [Lab C1 — Your first repository and commit](git-with-gitea-part2.md#lab-c1-your-first-repository-and-commit)
    - [Lab C2 — Connect to Gitea and push](git-with-gitea-part2.md#lab-c2-connect-to-gitea-and-push)
    - [Lab C3 — The staging area, properly](git-with-gitea-part2.md#lab-c3-the-staging-area-properly)
    - [Lab C4 — A branch and a real pull request](git-with-gitea-part2.md#lab-c4-a-branch-and-a-real-pull-request)
    - [Lab C5 — Make a conflict on purpose, then fix it](git-with-gitea-part2.md#lab-c5-make-a-conflict-on-purpose-then-fix-it)
    - [Lab C6 — Undo, four different ways](git-with-gitea-part2.md#lab-c6-undo-four-different-ways)
    - [Lab C7 — Destroy work, then get it back](git-with-gitea-part2.md#lab-c7-destroy-work-then-get-it-back)
    - [Lab C8 — Stash: "I need to switch branches right now"](git-with-gitea-part2.md#lab-c8-stash-i-need-to-switch-branches-right-now)
    - [Lab C9 — Be your own colleague](git-with-gitea-part2.md#lab-c9-be-your-own-colleague)
    - [Lab C10 — .gitignore, and the mistake it does not fix](git-with-gitea-part2.md#lab-c10-gitignore-and-the-mistake-it-does-not-fix)
    - [Lab C11 — Tags and a Gitea release](git-with-gitea-part2.md#lab-c11-tags-and-a-gitea-release)
    - [Lab C12 — Cherry-pick and bisect](git-with-gitea-part2.md#lab-c12-cherry-pick-and-bisect)
    - [You have finished Part 2](git-with-gitea-part2.md#you-have-finished-part-2)

**[Part 3 — Common reference](git-with-gitea-part3.md)** — both halves

- [14. Gitea specifics](git-with-gitea-part3.md#14-gitea-specifics)
    - [14.1 Tokens — see §0.4](git-with-gitea-part3.md#141-tokens-see-04)
    - [14.2 SSH instead (optional, nicer once set up)](git-with-gitea-part3.md#142-ssh-instead-optional-nicer-once-set-up)
    - [14.3 The Gitea web UI, mapped to git concepts](git-with-gitea-part3.md#143-the-gitea-web-ui-mapped-to-git-concepts)
    - [14.4 Merge styles Gitea offers on a PR](git-with-gitea-part3.md#144-merge-styles-gitea-offers-on-a-pr)
    - [14.5 Branch protection — expect `main` to reject you](git-with-gitea-part3.md#145-branch-protection-expect-main-to-reject-you)
    - [14.6 `tea` — Gitea's official CLI (optional)](git-with-gitea-part3.md#146-tea-giteas-official-cli-optional)
- [15. "Oh no" — the recovery section](git-with-gitea-part3.md#15-oh-no-the-recovery-section)
- [16. Make git comfortable](git-with-gitea-part3.md#16-make-git-comfortable)
    - [Aliases — worth 30 seconds, saves them back daily](git-with-gitea-part3.md#aliases-worth-30-seconds-saves-them-back-daily)
    - [Other settings worth having](git-with-gitea-part3.md#other-settings-worth-having)
    - [Where settings live](git-with-gitea-part3.md#where-settings-live)
- [17. Graduating: the real repository](git-with-gitea-part3.md#17-graduating-the-real-repository)
- [18. Rules of thumb](git-with-gitea-part3.md#18-rules-of-thumb)
- [19. Glossary](git-with-gitea-part3.md#19-glossary)
- [Where to go next](git-with-gitea-part3.md#where-to-go-next)

---

**[Cheat sheet](git-with-gitea-cheat-sheet.md)** — the daily loop, undo and stash as clicks and as commands, side by side, on two printable pages.
