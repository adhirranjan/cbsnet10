[Git with Gitea — start page](git-with-gitea.md) · [Part 1 · Visual Studio →](git-with-gitea-part1.md) · [Cheat sheet](git-with-gitea-cheat-sheet.md)

# Part 0 — Common ground

Five short sections and one sample project. Everything here applies to both halves, and the labs
in Part 1 and Part 2 both assume you have read it.


**On this page**

- [0.1 Before you start](#01-before-you-start)
- [0.2 The model, in five minutes](#02-the-model-in-five-minutes)
- [0.3 The sample project — every file, printed here](#03-the-sample-project-every-file-printed-here)
    - [0.3.1 Create the folder and project](#031-create-the-folder-and-project)
    - [0.3.2 The six files](#032-the-six-files)
    - [0.3.3 Prove it works before you commit anything](#033-prove-it-works-before-you-commit-anything)
- [0.4 Your Gitea account, repo, and token](#04-your-gitea-account-repo-and-token)
    - [The token — never your password](#the-token-never-your-password)
    - [The practice repo](#the-practice-repo)
- [0.5 Pull requests — the part that is not git](#05-pull-requests-the-part-that-is-not-git)
    - [Opening one](#opening-one)
    - [The PR page, tab by tab](#the-pr-page-tab-by-tab)
    - [When you are the reviewer](#when-you-are-the-reviewer)
    - [PR troubleshooting](#pr-troubleshooting)
- [0.6 Commit messages and branch names](#06-commit-messages-and-branch-names)
    - [Messages](#messages)
    - [Branch names](#branch-names)

---

## 0.1 Before you start

Check git is there. **Visual Studio ships with git**, so if you have VS you have git — but open a
terminal (**View → Terminal** inside VS, `` Ctrl+` ``) and confirm:

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

> **The Visual Studio way, if you prefer:** **Git → Settings → Git Global Config** — name and
> email are the first two boxes. It writes the same `C:\Users\<you>\.gitconfig` that the commands
> above do. There is no separate "Visual Studio identity"; it is one setting with two front doors.

Three settings that will save you real pain. Set them now — Visual Studio exposes some of these
under **Git → Settings**, but not reliably across versions, so do them once at the terminal and be
certain:

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
# if you had already pushed them. See §11.5.
git config --global pull.rebase false

# Name the first branch `main` instead of the older `master`. Gitea defaults to main.
git config --global init.defaultBranch main
```

---

## 0.2 The model, in five minutes

Almost every git confusion comes from not knowing **which of four places** your file is in. This is
just as true in Visual Studio as at the terminal — the IDE shows you the same four places, it just
names them differently.

```
   ┌──────────────┐  git add   ┌──────────────┐  git commit  ┌──────────────┐  git push  ┌──────────────┐
   │ Working tree │ ─────────► │   Staging    │ ───────────► │ Local repo   │ ─────────► │    Gitea     │
   │ (your files, │            │    area      │              │  (.git dir,  │            │  (the server,│
   │  as edited)  │ ◄───────── │  ("index")   │ ◄─────────── │ your history)│ ◄───────── │  shared)     │
   └──────────────┘ git restore└──────────────┘  git reset   └──────────────┘  git pull  └──────────────┘
```

| Place | What it is | Where it is in Visual Studio |
|---|---|---|
| **Working tree** | The actual files on disk. Edit freely; git doesn't care yet | The **Changes** list in **Git Changes** |
| **Staging area** | The shortlist of changes going into the *next* commit. The step people find strange — it exists so you can commit *some* of your edits and not others | The **Staged Changes** list, right below it |
| **Local repo** | The `.git` folder. Your full history. Everything works offline | The graph in **Git Repository** |
| **Gitea** | The shared copy. Nothing you do reaches your colleagues until you push | The **↑** arrow, and the *Outgoing* list |

**`git status` tells you where everything is.** Run it constantly. It is not a stupid question;
experienced developers run it more often than beginners do. In Visual Studio the **Git Changes**
window *is* `git status`, permanently on screen — which is the single best argument for the IDE.

A **commit** is a snapshot of the whole project plus a message, an author and a parent commit.
A **branch** is a sticky note pointing at one commit — that's genuinely all it is, which is why
creating and deleting branches is instant and cheap.

```
   A ◄──── B ◄──── C ◄──── D ◄──── E          each commit points back at its parent
                   ▲               ▲
                 main          feature/x ◄── HEAD   (HEAD = the branch you are on)

   git commit on feature/x  →  a new commit F, and ONLY the feature/x note moves

   A ◄──── B ◄──── C ◄──── D ◄──── E ◄──── F
                   ▲                       ▲
                 main                  feature/x ◄── HEAD
```

**There are three copies of `main`, not two.** Your branch, the server's branch — and between
them `origin/main`, your machine's *cached* copy of the server's `main`, refreshed only when you
fetch. It is what the **↑↓** counts compare against, which is why they can be out of date.

```
            YOUR MACHINE                                        GITEA
  ┌──────────────────────────────────┐                  ┌──────────────────┐
  │                                  │     git push     │                  │
  │  main  (your branch)  ───────────┼────────────────► │  main            │
  │    ▲                             │                  │  (the shared     │
  │    │ merge                       │                  │   one)           │
  │    │                             │     git fetch    │                  │
  │  origin/main  ◄──────────────────┼──────────────────│                  │
  │  (a CACHED copy of Gitea's main, │                  │                  │
  │   as of your last fetch)         │                  │                  │
  └──────────────────────────────────┘                  └──────────────────┘

  git pull   =  git fetch  +  merge origin/main into main
  ↑↓ 2 / 1   =  2 commits you have that origin/main lacks  /  1 it has that you lack
```

**Why a push gets rejected**, which Part 1 and Part 2 both walk you into (Labs V10 and C9). Time
runs left to right:

```
  Gitea main:   A ── B ── C ── X            X = a colleague's commit, already pushed
  your main:    A ── B ── C ── Y            Y = yours, not pushed yet

  git push  →  REJECTED. Accepting it would make Gitea's main  …C ── Y  and lose X.

  git pull  →  fetches X, then merges it with Y into a new merge commit M:

                              ┌── Y ──┐
  your main:    A ── B ── C ──┤       ├── M
                              └── X ──┘

  git push  →  accepted: everything Gitea had (…C ── X) is inside your main now.
```

---
## 0.3 The sample project — every file, printed here

Both halves of this guide work on one tiny C# console app called **GitPractice**. It is six files
and about sixty lines, and every one of them is printed below. **There is nothing to clone and
nothing to download** — you create it once, copy-paste the contents out of this page, and then
spend the labs committing it, branching it, breaking it and recovering it.

It is deliberately a *real project that builds and runs*, not a folder of text files, because three
of the labs depend on that: `bin/` and `obj/` have to actually appear for the `.gitignore` lab to
have a point, and a conflict you resolve has to be something you can **run** to discover you
resolved it wrongly.

Why these particular files:

| File | The job it does in the labs |
|---|---|
| `Ledger.cs` | Holds a single `Version` line. Two branches will fight over exactly that line — this is the conflict |
| `Account.cs` | A second class, so there is a file to *forget* in one commit and amend into it |
| `Program.cs` | Prints the version, so you can **run** the app and see which side of a conflict you kept |
| `README.md` | Prose, edited constantly — the "unrelated second change" in the staging labs |
| `.gitignore` | Keeps `bin/` and `obj/` out. One lab breaks it on purpose |
| `<folder>.csproj` | Makes it a real project, so `dotnet build` produces the build output the ignore lab needs |

---

### 0.3.1 Create the folder and project

Do this **once per half** you intend to work through. The two halves use different folders and
different Gitea repos on purpose, so you can do either one first, redo one without disturbing the
other, and delete either without a thought.

| | Part 1 (Visual Studio) | Part 2 (command line) |
|---|---|---|
| Folder | `E:\adtemp\hands_on\git\GitSandbox-vs\` | `E:\adtemp\hands_on\git\GitSandbox\` |
| Gitea repo | `git-practice-vs` | `git-practice` |

**In Visual Studio:**

1. **File → New → Project…** → **Console App** (C#) → **Next**.
2. **Project name:** `GitSandbox-vs`  **Location:** `E:\adtemp\hands_on\git`
3. Tick **Place solution and project in the same directory**. You want one flat folder, because
   that folder is about to become the repository.
4. **Next** → **Framework: .NET 10.0** → **Create**.
5. **Do not tick "Add to source control" / do not let it create a git repo yet.** Lab V1 does that
   deliberately, and watching an untracked folder become a repository is half the lesson.

**At the command line:**

```bash
mkdir -p E:/adtemp/hands_on/git       # first time only — the parent folder may not exist yet
cd E:/adtemp/hands_on/git
dotnet new console -o GitSandbox      # creates the folder, GitSandbox.csproj and Program.cs
cd GitSandbox
```

Either way you now have a folder with a `.csproj` and a `Program.cs` in it. Replace the contents
with the six listings below.

> **A note on the `.csproj` filename.** The template names it after your folder —
> `GitSandbox-vs.csproj` or `GitSandbox.csproj`. That is fine and you should leave it alone; the
> listing below sets `RootNamespace` and `AssemblyName` explicitly so the *code* is identical in
> both halves regardless of what the project file is called.

---

### 0.3.2 The six files

Copy each block into the file named above it. In Visual Studio, add a new class with
**right-click the project → Add → Class…**, and a plain file with **Add → New Item… → Text File**.

**`GitSandbox.csproj`** *(or `GitSandbox-vs.csproj` — replace the whole file)*

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>GitPractice</RootNamespace>
    <AssemblyName>GitPractice</AssemblyName>
  </PropertyGroup>

</Project>
```

**`Program.cs`** *(replace whatever the template generated)*

```csharp
// Program.cs — the entry point.
// It prints the ledger version, which is how you find out, by running the app,
// which side of a merge conflict you actually kept.
namespace GitPractice;

public static class Program
{
    public static void Main()
    {
        Console.WriteLine($"ledger v{Ledger.Version}");

        var account = new Account("SB-0001", "A. Ranjan", 1000m);
        account.Deposit(250m);
        Console.WriteLine(account.Describe());
    }
}
```

**`Ledger.cs`** *(new file)*

```csharp
// Ledger.cs — Version is the one line that two branches will fight over.
// Keep it on a line of its own; the conflict labs depend on that.
namespace GitPractice;

public static class Ledger
{
    public const string Version = "1.0";

    public static decimal Round(decimal amount) =>
        Math.Round(amount, 2, MidpointRounding.AwayFromZero);
}
```

**`Account.cs`** *(new file)*

```csharp
// Account.cs — a second class, so the labs have a file to forget and then remember.
namespace GitPractice;

public sealed class Account(string number, string holder, decimal balance)
{
    public string Number { get; } = number;
    public string Holder { get; } = holder;
    public decimal Balance { get; private set; } = balance;

    public void Deposit(decimal amount) => Balance = Ledger.Round(Balance + amount);

    public string Describe() => $"{Number} {Holder}: {Balance:0.00}";
}
```

**`README.md`** *(new file)*

```markdown
# GitPractice

A throwaway console app that exists only to be committed, branched, broken and recovered
while working through `docs/guides/git-with-gitea.md`.

Nothing in here is real. Delete the whole folder when you are done.

    dotnet run
    # ledger v1.0
    # SB-0001 A. Ranjan: 1250.00
```

**`.gitignore`** *(new file — note the leading dot, and no extension)*

```gitignore
# Build output. Regenerated by every build, so it must never be committed.
bin/
obj/

# Visual Studio's own scratch files.
.vs/
*.user
```

> **Creating a file called `.gitignore` in Visual Studio:** **Add → New Item… → Text File**, and
> type the name `.gitignore` including the leading dot. Windows Explorer refuses names that start
> with a dot; the VS dialog and the terminal both accept them fine.

---

### 0.3.3 Prove it works before you commit anything

```bash
dotnet run
```

Expected output, exactly:

```
ledger v1.0
SB-0001 A. Ranjan: 1250.00
```

In Visual Studio: **Ctrl+F5** (Start Without Debugging) gives the same two lines.

**Do not go further until you see those two lines.** Several labs verify themselves by running the
app — Lab V6 and Lab C5 both check that the number printed is the one you chose when resolving a
conflict — and that check is worthless if the app was already broken.

> **Starting over.** If a lab goes so wrong you want a clean slate: delete the whole sandbox
> folder, delete the practice repo in Gitea (**Settings → Delete This Repository**), and redo
> §0.3.1. It costs two minutes and nothing of value is lost. That is the entire reason the labs
> use a throwaway app instead of the real solution.

---

## 0.4 Your Gitea account, repo, and token

Both halves push to the real Gitea server, so both need this once.

### The token — never your password

Gitea will prompt for a username and password on your first `push`, whether that push comes from
the terminal or from Visual Studio's **↑** button. **Do not type your account password** —
generate a Personal Access Token (PAT) instead. A token can be scoped and revoked without
changing your login, and it is what Gitea expects.

1. Gitea → click your avatar → **Settings** → **Applications** → *Manage Access Tokens*
2. **Token Name** — name it after the machine (`work-laptop`)
3. **Select permissions** — modern Gitea has no single `repo` checkbox; it lists permission
   *groups* (repository, issue, user, organization, package, …), each a dropdown of
   *No Access / Read / Write*. Set **repository → Read and Write** and leave the rest at
   *No Access*. That covers clone, push, and PRs. Add **issue → Read and Write** only if you will
   file issues from `tea` ([§14.6](git-with-gitea-part3.md#146-tea-giteas-official-cli-optional)).
4. **Generate Token**, then **copy it now**. Gitea shows it exactly once.

[![Gitea Generate New Token form](img/git-with-gitea/g-token-new.png)](img/git-with-gitea/g-token-new.png)

*Settings → Applications → **Generate New Token**. Every permission group starts at No Access —
change only **repository** to **Read and Write**, then **Generate Token**.*

Then store it so you are not asked every time:

```bash
# Windows: uses the built-in Windows Credential Manager (encrypted, per-user)
git config --global credential.helper manager

# Next push prompts once: username = Adhir, password = PASTE THE TOKEN.
# It is saved from then on — Visual Studio uses the same store, so you do this once for both halves.
```

To replace a token later: Windows **Credential Manager** → *Windows Credentials* → find the
`git:http://192.168.0.22:3000` entry → edit or remove it. (Lab V13 makes you do exactly that.)

**Never** put the token in the remote URL (`http://user:token@host/...`) — it lands in
`.git/config` in clear text and leaks into any log that echoes the remote.

> **This server is plain HTTP, not HTTPS.** `http://192.168.0.22:3000` sends your token, and every
> byte you push and pull, unencrypted across the LAN. That is normally acceptable for an internal
> server on a trusted network, and it is what we have today — but be aware of it, and treat the
> token as LAN-visible: give it the narrowest permissions that work, never reuse it elsewhere, and revoke it (Gitea →
> Settings → Applications) the moment a machine is retired. **[§14.2](git-with-gitea-part3.md#142-ssh-instead-optional-nicer-once-set-up) (SSH) avoids this entirely**
> and is the better option if the server has SSH enabled — the traffic is encrypted even though
> the web UI is not. Worth raising with whoever administers the server: a TLS certificate on
> Gitea would close this properly.

### The practice repo

In the Gitea web UI: **+** (top right) → **New Repository**.

- **Name:** `git-practice-vs` for Part 1, or `git-practice` for Part 2
- **Visibility:** Private
- **Leave "Initialize repository" UNCHECKED.** You want a genuinely empty repo — your first push
  puts *your* history into it, and an initialised repo (with its own README commit) would collide
  with that on the very first push.

[![Gitea New Repository form](img/git-with-gitea/g-new-repo.png)](img/git-with-gitea/g-new-repo.png)

*The two boxes that matter: **Make repository private** ticked, **Initialize Repository** left
empty. Everything in between can stay as it is.*

[![A new, empty Gitea repository](img/git-with-gitea/g-empty-repo.png)](img/git-with-gitea/g-empty-repo.png)

*What you should see right after **Create Repository**: an empty repo with a Quick Guide. The
last block, **Pushing an existing repository from the command line**, is exactly what Part 2's Lab
C2 types. (This screenshot is of a throwaway repo, `git-guide-demo`; yours will say
`git-practice-vs` or `git-practice`.)*

---

## 0.5 Pull requests — the part that is not git

**A pull request is not a git feature.** Git — the program on your machine — knows about commits,
branches and remotes, and has no idea what a PR is. `git help -a` will never list one. Pull
requests were invented by the web platforms (GitHub first, then Gitea, GitLab, Azure DevOps) and
live entirely on the **server**.

This matters for both halves of this guide, and it is the reason **neither** half can finish a
workflow without a browser tab:

- There is **no git command** that opens a pull request. `git` does not speak Gitea's API.
- There is **no Visual Studio button** that opens one either. VS's PR tooling binds to GitHub and
  Azure DevOps only; to Visual Studio our server is just a generic HTTP remote.

A PR is a page on Gitea that says *"please merge my branch into `main`"*, wrapped around three
things:

1. **A diff** — Gitea has both branches, so it computes exactly what changes if the merge happens.
2. **A conversation** — comments on the change as a whole, and on individual lines of code.
3. **A merge button** — which performs the merge *on the server*. In Gitea it is labelled for the
   style it will use, **Create merge commit** ([§14.4](git-with-gitea-part3.md#144-merge-styles-gitea-offers-on-a-pr)).

That is the entire concept: a branch, a computed diff, a comment thread, and a button.

**Why it exists.** Without a PR, "merging your work" means running a merge locally and pushing to
`main`. Nobody saw it, nobody could object, and there is no record of why. The PR inserts a
deliberate pause between *"I have finished"* and *"it is in main"* — a place for a second pair of
eyes, for automated checks to run, and for a written reason that outlives everyone's memory.

**The name is backwards, and it confuses everybody.** You are not pulling anything. *You* are
asking *the maintainer* to pull from your branch — the name survives from the original email-based
workflow. GitLab calls it a **Merge Request**, which is what it actually is. Read "PR" as "merge
request" and it stops being strange.

Where the work lives at each step — identical whichever half you are in:

```
create a branch             LOCAL ONLY   Gitea knows nothing about this yet
    ...commits...           LOCAL ONLY   still nothing
push the branch             ON GITEA     your branch now exists, beside main.
                                         main is UNCHANGED.
open a PR in the browser    ON GITEA     "compare these two branches for me"
    review, discussion
    more commits pushed     ON GITEA     the PR updates itself, automatically
click Merge                 ON GITEA     the server merges; main moves
switch to main and pull     LOCAL        you bring the result back down
```

The same journey as a picture — your machine on the left, the server on the right, time running
down the page (`o` is a commit):

```
      YOUR MACHINE                               GITEA  (192.168.0.22:3000)
      ════════════                               ══════════════════════════
  1   main  o                                    main  o
            │
  2         └── o ── o   feature/x               (Gitea has never heard of it)
                     │
  3                  └──── git push ───────────► feature/x  o ── o     beside main;
                                                                        main unchanged
  4                                              Pull Request:
                                                 "merge feature/x into main"
                                                   · Files Changed = the diff
                                                   · comments on single lines
  5   feature/x  o ── o ── o   fix after review
                           └── git push ───────► the PR shows the new commit by itself
  6                                              Create merge commit:
                                                 main  o ─────────────── M
  7   main  o ─────────── M  ◄──── git pull ─────────────────────────────┘
      then delete feature/x, here and on Gitea
```

**Do them even when you are the only developer.** Solo, a PR costs thirty seconds and still gives
you one readable view of everything you are about to make permanent in `main`. That is how you
catch the committed password.

### Opening one

1. Go to `http://192.168.0.22:3000/Adhir/<your-practice-repo>`
2. **Pull Requests** tab → **New Pull Request** button → pick the two branches in the compare bar.
   (Shortcut: right after a push, the repo page shows a green *"You pushed on branch `feature/x`"*
   banner with its own **New Pull Request** button — it disappears after a while, and Gitea has no
   *"Compare & Pull Request"* button, that is GitHub's wording.)
3. **Check the direction: base `main` ← compare `your-branch`.** Gitea labels the two boxes
   **merge into:** (the base, left) and **pull from:** (your branch, right), with an arrow pointing
   left. Getting these backwards is the single most common PR mistake, and it produces a confusing
   empty or enormous diff.
4. **Title** — the same rules as a commit subject ([§0.6](#06-commit-messages-and-branch-names)):
   short, imperative, specific. *"Fix penal-interest label on locker type screen"*, not *"changes"*.
5. **Description** — what changed, **why**, and how you know it works. If it touches a screen, say
   which. If it fixes an issue, write `Fixes #12` and Gitea closes issue 12 automatically when the
   PR merges.
6. Right-hand sidebar → **Reviewers** → pick someone. A PR nobody is assigned to is a PR nobody
   reads. *On your solo practice repo the list is empty — Gitea only offers collaborators, and you
   cannot request review from yourself. Skip it there; use it on real repos.*
7. **Create Pull Request**.

**Watch it once before you read the details** — the whole flow, start to merge, on our Gitea:

<figure class="clip"><video controls preload="none" poster="img/git-with-gitea/rec-pr-poster.png" src="img/git-with-gitea/rec-pr.webm"></video></figure>

*82 seconds, recorded on our Gitea 1.27 in a throwaway repo: the push banner, the direction check, title and description, Create Pull Request, a comment on one line in Files Changed, then **Create merge commit** with **Delete Branch** ticked. The screens below are the same steps, one at a time.*

[![The "You pushed on branch" banner](img/git-with-gitea/g-recent-push.png)](img/git-with-gitea/g-recent-push.png)

*Step 2's shortcut: the banner Gitea shows on the repo page right after you push a branch.*

[![Comparing changes: merge into main, pull from the feature branch](img/git-with-gitea/g-compare.png)](img/git-with-gitea/g-compare.png)

*Step 3: **merge into:** `main` ← **pull from:** your branch. Below the bar Gitea lists the commits
that would be merged — two here. If that list is empty or huge, stop and check the direction.*

[![The new pull request form](img/git-with-gitea/g-pr-new.png)](img/git-with-gitea/g-pr-new.png)

*Steps 4–7: a specific title, a description that says what, why and how it was tested, and
**Create Pull Request**. Note the hint under the title about `WIP:`.*

**Not ready for review yet?** Start the title with `WIP:` (or `[WIP]`) — Gitea greys out the merge
box until you drop the prefix. On an open PR the same switch is the **Still in progress? Add WIP:
prefix** link in the right-hand sidebar.

### The PR page, tab by tab

| Tab | What it holds |
|---|---|
| **Conversation** | The description, all comments, and the merge button. The narrative record |
| **Commits** | Your commits in order. This is why messages matter — a reviewer reads this list first |
| **Files Changed** | The diff. Where line-by-line review happens |

[![An open pull request, Conversation tab](img/git-with-gitea/g-pr-conversation.png)](img/git-with-gitea/g-pr-conversation.png)

*The top of an open PR: status (**Open**), "wants to merge 2 commits from `feature/vs-staging` into
`main`", the three tabs with their counts, and the description as the first comment.*

[![Commits tab](img/git-with-gitea/g-pr-commits.png)](img/git-with-gitea/g-pr-commits.png)

*The **Commits** tab — the list a reviewer reads first, which is why commit messages matter.*

In **Files Changed**, hover any line and click the **+** to comment on exactly that line. That is
the whole mechanism of code review: specific comments attached to specific lines, which stay
attached as the code changes.

[![Commenting on one line in Files Changed](img/git-with-gitea/g-pr-line-comment.png)](img/git-with-gitea/g-pr-line-comment.png)

*The blue **+** beside line 7 opened a comment box for that line only. **Add single comment** posts
it now; **Start review** holds it as pending until you submit the review with the **Review**
button (top right).*

**Responding to review is just more commits.** Make the changes on the same branch, commit, push.
Refresh the PR — the new commit is in it. **Never close a PR and open a new one** to incorporate
feedback; you would throw away the entire discussion. The PR tracks the *branch*, so anything you
push to that branch is in the PR automatically.

### When you are the reviewer

You will be on this side too, so know what is expected:

- Read the **description** first, then **Commits**, then **Files Changed**. In that order — you
  need the intent before the diff means anything.
- Comment on lines, not on people. *"This throws if the list is empty"* — not *"you forgot"*.
- Distinguish blocking from optional. Prefix nits: *"nit: spelling"* — the author then knows what
  must change and what is taste.
- The verdict lives behind the **Review** button at the top right of **Files Changed** — write a
  summary, then pick **Comment**, **Approve**, or **Request changes**. Line comments you leave
  first are held as *pending* until you submit that review, which is how you post ten remarks as
  one notification instead of ten. Choosing "Comment" when you mean "Request changes" leaves the
  author guessing. **Approve** is greyed out on your own PR — Gitea does not let authors approve
  themselves, which is why the practice repos never show it enabled.

  [![The Submit review box](img/git-with-gitea/g-pr-review.png)](img/git-with-gitea/g-pr-review.png)

  *The **Review** button opens this box. Here it is the author's own PR, so **Approve** is disabled.*

- Pull the branch down and **run it** when the change is non-trivial. A diff that reads correctly
  and a program that behaves correctly are different claims.

### PR troubleshooting

| Symptom | Cause and fix |
|---|---|
| <span id="pr-empty"></span>The diff is empty | Base and compare are the same branch, or you never pushed. Push and re-check the direction |
| <span id="pr-enormous"></span>The diff is enormous and full of files you never touched | Base and compare are backwards, or you branched off the wrong branch. Re-open with the right base |
| <span id="pr-no-diff"></span>"There are no differences to show. There is no need to create a pull request." | Your commits are still local, or both boxes name the same branch. Push, then re-pick **pull from:** |
| <span id="pr-no-branch"></span>Your branch is not in the dropdown | Not pushed yet, or pushed to a different remote |
| <span id="pr-not-yours"></span>The PR shows commits that are not yours | You branched off someone else's branch instead of `main` |
| <span id="pr-conflicts"></span>"This branch has conflicts that must be resolved" | `main` moved under you. Merge `main` into your branch locally, resolve, push — the PR re-checks itself and goes green |
| <span id="pr-no-merge"></span>Cannot merge, no button | The **Create merge commit** button is at the *bottom* of **Conversation**, under every comment — scroll. Genuinely absent means branch protection, unmet approvals, or a `WIP:` title ([§14.5](git-with-gitea-part3.md#145-branch-protection-expect-main-to-reject-you)) |
| <span id="pr-closed"></span>You closed the PR by accident | Reopen it on the same page — the branch and discussion are intact |
| <span id="pr-force-pushed"></span>You force-pushed and the review comments now point at nothing | Comments on rewritten commits become "outdated". Avoid force-pushing a branch that is under review |

---

## 0.6 Commit messages and branch names

### Messages

First line ≤ 72 characters, imperative mood ("Add taluka lookup", not "Added" or "Adding"),
explaining **why** if it isn't obvious. Start it with one of this repo's `CHANGELOG.md` type words:

```
fix: reference cache ignored Cache:Provider

AddControllersWithViews registers a default MemoryDistributedCache before
AddCbsFramework runs, so the provider switch short-circuited on every startup.
```

`feat` / `fix` / `docs` / `refactor` / `test` are **Conventional Commits** — a convention, not a
git feature. Git will happily accept any message; this is a habit the team keeps because
[`CHANGELOG.md`](../../CHANGELOG.md) already uses these words across hundreds of entries. Match them
and your commit message and your changelog line become the same sentence, written once.

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

### Branch names

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

**Never commit directly to `main`.** Branch, push, open a PR, get it reviewed, merge. That is the
whole workflow, and it is the same on every team you will ever join — and the same in both halves
of this guide.

---

**Next:** [Part 1 — Git in Visual Studio →](git-with-gitea-part1.md)

[Git with Gitea — start page](git-with-gitea.md) · [Part 1 · Visual Studio →](git-with-gitea-part1.md) · [Cheat sheet](git-with-gitea-cheat-sheet.md)
