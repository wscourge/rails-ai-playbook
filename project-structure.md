# Project Structure Templates

> Templates for CLAUDE.md and docs/ folder when creating new projects.

---

## Overview

Every new project should have:

```
my-app/
├── CLAUDE.md                    # Brief index, links to docs/
├── README.md                    # Dev + prod setup, third-party services, env vars
├── .env.example                 # Required ENV vars
├── .rubocop.yml                 # RuboCop config (from playbook)
├── .rubocop_todo.yml            # Auto-generated exclusions
├── .yamllint.yml                # YAML linting rules
├── .prettierrc                  # Prettier formatting rules
├── .prettierignore              # Files Prettier should skip
├── .stylelintrc.json            # Stylelint CSS rules
├── eslint.config.mjs            # ESLint config
├── jsconfig.json                # @ alias for IDE support
├── .claude/
│   └── hooks/
│       └── post-commit-audit.sh # Quality enforcement (from playbook)
└── docs/
    ├── SCHEMA.md                # Every table, column, relationship, index
    ├── BUSINESS_RULES.md        # Domain logic, permissions, edge cases
    ├── DESIGN.md                # Brand identity (from interview)
    ├── ARCHITECTURE.md          # Technical decisions
    ├── CODE_QUALITY.md          # Code quality rules (from playbook, grows with project)
    ├── TESTING.md               # Testing principles (from playbook, grows with project)
    ├── PROJECT_SETUP.md         # Local dev, testing, deploy
    └── ROADMAP.md               # Feature priorities
```

---

## CLAUDE.md Template

```markdown
# [App Name] - Claude Playbook

> Instructions for working on this Rails + Inertia + Vite + Tailwind project.
> **These rules are mandatory. Every file you create or modify must follow them.**

**Read these docs before writing any code:**
- [Code Quality](docs/CODE_QUALITY.md) - **Mandatory rules** for controllers, interactors, models, database, imports, linting
- [Testing Guidelines](docs/TESTING.md) - **Mandatory rules** for RSpec, factories, shared examples
- [Schema](docs/SCHEMA.md) - Every table, column, relationship, and index
- [Business Rules](docs/BUSINESS_RULES.md) - Domain logic, permissions, edge cases
- [Design System](docs/DESIGN.md) - Colors, typography, components
- [Architecture](docs/ARCHITECTURE.md) - Technical decisions, key flows
- [Project Setup](docs/PROJECT_SETUP.md) - Local dev, testing, deploy
- [Roadmap](docs/ROADMAP.md) - Feature priorities

---

## Stack

| Layer | Technology |
|-------|------------|
| Server | Rails + PostgreSQL |
| Frontend | Inertia + React + Vite |
| Styling | Tailwind + shadcn/ui |
| Auth | Rails sessions [+ Google OAuth] |
| Payments | Stripe via Pay gem |
| Jobs | Solid Queue |
| Email | Resend (prod) / letter_opener_web (dev) |
| Testing (Ruby) | RSpec + FactoryBot + FFaker + Shoulda Matchers |
| Testing (JS) | Jest (logic only) |
| CSS Linting | Stylelint |
| JS Linting | ESLint |
| Ruby Linting | RuboCop + extensions |
| Formatting | Prettier (JS/CSS/YAML) |
| YAML Linting | yamllint |
| Package Manager (JS) | Bun |
| Business Logic | Interactor gem |
| Error Tracking | Sentry |
| i18n | Rails I18n + react-i18next |
| Hosting | Kamal |

---

## Quick Reference

### Commands
\`\`\`bash
bin/dev              # Start dev server
bundle exec rspec    # Run Ruby tests
bun test             # Run JS tests (Jest)
bin/rails console    # Rails console
\`\`\`

### Linting & Formatting
\`\`\`bash
bundle exec rubocop          # Ruby linting
bun lint                     # JS linting
bun lint:fix                 # JS auto-fix (sorts imports, removes unused)
bun lint:css                 # CSS linting
bun format:check             # Prettier check (JS/CSS/YAML)
bun format                   # Prettier auto-format
yamllint config/locales/ app/frontend/locales/  # YAML linting
\`\`\`

### Key Paths
- Pages: `app/frontend/pages/`
- Components: `app/frontend/components/`
- Interactors: `app/interactors/`
- Locales (Ruby): `config/locales/`
- Locales (React): `app/frontend/locales/`
- Validators (JS): `app/frontend/lib/validators.js`
- Styles: `app/frontend/entrypoints/application.css`

---

## Mandatory Conventions

### Backend

- **Controllers do 3 things:** authorize, call an interactor, render. No business logic.
- **All business logic in interactors** (`app/interactors/`). Use the Interactor gem. One interactor = one job.
- **No `validates` on models. Ever.** All validation lives in `Validate*` interactors. The database enforces integrity (NOT NULL, unique indexes, CHECK constraints, foreign keys).
- **Strong params only.** Never `.permit!`.
- **Class methods use `class << self`**, not `self.method_name`. Class methods go at the top, before instance methods.
- **Jobs call one interactor.** No business logic in job classes.
- **Seeds are idempotent.** Use `find_or_create_by`. Split into numbered files under `db/seeds/`.
- **Index endpoints use standardized params:** `search`, `page`, `per_page`, `sort`, `sort_direction`, `filter[field]`. Use the `Indexable` concern.
- **Return 404 for unauthorized access**, not 403.
- **i18n everywhere.** `I18n.t()` in Ruby — no hardcoded English strings.

### Frontend

- **No TypeScript.** Plain JS/JSX only. No `.ts`, `.tsx` files.
- **Imports use `@/` alias** (maps to `app/frontend/`). No `../` imports ever. Relative `./` only for same directory or one level down.
- **Internal links: `<Link href={routes.X} />`** (Inertia). Never construct URLs with template literals.
- **Routes from server:** `usePage().props.routes`. Never hardcode paths.
- **Icons via wrapper components** in `@/components/icons/`. Never import directly from `lucide-react`.
- **shadcn/ui for all controls.** Check [Blocks](https://www.shadcn.io/blocks/) before building custom components.
- **Tailwind tokens only.** `bg-background`, not `bg-white`. No hardcoded colors.
- **Mobile first, 320px minimum.** Base styles for mobile, then `sm:` → `md:` → `lg:` to scale up.
- **Validate forms client-side** with Zod schemas before submitting.
- **i18n everywhere.** `useTranslation()` in React — no hardcoded English strings, including inside shadcn/ui components.
- **Dark mode always supported.** Light, dark, and system themes via `ThemeProvider`.
- **Pages stay thin.** Over 100 lines → extract sub-components. Complex state → extract a hook.

### Commits

- **Conventional Commits:** `type(scope): description`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`

---

## Review Checklist

**Run this checklist before completing every task:**

- [ ] Tests added/updated, `bundle exec rspec` passes
- [ ] No hardcoded English — i18n keys used (both frontend and backend)
- [ ] Frontend form validation present (Zod schema)
- [ ] Backend params validated in interactor (no `validates` on models)
- [ ] Inertia `<Link/>` for internal navigation
- [ ] Routes from `usePage().props.routes` — no hardcoded paths
- [ ] Imports use `@/` — no `../` parent imports
- [ ] shadcn/ui for controls & cards (checked Blocks first)
- [ ] Icons imported from `@/components/icons/` wrappers
- [ ] Mobile-first, works at 320px, tablet handled at `md` breakpoint
- [ ] Tailwind tokens (not hardcoded colors)
- [ ] No secrets in code (use ENV)
- [ ] Public endpoints have `allow_unauthenticated_access`
- [ ] Class methods use `class << self` block
- [ ] Bullet gem not flagging N+1 queries
- [ ] `bundle exec rubocop` passes
- [ ] `bun lint` passes
- [ ] `bun lint:css` passes
- [ ] `bun format:check` passes
- [ ] `yamllint` passes on locale YAML files
- [ ] Commit message follows Conventional Commits

---

## Non-Negotiables

1. Small tasks (30-90 min chunks)
2. Tests for every behavior change
3. Never hardcode routes or English strings
4. Use ENV for all secrets and configuration
5. Update docs when adding features or changing schema
6. All linters must pass before committing

---

## Available MCP Tools

Use these for research and validation:

| MCP | Purpose |
|-----|---------|
| **Reddit (dialog-mcp)** | Community research, pain points, feature requests |
| **Twitter/X** | Market sentiment, competitor mentions, trends |
| **Exa** | Web search, company research, competitive analysis |
| **Context7** | Up-to-date library documentation |
| **Claude-Mem** | Persistent memory across sessions |

### Usage
- Research before building new features
- Validate assumptions with real community data
- Check latest docs before implementing libraries
```

---

## docs/PROJECT_SETUP.md Template

```markdown
# Project Setup

> How to run [App Name] locally, test, and deploy.

---

## Prerequisites

- Ruby (latest stable)
- Node.js (latest LTS)
- PostgreSQL (latest stable)
- Docker Desktop (for Kamal deployment)
- Kamal (`gem install kamal`)
- Stripe CLI (for webhook testing)

---

## Local Development

### 1. Clone & Install

\`\`\`bash
git clone [repo-url]
cd [app-name]
bundle install
bun install
\`\`\`

### 2. Environment Setup

\`\`\`bash
cp .env.example .env
# Edit .env with your values
\`\`\`

### 3. Database Setup

\`\`\`bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Idempotent — safe to run multiple times
\`\`\`

### 4. Start Dev Server

\`\`\`bash
bin/dev
# App runs at http://localhost:3000
\`\`\`

---

## Testing

\`\`\`bash
# Run all Ruby tests
bundle exec rspec

# Run specific spec file
bundle exec rspec spec/interactors/users/create_user_spec.rb

# Run specific test
bundle exec rspec spec/interactors/users/create_user_spec.rb:42

# Run JS tests
bun test

# Run JS tests in watch mode
bun run test:watch

# Lint CSS
bun stylelint "app/frontend/**/*.css"
\`\`\`

---

## Stripe Testing

\`\`\`bash
# Terminal 1: Forward webhooks
stripe listen --forward-to localhost:3000/webhooks/stripe

# Terminal 2: Trigger test events
stripe trigger customer.subscription.created
\`\`\`

---

## Deployment

### Kamal (Hetzner)

\`\`\`bash
# First deploy (bootstraps servers)
kamal setup

# Subsequent deploys
kamal deploy

# Migrations run automatically via docker-entrypoint
# Manual if needed:
kamal app exec "bin/rails db:migrate"

# View logs
kamal app logs -f
\`\`\`

### Environment Variables

See `.env.example` for required vars. Production secrets go in `.kamal/secrets`:

\`\`\`bash
# Edit .kamal/secrets (never committed)
vim .kamal/secrets

# Push env changes without redeploying
kamal env push
\`\`\`

---

## Useful Commands

\`\`\`bash
bin/rails console          # Rails console
bin/rails routes           # List routes
bin/rails db:rollback      # Undo last migration
kamal app exec -i "bin/rails console"   # Production console
\`\`\`
```

---

## docs/ARCHITECTURE.md Template

```markdown
# Architecture

> Technical decisions and system design for [App Name].

---

## Data Model

### Core Models

\`\`\`
User
├── has_many :projects
├── has_many :subscriptions (via Pay)
└── attributes: email, name, plan, etc.

Project
├── belongs_to :user
└── attributes: name, description, etc.
\`\`\`

### Database Schema

[Add ERD or key tables]

---

## Key Services

| Interactor | Purpose |
|------------|---------|
| PlansService | Centralized plan/pricing config |
| [Service] | [Purpose] |

---

## Authentication Flow

1. User signs up (email/password or Google OAuth)
2. Email verification sent
3. Session created via Rails auth
4. JWT not used - cookie-based sessions

---

## Payment Flow

1. User selects plan on pricing page
2. Redirect to Stripe Checkout
3. Webhook receives `subscription.created`
4. User record updated with plan
5. Billing portal for management

---

## Background Jobs

Using Solid Queue (single database).

| Job | Purpose | Priority |
|-----|---------|----------|
| [Job] | [Purpose] | default |

---

## External Integrations

| Service | Purpose | Docs |
|---------|---------|------|
| Stripe | Payments | stripe.com/docs |
| Resend | Email | resend.com/docs |
| [Service] | [Purpose] | [URL] |

---

## Technical Decisions

### Why [Decision]?

[Reasoning]

### Why not [Alternative]?

[Reasoning]
```

---

## docs/ROADMAP.md Template

```markdown
# Roadmap

> Feature priorities and development phases for [App Name].

---

## Current Phase: MVP

**Goal:** [One sentence goal]

**Target:** [Date or milestone]

### Must Have
- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3

### Should Have
- [ ] Feature 4
- [ ] Feature 5

### Nice to Have
- [ ] Feature 6

---

## Phase 2: [Name]

**Goal:** [One sentence goal]

### Planned Features
- [ ] Feature A
- [ ] Feature B

---

## Backlog

Ideas for future consideration:
- Idea 1
- Idea 2
- Idea 3

---

## Completed

### Phase 0: Foundation
- [x] Rails setup
- [x] Auth (email + Google)
- [x] Stripe payments
- [x] Kamal deployment
```

---

## README.md Template

```markdown
# [App Name]

> [One-line description]

## Features

- Feature 1
- Feature 2
- Feature 3

## Tech Stack

- Rails + PostgreSQL
- Inertia + React + Vite
- Tailwind + shadcn/ui
- Stripe payments
- Kamal + Hetzner hosting

---

## Development Setup

### Prerequisites

- Ruby (latest stable)
- PostgreSQL (latest stable)
- Bun (latest stable)
- Stripe CLI (for webhook testing)

### Steps

\`\`\`bash
git clone [repo-url]
cd [app-name]
bundle install
bun install
cp .env.example .env    # Edit with your values
bin/rails db:setup
bin/dev                  # http://localhost:3000
\`\`\`

### Third-Party Services (Development)

| Service | What to do | Env var(s) |
|---------|-----------|------------|
| [Stripe](https://dashboard.stripe.com/test/apikeys) | Create test-mode API keys | `STRIPE_PUBLIC_KEY`, `STRIPE_SECRET_KEY` |
| [Stripe CLI](https://docs.stripe.com/stripe-cli) | `stripe listen --forward-to localhost:3000/webhooks/stripe` | `STRIPE_WEBHOOK_SECRET` (printed by CLI) |
| [Google Cloud Console](https://console.cloud.google.com/apis/credentials) | Create OAuth 2.0 credentials (redirect: `http://localhost:3000/auth/google_oauth2/callback`) | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| [Resend](https://resend.com) | Not needed locally — uses `letter_opener_web` | — |
| [Sentry](https://sentry.io) | Optional for dev — create a project if you want error tracking | `SENTRY_DSN` |

> Add/remove rows based on the project's actual integrations.

---

## Production Setup

### Infrastructure

1. **Hetzner Cloud** — Provision servers (web + db), configure firewall and private network. See [kamal-deploy.md](docs links) for full steps.
2. **PostgreSQL** — Install on db server, create database and user, allow private-network connections.
3. **Docker Hub** — Create account + access token for container registry.
4. **Domain** — Point DNS A records to web server IP.

### Third-Party Services (Production)

| Service | What to do | Env var(s) |
|---------|-----------|------------|
| [Stripe](https://dashboard.stripe.com/apikeys) | Switch to **live-mode** API keys | `STRIPE_PUBLIC_KEY`, `STRIPE_SECRET_KEY` |
| [Stripe Webhooks](https://dashboard.stripe.com/webhooks) | Add endpoint `https://[domain]/webhooks/stripe` | `STRIPE_WEBHOOK_SECRET` |
| [Google Cloud Console](https://console.cloud.google.com/apis/credentials) | Add production redirect URI: `https://[domain]/auth/google_oauth2/callback` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| [Resend](https://resend.com) | Verify sending domain, create production API key | `RESEND_API_KEY` |
| [Sentry](https://sentry.io) | Create project, grab DSN | `SENTRY_DSN` |
| [Docker Hub](https://hub.docker.com/settings/security) | Create access token | `KAMAL_REGISTRY_PASSWORD` |

> Add/remove rows based on the project's actual integrations.

### Secrets

All production secrets go in `.kamal/secrets` (never committed) and are mirrored as GitHub repository secrets for CI/CD:

\`\`\`bash
# Local (Kamal reads from this file)
vim .kamal/secrets

# GitHub (for GitHub Actions auto-deploy)
gh secret set SECRET_NAME
gh secret list
\`\`\`

### Deploy

\`\`\`bash
# First deploy
kamal setup

# Subsequent deploys — push to main (GitHub Actions auto-deploys)
git push origin main
\`\`\`

---

## Keeping This README Up to Date

When any of these change, update the relevant section above:

- **New third-party service** — add a row to the dev and/or prod services table
- **New env var** — add to the table AND to `.env.example`
- **Infrastructure change** — update the Production Setup section
- **Prerequisite change** — update the Prerequisites list

---

## Documentation

- [Design System](docs/DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Business Rules](docs/BUSINESS_RULES.md)
- [Schema](docs/SCHEMA.md)
- [Roadmap](docs/ROADMAP.md)

## License

[License type]
```

---

## Creation Checklist

When creating a new project:

1. [ ] Create CLAUDE.md (brief, links to docs/)
2. [ ] Create README.md (dev setup, prod setup, third-party services table, env vars — keep updated)
3. [ ] Create docs/ folder
4. [ ] Create docs/SCHEMA.md (from domain model interview)
5. [ ] Create docs/BUSINESS_RULES.md (from domain model interview)
6. [ ] Create docs/DESIGN.md (from brand interview)
7. [ ] Create docs/ARCHITECTURE.md
8. [ ] Create docs/CODE_QUALITY.md (copy from `~/.claude/rails-playbook/code-quality.md`)
9. [ ] Create docs/TESTING.md (copy from `~/.claude/rails-playbook/testing-guidelines.md`)
10. [ ] Create docs/PROJECT_SETUP.md
11. [ ] Create docs/ROADMAP.md
12. [ ] Create .env.example
13. [ ] Copy `.claude/hooks/post-commit-audit.sh` from playbook, customize design system checks
14. [ ] Register hook in `.claude/settings.json` (see `~/.claude/rails-playbook/hooks/README.md`)
15. [ ] Create `.rubocop.yml` (from [code-quality.md](code-quality.md#rubocop) base template)
16. [ ] Create `.rubocop_todo.yml` (empty file — generate later with `--auto-gen-config`)
17. [ ] Create `eslint.config.mjs` (from [inertia-react.md](inertia-react.md#eslint--prettier))
18. [ ] Create `.prettierrc` (from [inertia-react.md](inertia-react.md#eslint--prettier))
19. [ ] Create `.prettierignore` (from [inertia-react.md](inertia-react.md#eslint--prettier))
20. [ ] Create `.stylelintrc.json` (from [inertia-react.md](inertia-react.md#stylelint))
21. [ ] Create `.yamllint.yml` (from [code-quality.md](code-quality.md#yamllint))
22. [ ] Create `jsconfig.json` (from [inertia-react.md](inertia-react.md#path-alias----appfrontend) — `@` alias)
23. [ ] Add lint/format scripts to `package.json`
24. [ ] Verify all linters pass on fresh project (`rubocop`, `bun lint`, `bun lint:css`, `bun format:check`, `yamllint`)
25. [ ] Add all docs to .gitignore exclusion (should be committed)
