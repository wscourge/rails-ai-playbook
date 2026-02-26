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

**Project Docs:**
- [Schema](docs/SCHEMA.md) - Every table, column, relationship, and index
- [Business Rules](docs/BUSINESS_RULES.md) - Domain logic, permissions, edge cases
- [Design System](docs/DESIGN.md) - Colors, typography, components
- [Architecture](docs/ARCHITECTURE.md) - Technical decisions, key flows
- [Code Quality](docs/CODE_QUALITY.md) - Rules for writing clean, maintainable code
- [Testing Guidelines](docs/TESTING.md) - Principles for writing excellent tests
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
| Email | Resend (prod) / letter_opener (dev) |
| Testing (Ruby) | RSpec + FactoryBot + FFaker |
| Testing (JS) | Jest (logic only) |
| CSS Linting | Stylelint |
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
bun stylelint "app/frontend/**/*.css"  # Lint CSS
bundle exec rspec spec/interactors/  # Run interactor tests
bin/rails console    # Rails console
\`\`\`

### Key Paths
- Pages: `app/frontend/pages/`
- Components: `app/frontend/components/`
- Interactors: `app/interactors/`
- Locales (Ruby): `config/locales/`
- Locales (React): `app/frontend/locales/`
- Validators (JS): `app/frontend/lib/validators.ts`
- Styles: `app/frontend/entrypoints/application.css`

### Conventions
- Internal links: `<Link href={routes.X} />` (Inertia)
- Routes: Always use shared routes from `usePage().props.routes`
- Icons: Lucide React only
- Components: shadcn/ui
- Colors: Tailwind tokens (`bg-background`, not `bg-white`)
- Business logic: Always in `app/interactors/`, never in controllers or models
- Validation (backend): In `Validate*` interactors, not model validations
- Validation (frontend): Zod schemas, validate before sending request
- i18n: `I18n.t()` in Ruby, `useTranslation()` in React — no hardcoded English
- Class methods: `class << self` block, never `self.method_name`
- Timestamps: Stored UTC, displayed in user's timezone via `Time.use_zone`

### Frontend Design
When building pages, components, or layouts, use the `/frontend-design` skill to generate distinctive, production-grade UI. Avoids generic AI aesthetics and uses the project's design system (Tailwind + shadcn/ui).

---

## Non-Negotiables

1. Small tasks (30-90 min chunks)
2. Tests for behavior changes
3. Never hardcode routes
4. Use ENV for all secrets
5. Update docs when adding features

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
bin/rails db:seed  # Optional
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
15. [ ] Add all docs to .gitignore exclusion (should be committed)
