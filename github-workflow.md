# GitHub Workflow — Issues, Projects, and the "Manual, by Human" queue

How work is tracked across all my repos. Every AI agent working in any of my
projects follows this; copy the relevant parts into each repo's `AGENTS.md` /
`.claude/CLAUDE.md` when setting up a project.

## The two kinds of work

1. **Agent work** — anything an AI coding agent can finish end-to-end with
   repo access, the `gh` CLI, and existing deploy credentials: code, tests,
   docs, migrations, seeds, deploys, CLI-drivable configuration.
2. **Human work** — anything that needs *me* personally: logging into web
   consoles (GA4, Firebase, App Store Connect, Play Console, Cloudflare/DNS,
   Brevo, Sentry, RevenueCat, banks…), creating third-party
   accounts/properties, minting or rotating credentials, accepting store or
   legal agreements, and spend/business decisions.

## Rules

### 1. Every workstream is a GitHub Issue

- Open an issue (`gh issue create`) in the repo the work belongs to **at the
  start** of any feature, fix, audit, or migration. The issue is the unit of
  work; per-feature plan files (`docs/roadmap/NNNN_*.md`) are the spec behind
  it and are linked from the issue.
- Label agent work `owner: eng` (`owner: either` when a human could equally
  do it).
- **Resolve on merge**: work merges to `main` (no PRs — local merge), then the
  issue closes. Put `Closes #N` in the merging commit so it auto-closes when
  it lands on `main`, or run `gh issue close N --comment "shipped in <sha>"`.
  Never close an issue whose work hasn't merged; never leave a merged issue
  open.

### 2. Human work goes to the "Manual, by Human" project — always

**[Manual, by Human](https://github.com/users/wscourge/projects/10)** (user
project `10`, owner `wscourge`) is the single cross-repo queue I check for
pending manual work. If a human-action item is not in that project, I will
miss it — so agents must never bury one in a plan file, a checklist, a commit
message, or a mixed issue.

The moment a human-only step surfaces, split it into its own issue and route
it there:

```bash
gh issue create --repo wscourge/<repo> \
  --title "[Manual] <what the human must do>" \
  --assignee wscourge --label "owner: user" \
  --body "<exact console URLs, step-by-step actions, and what it unblocks>"
gh project item-add 10 --owner wscourge --url <created-issue-url>
```

- Assignee `wscourge` + label `owner: user` + project 10 — **all three, every
  time**.
- One issue per coherent manual task. The body always gives exact console
  URLs, concrete steps, and **what it unblocks**.
- Agent-doable work never goes into that project.
- A mixed issue gets split: human part → Manual, by Human; agent part stays a
  normal issue.
- When I complete the manual step, I (or an agent verifying it) close the
  issue; the project's Done column is the archive.

### 3. No pull requests

Branches follow `{type}/{meaningful-kebab-slug}` with Conventional Commits.
Merge to `main` locally — no PRs, no review gates. Repo-specific deploy
semantics (does pushing `main` deploy?) live in each repo's `AGENTS.md`.

## New-repo setup

When creating a new repo, seed the label taxonomy before the first issue:

```bash
gh label create "owner: user"   --repo wscourge/<repo> --color D93F0B \
  --description "Needs the human owner to act (console, credentials, decisions)"
gh label create "owner: eng"    --repo wscourge/<repo> --color 0E8A16 \
  --description "AI agent / engineering work"
gh label create "owner: either" --repo wscourge/<repo> --color FBCA04 \
  --description "Human or agent can do it"
```

No new per-repo project is needed for human work — "Manual, by Human" is
user-level and spans all repos. Per-initiative projects for agent work are
optional; the issues themselves are the tracking that matters.
