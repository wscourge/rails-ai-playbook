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
│   ├── CLAUDE.md                # Claude-specific project rules (from playbook)
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

**CRITICAL: Keep [docs/ROADMAP.md](docs/ROADMAP.md) always up to date.**
- Mark items `[x]` as you complete them
- Add new items as they emerge from development
- This is the source of truth for project progress

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
| Email | Brevo SMTP (prod) / letter_opener_web (dev) |
| SMS | Brevo Transactional SMS (prod) / Rails logger (dev) |
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
bin/dev                                      # Start dev server
bundle exec rspec                            # Run Ruby tests
bundle exec rspec spec/system                # Run E2E browser tests (headless)
E2E=headed bundle exec rspec spec/system     # E2E with visible browser
bun test                                     # Run JS tests (Jest)
bin/rails console                            # Rails console
\`\`\`

### Linting & Formatting
\`\`\`bash
bundle exec rubocop          # Ruby linting
bun lint:js                  # Prettier + ESLint (check)
bun lint:js:fix              # Prettier + ESLint (auto-fix)
bun lint:css                 # CSS linting
yamllint config/locales/ app/frontend/locales/  # YAML linting
\`\`\`

### Key Paths
- Pages: `app/frontend/pages/`
- Components: `app/frontend/components/`
- Layouts: `app/frontend/layout/` (app, auth, marketing, settings, staff)
- Interactors: `app/interactors/`
- Configs: `app/configs/` (Anyway Config classes)
- Locales (Ruby): `config/locales/`
- Locales (React): `app/frontend/locales/`
- Validators (JS): `app/frontend/lib/validators.js`
- Styles: `app/frontend/entrypoints/application.css`
- E2E Tests: `spec/system/`

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
- **All frontend files use kebab-case.** Pages, components, hooks, utils — every `.js` and `.jsx` file. `dashboard.jsx`, `forgot-password.jsx`, `theme-provider.jsx`, `use-flash-toasts.js`. Never PascalCase or camelCase filenames.
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
- [ ] E2E tests pass: `bundle exec rspec spec/system` (no console errors)
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
- [ ] No secrets in code (use ENV via Anyway Config)
- [ ] Public endpoints have `allow_unauthenticated_access`
- [ ] Class methods use `class << self` block
- [ ] Bullet gem not flagging N+1 queries
- [ ] `bundle exec rubocop` passes
- [ ] `bun lint:js` passes
- [ ] `bun lint:css` passes
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

## .claude/CLAUDE.md Template

This file contains Claude-specific project rules that should be committed to the repo:

```markdown
## General

When a terminal command output is not accessible, use the `./tmp/commands-output/` in the current project instead of the root `/tmp`.

## Feature Development Workflow

When implementing a feature, follow this structure:

1. **Plan** — Break the feature into small, concrete implementation steps. Write them to `docs/ROADMAP.md` (or confirm they're already there). Mark items `[ ]` as you plan, `[x]` as you complete them.

2. **Implement** — Work through steps one at a time. Commit after each logical chunk. Keep `docs/ROADMAP.md` updated as you go.

3. **Test the feature** — Write tests for the new functionality. Run them and confirm they pass.

4. **Verify existing tests** — Run the full test suite (`bundle exec rspec` for Ruby, `bun test` for JS) to ensure nothing broke.

Only mark a feature complete when all four steps are done.
```

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

## Directory Structure Reference

### Frontend (`app/frontend/`)

```
app/frontend/
├── components/              # Reusable React components
│   ├── ui/                  # shadcn/ui components (auto-generated)
│   ├── icons/               # Wrapper components for lucide-react icons
│   │   ├── close.jsx        # export { X as CloseIcon } from 'lucide-react'
│   │   ├── loading.jsx      # With animation: cn("animate-spin", className)
│   │   └── ...
│   ├── data-table.jsx       # Reusable table with sort/filter/pagination
│   ├── theme-provider.jsx   # Dark mode provider
│   ├── theme-toggle.jsx     # Light/dark/system toggle
│   └── [domain]-*.jsx       # Domain-specific components
├── entrypoints/
│   └── application.css      # Tailwind imports + custom CSS
├── hooks/
│   ├── use-data-table.js    # Client-side table state management
│   └── use-*.js             # Custom React hooks
├── layout/
│   ├── app-layout.jsx       # Main app layout with sidebar
│   ├── auth-layout.jsx      # Login/signup page layout
│   ├── marketing-layout.jsx # Public pages layout
│   ├── settings-layout.jsx  # Settings pages with sub-nav
│   └── staff-layout.jsx     # Staff admin layout
├── lib/
│   ├── utils.js             # cn() and other utilities
│   ├── validators.js        # Zod validation schemas
│   ├── i18n.js              # i18n configuration
│   └── sentry.js            # Sentry initialization
├── locales/
│   ├── en.json              # English translations (frontend)
│   └── pl.json              # Polish translations (frontend)
└── pages/
    ├── app/                 # Authenticated app pages
    │   ├── dashboard.jsx
    │   └── settings/
    ├── auth/                # Authentication pages
    │   ├── login.jsx
    │   └── signup.jsx
    ├── staff/               # Staff admin pages
    └── home.jsx             # Landing page
```

### Backend (`app/`)

```
app/
├── configs/                 # Anyway Config classes
│   ├── stripe_config.rb
│   ├── sentry_config.rb
│   └── oauth_config.rb
├── controllers/
│   ├── concerns/
│   │   └── indexable.rb     # Standardized index params
│   ├── app/                 # Authenticated user controllers
│   └── staff/               # Staff admin controllers
├── interactors/
│   ├── users/               # User domain
│   │   ├── create_user.rb
│   │   ├── register.rb
│   │   └── validate_*.rb
│   ├── billing/             # Payment domain
│   └── [domain]/            # Other domains
├── jobs/
│   └── [name]_job.rb        # Call one interactor per job
├── mailers/
├── models/
│   └── concerns/
│       ├── sluggable.rb     # URL-friendly slugs
│       └── indexable.rb     # Search/filter/sort scopes
└── views/                   # Minimal (Inertia renders React)
```

### Database (`db/`)

```
db/
├── data/                    # Static YAML reference data
│   ├── countries/           # Country reference data
│   ├── languages/           # Language reference data
│   └── time_zones/          # Time zone reference data
├── dev_seeds/               # Development sample data (FFaker)
│   ├── 00_helpers.rb        # seed_record helper
│   ├── 01_users.rb
│   └── ...
├── seeds/                   # Production seeds (reference data)
│   └── reference_data.rb
├── migrate/
└── schema.rb
```

### Specs (`spec/`)

```
spec/
├── factories/               # One file per model
│   ├── users.rb
│   └── ...
├── interactors/             # Heavy coverage
│   └── users/
│       └── create_user_spec.rb
├── requests/                # Heavy coverage
│   ├── app/
│   └── staff/
├── models/                  # Medium coverage
├── jobs/
├── system/                  # E2E browser tests
│   ├── auth_spec.rb
│   ├── console_errors_spec.rb
│   ├── public_pages_spec.rb
│   └── staff/
├── support/
│   ├── capybara.rb          # Playwright configuration
│   ├── system_helpers.rb    # E2E helper methods
│   ├── factory_bot.rb
│   ├── shoulda_matchers.rb
│   ├── vcr.rb
│   ├── factories/           # One file per model
│   │   ├── users.rb
│   │   └── ...
│   ├── cassettes/           # VCR recordings (committed)
│   └── shared_examples/
│       ├── rendered_page.rb
│       └── requires_authentication.rb
├── rails_helper.rb
└── spec_helper.rb
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
| Brevo | Email + SMS | developers.brevo.com/docs |
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
> **Last updated:** [Date]

---

## Legend

- `[x]` = Complete and tested
- `[~]` = Partial (stub/basic implementation exists, needs enhancement)
- `[ ]` = Not started

Before starting ANY new feature:
1. Read this roadmap to understand current project status
2. Verify the feature aligns with the current phase priorities
3. Check dependencies — features may require earlier roadmap items

After completing ANY work:
1. Update this file to reflect completed items
2. Change `[ ]` to `[x]` for completed features
3. Change `[ ]` to `[~]` for partial implementations
4. Update the "Last updated" date

---

## Phase 1 — MVP (Current)

**Goal:** [One sentence goal — what does MVP deliver?]

**Target:** [Date or milestone]

### Core Infrastructure
- [ ] Rails app generation + PostgreSQL
- [ ] Authentication (email/password + Google OAuth)
- [ ] Email verification
- [ ] Solid Queue/Cache/Cable
- [ ] Inertia + React + Vite + Tailwind + shadcn/ui
- [ ] i18n (EN + [other languages])
- [ ] Stripe subscriptions via Pay gem
- [ ] Sentry error tracking
- [ ] Linting & formatting

### Domain Models
- [ ] [Core model 1]
- [ ] [Core model 2]
- [ ] [Core model 3]

### UI
- [ ] Landing page
- [ ] Auth pages (login, signup, forgot password)
- [ ] App dashboard
- [ ] Settings page
- [ ] Billing page

---

## Phase 2 — [Name]

**Goal:** [One sentence goal]

### Features
- [ ] Feature A
- [ ] Feature B
- [ ] Feature C

---

## Phase 3 — [Name]

**Goal:** [One sentence goal]

### Features
- [ ] Feature X
- [ ] Feature Y

---

## Backlog

Ideas for future consideration (not committed to any phase):

- Idea 1
- Idea 2
- Idea 3
```

---

## README.md Template

```markdown
# [App Name]

> [One-line description of what the app does and who it's for.]

Built with Rails, Inertia.js, React, Tailwind, and shadcn/ui. Deployed with Kamal on Hetzner.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Ruby | latest stable | `brew install ruby` or [rbenv](https://github.com/rbenv/rbenv) |
| PostgreSQL | latest stable | `brew install postgresql@16 && brew services start postgresql@16` |
| Bun | latest stable | `brew install oven-sh/bun/bun` |
| Stripe CLI | latest | `brew install stripe/stripe-cli/stripe` |
| Docker Desktop | latest | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) (for Kamal deploys) |
| Kamal | latest | `gem install kamal` |

---

## Getting Started

\`\`\`bash
git clone [repo-url]
cd [app-name]

# Install dependencies
bundle install
bun install

# Configure environment
cp .env.example .env
# Edit .env — see "Environment Variables" section below

# Set up databases (primary + queue + cache + cable)
bin/rails db:create
bin/rails db:prepare

# Seed reference data (plans, roles)
bin/rails db:seed

# (Optional) Populate dev data for manual exploration
bin/rails dev:seed

# Start the dev server
bin/dev
# → http://localhost:3000
# → Sign in as dev@example.com / password123 (created by dev:seed)
\`\`\`

---

## Development

### Testing

\`\`\`bash
bundle exec rspec                                        # All Ruby tests
bundle exec rspec spec/interactors/                      # All interactor specs
bundle exec rspec spec/interactors/create_user_spec.rb   # Single file
bundle exec rspec spec/interactors/create_user_spec.rb:42  # Single example

bun test                                                 # All JS tests (Jest)
bun run test:watch                                       # JS tests in watch mode
\`\`\`

### Code Quality

\`\`\`bash
bundle exec rubocop          # Ruby linting
bun lint:js                  # Prettier + ESLint (check)
bun lint:js:fix              # Prettier + ESLint (auto-fix)
bun lint:css                 # CSS linting (Stylelint)
bun lint:css:fix             # CSS auto-fix
yamllint config/locales/ app/frontend/locales/  # YAML linting
\`\`\`

### Dev Seed Data

Populate all models with realistic, diverse data so you can click around and see how the app works:

\`\`\`bash
bin/rails dev:seed
# Sign in as dev@example.com / password123 (staff super_admin)
\`\`\`

This creates records for every meaningful state and combination — free users, paid users, suspended users, comped users, contact requests, announcements, etc. See `db/dev_seeds/` for details.

> **Every new feature must ship with a corresponding dev seed file.** If you add a model or a new status/flag, add dev seed data for it.

### Useful Commands

\`\`\`bash
bin/rails console                     # Rails console
bin/rails routes                      # List all routes
bin/rails db:migrate                  # Run pending migrations
bin/rails db:rollback                 # Undo last migration
bin/rails db:seed                     # Seed reference data (idempotent)
bin/rails dev:seed                    # Seed development sample data (idempotent)
bin/rails comp:add[user@example.com]  # Gift a user paid access
bin/rails comp:remove[user@example.com] # Remove gifted access
bin/rails comp:list                   # List all comped users
\`\`\`

---

## Third-Party Services (Development)

How to get each service working locally. Skip rows for services the project doesn't use.

> **Note**: All external services are also tracked in the database via the `ExternalService` model with environment labels (development/production). See [staff-admin.md § External Services Registry](staff-admin.md#external-services-registry) for the seed data and staff dashboard integration.

| Service | What to do | Env var(s) |
|---------|-----------|------------|
| **[Stripe](https://dashboard.stripe.com/test/apikeys)** | Create test-mode API keys | `STRIPE_PUBLIC_KEY`, `STRIPE_SECRET_KEY` |
| **[Stripe CLI](https://docs.stripe.com/stripe-cli)** | Run `stripe listen --forward-to localhost:3000/webhooks/stripe` — copy the signing secret it prints | `STRIPE_WEBHOOK_SECRET` |
| **[Google Cloud Console](https://console.cloud.google.com/apis/credentials)** | Create OAuth 2.0 credentials. Authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback` | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` |
| **Email (Brevo)** | Not needed locally — uses [letter_opener_web](http://localhost:3000/letter_opener) to preview emails in the browser | — |
| **SMS (Brevo)** | Not needed locally — logs to Rails console | — |
| **[Sentry](https://sentry.io)** | Optional for dev — create a project if you want error tracking locally | `SENTRY_DSN` |

### Re-recording VCR Cassettes

Tests use pre-recorded HTTP responses (VCR cassettes) committed to git. **You don't need any API credentials for normal `bundle exec rspec` runs.** Credentials are only needed when re-recording cassettes after an API changes.

To re-record:

1. Set up the relevant service credentials in `.env` (see table below)
2. Delete the stale cassettes: `rm spec/support/cassettes/<service>/<cassette>.yml`
3. Run the affected specs: `bundle exec rspec spec/path/to/spec.rb`
4. Verify the new cassettes don't contain real secrets: `grep -r "sk_test_" spec/support/cassettes/` (should only show VCR placeholders)
5. Commit the updated cassettes

| Service | Env vars needed for re-recording | Where to get credentials |
|---------|----------------------------------|-------------------------|
| **Stripe** | `STRIPE_SECRET_KEY`, `STRIPE_PUBLIC_KEY` | [Dashboard → API keys](https://dashboard.stripe.com/test/apikeys) (use **test mode**) |
| **Google OAuth** | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` | [Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials) |
| **Brevo** | `BREVO_API_KEY` | [Brevo dashboard → SMTP & API](https://app.brevo.com) |
| **Sentry** | `SENTRY_DSN` | [Sentry → Project Settings → DSN](https://sentry.io) |
| **OpenAI** | `LLM_OPENAI_API_KEY` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| **Anthropic** | `LLM_ANTHROPIC_API_KEY` | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |

> **Add rows here** whenever you integrate a new external API. Every service that makes HTTP requests must be listed so future developers know how to re-record.

---

## Release

Deployment is fully automated via **GitHub Actions CI/CD**. There is no manual deploy step in normal workflow.

### How It Works

1. Push (or merge) to `main`
2. GitHub Actions runs the CI pipeline:
   - `bundle exec rspec` — all Ruby tests must pass
   - `bun test` — all JS tests must pass
   - `bundle exec rubocop` — Ruby linting
   - `bun lint:js` — Prettier + ESLint
   - `bun lint:css` — CSS linting
   - `yamllint` — YAML linting
3. If all checks pass → Kamal auto-deploys to production
4. Docker image is built, pushed to Docker Hub, and rolled out on the Hetzner server
5. Database migrations run automatically via the Docker entrypoint

### Manual Deploy (if needed)

\`\`\`bash
# First-ever deploy (bootstraps servers)
kamal setup

# Force a manual deploy (bypasses CI)
kamal deploy

# Push env var changes without redeploying
kamal env push

# View production logs
kamal app logs -f

# Production Rails console
kamal app exec -i "bin/rails console"
\`\`\`

### Secrets Management

All production secrets live in two places:

\`\`\`bash
# .kamal/secrets — local file, NEVER committed (Kamal reads from here)
vim .kamal/secrets

# GitHub repository secrets — for CI/CD auto-deploy
gh secret set SECRET_NAME
gh secret list
\`\`\`

Both must stay in sync. See the "Environment Variables" section below for the full list.

---

## Third-Party Services (Production)

| Service | What to do | Env var(s) |
|---------|-----------|------------|
| **[Stripe](https://dashboard.stripe.com/apikeys)** | Switch to **live-mode** API keys | `STRIPE_PUBLIC_KEY`, `STRIPE_SECRET_KEY` |
| **[Stripe Webhooks](https://dashboard.stripe.com/webhooks)** | Add endpoint: `https://[domain]/webhooks/stripe` | `STRIPE_WEBHOOK_SECRET` |
| **[Google Cloud Console](https://console.cloud.google.com/apis/credentials)** | Add production redirect URI: `https://[domain]/auth/google_oauth2/callback`. Set consent screen to Production. | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` |
| **[Brevo](https://app.brevo.com)** | Verify sending domain (DNS records), copy SMTP credentials + API key | `BREVO_SMTP_USERNAME`, `BREVO_SMTP_PASSWORD`, `BREVO_API_KEY` |
| **[Sentry](https://sentry.io)** | Create project, grab DSN | `SENTRY_DSN` |
| **[Docker Hub](https://hub.docker.com/settings/security)** | Create access token | `KAMAL_REGISTRY_PASSWORD` |
| **[Google Analytics](https://analytics.google.com)** | Create GA4 property, copy Measurement ID | `ANALYTICS_GA_MEASUREMENT_ID` |
| **[Google Search Console](https://search.google.com/search-console)** | Verify domain, submit sitemap | — |
| **[Ahrefs](https://ahrefs.com)** | Verify site, copy verification meta content | `ANALYTICS_AHREFS_VERIFICATION` |

> Add/remove rows based on the project's actual integrations.

---

## Environment Variables

All environment variables are documented in `.env.example`. Uses [Anyway Config](https://github.com/palkan/anyway_config) naming conventions:

| Variable | Required | Where to get it | Used for |
|----------|----------|----------------|----------|
| `APP_NAME` | yes | Set manually | Application name |
| `APP_URL` | yes | Set manually | Application URL |
| `DATABASE_URL` | prod only | Your PostgreSQL server | Primary database connection |
| `QUEUE_DATABASE_URL` | prod only | Your PostgreSQL server | Solid Queue database |
| `CACHE_DATABASE_URL` | prod only | Your PostgreSQL server | Solid Cache database |
| `CABLE_DATABASE_URL` | prod only | Your PostgreSQL server | Solid Cable database |
| `RAILS_MASTER_KEY` | prod only | `config/master.key` (auto-generated) | Decrypt credentials |
| `STRIPE_PUBLIC_KEY` | yes | Stripe Dashboard → API keys | Client-side Stripe.js |
| `STRIPE_SECRET_KEY` | yes | Stripe Dashboard → API keys | Server-side Stripe API |
| `STRIPE_WEBHOOK_SECRET` | yes | Stripe Dashboard → Webhooks (or Stripe CLI in dev) | Verify webhook signatures |
| `GOOGLE_OAUTH_CLIENT_ID` | if OAuth | Google Cloud Console → Credentials | Google sign-in |
| `GOOGLE_OAUTH_CLIENT_SECRET` | if OAuth | Google Cloud Console → Credentials | Google sign-in |
| `BREVO_SMTP_USERNAME` | prod only | Brevo dashboard → SMTP & API | Production email delivery |
| `BREVO_SMTP_PASSWORD` | prod only | Brevo dashboard → SMTP & API | Production email delivery |
| `BREVO_API_KEY` | prod only | Brevo dashboard → SMTP & API | SMS delivery |
| `BREVO_SMS_SENDER` | if SMS | Brevo dashboard | SMS sender name |
| `BREVO_FROM_ADDRESS` | prod only | Your domain | Email from address |
| `SENTRY_DSN` | recommended | Sentry → Project Settings | Error tracking |
| `ANALYTICS_GA_MEASUREMENT_ID` | optional | Google Analytics → Property Settings | Analytics |
| `ANALYTICS_AHREFS_VERIFICATION` | optional | Ahrefs → Site Verification | SEO verification |
| `KAMAL_REGISTRY_PASSWORD` | prod only | Docker Hub → Security → Access Tokens | Container registry auth |

> Update this table AND `.env.example` whenever you add a new env var.

---

## Staff Admin

Access the staff admin panel at `/staff`. You must have a `Staff` record associated with your user.

### Creating a Staff User

\`\`\`bash
# Development (already done by dev:seed)
bin/rails dev:seed
# → dev@example.com is a super_admin

# Production
kamal app exec -i "bin/rails console"
> user = User.find_by(email_address: "your@email.com")
> Staff.create!(user: user, role: "super_admin")
\`\`\`

### Available Features

- User management (search, suspend/unsuspend, comp access, reset password, force verify email)
- Contact request inbox
- Announcements / banners
- Payment history with CSV export
- GDPR data export
- User activity log
- Links to external dashboards (Stripe, Sentry, GA, Search Console)

---

## Background Jobs

Background jobs run via **Solid Queue** using a dedicated PostgreSQL database.

\`\`\`bash
# Jobs process automatically when running bin/dev
# Check job status in production:
kamal app exec "bin/rails runner 'puts SolidQueue::Job.where(finished_at: nil).count'"

# Monitor via staff admin → External Links → Solid Queue dashboard
\`\`\`

| Job | Purpose | Queue |
|-----|---------|-------|
| *[Add jobs as they are created]* | | `default` |

---

## Production Access

### Getting Access

To access production servers, you need:

1. **SSH key added to the web server** — ask an existing team member to add your public key to `~/.ssh/authorized_keys` on web-1
2. **Docker Hub access** — get added to the Docker Hub organization (for pulling images)
3. **Kamal secrets** — get a copy of `.kamal/secrets` from an existing team member (never committed to git)

### Common Commands

\`\`\`bash
# SSH into the web server
ssh root@<web-1-ip>

# Rails console (interactive)
kamal app exec -i "bin/rails console"

# Run a one-off command
kamal app exec "bin/rails runner 'puts User.count'"

# View live logs
kamal app logs -f

# View recent logs (last 100 lines)
kamal app logs -n 100

# Run migrations manually (usually automatic on deploy)
kamal app exec "bin/rails db:migrate"

# Check app status
kamal app details

# Restart the app (without redeploying)
kamal app boot

# Check which version is deployed
kamal app version
\`\`\`

### Database Access

\`\`\`bash
# SSH into the database server
ssh root@<db-1-ip>

# Connect to PostgreSQL directly
sudo -u postgres psql myapp_production

# Export reference data from production (e.g., after staff edits plans)
kamal app exec "bin/rails reference_data:export[Plan]"
kamal app exec "cat db/reference_data/plans.yml"
\`\`\`

### Debugging in Production

\`\`\`bash
# Check Sentry for errors (link in staff admin → External Links)

# Tail logs for a specific request
kamal app logs -f | grep "request-id-here"

# Check background job status
kamal app exec "bin/rails runner 'puts SolidQueue::Job.where(finished_at: nil).count'"

# Retry failed jobs
kamal app exec -i "bin/rails console"
# > SolidQueue::Job.where.not(failed_at: nil).find_each(&:retry)
\`\`\`

---

## Troubleshooting

### PostgreSQL won't start

\`\`\`bash
brew services restart postgresql@16
# Check logs:
tail -f /opt/homebrew/var/log/postgresql@16.log
\`\`\`

### Bun lockfile conflicts

\`\`\`bash
rm bun.lockb
bun install
\`\`\`

### Solid Queue jobs stuck

\`\`\`bash
# In Rails console:
SolidQueue::Job.where(finished_at: nil).find_each(&:discard)
\`\`\`

### Stripe webhooks not arriving locally

Make sure Stripe CLI is running in a separate terminal:

\`\`\`bash
stripe listen --forward-to localhost:3000/webhooks/stripe
\`\`\`

### letter_opener_web not showing emails

Visit [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener). If blank, check that `config.action_mailer.delivery_method = :letter_opener_web` is set in `config/environments/development.rb`.

---

## Documentation

Detailed technical documentation lives in `docs/`:

| Doc | Purpose |
|-----|---------|
| [DESIGN.md](docs/DESIGN.md) | Brand identity, colors, typography, component styles |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical decisions, data model, key flows |
| [BUSINESS_RULES.md](docs/BUSINESS_RULES.md) | Domain logic, permissions, edge cases |
| [SCHEMA.md](docs/SCHEMA.md) | Every table, column, relationship, and index |
| [CODE_QUALITY.md](docs/CODE_QUALITY.md) | Mandatory code quality rules |
| [TESTING.md](docs/TESTING.md) | Testing principles and conventions |
| [PROJECT_SETUP.md](docs/PROJECT_SETUP.md) | Extended setup notes |
| [ROADMAP.md](docs/ROADMAP.md) | Feature priorities and backlog |

---

## Keeping This README Up to Date

When any of these change, update the relevant section:

- **New third-party service** → add a row to the dev and/or prod services table
- **New env var** → add to the Environment Variables table AND `.env.example`
- **New model/feature** → add dev seed data, update Staff Admin features if applicable
- **New background job** → add to the Background Jobs table
- **Infrastructure change** → update the Release section
- **New troubleshooting issue** → add to Troubleshooting

---

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
13. [ ] Create `.claude/CLAUDE.md` (from playbook template — contains Feature Development Workflow)
14. [ ] Copy `.claude/hooks/post-commit-audit.sh` from playbook, customize design system checks
15. [ ] Register hook in `.claude/settings.json` (see `~/.claude/rails-playbook/hooks/README.md`)
16. [ ] Create `.rubocop.yml` (from [code-quality.md](code-quality.md#rubocop) base template)
17. [ ] Create `.rubocop_todo.yml` (empty file — generate later with `--auto-gen-config`)
18. [ ] Create `eslint.config.mjs` (from [inertia-react.md](inertia-react.md#eslint--prettier))
19. [ ] Create `.prettierrc` (from [inertia-react.md](inertia-react.md#eslint--prettier))
20. [ ] Create `.prettierignore` (from [inertia-react.md](inertia-react.md#eslint--prettier))
21. [ ] Create `.stylelintrc.json` (from [inertia-react.md](inertia-react.md#stylelint))
22. [ ] Create `.yamllint.yml` (from [code-quality.md](code-quality.md#yamllint))
23. [ ] Create `jsconfig.json` (from [inertia-react.md](inertia-react.md#path-alias----appfrontend) — `@` alias)
24. [ ] Add lint/format scripts to `package.json`
25. [ ] Verify all linters pass on fresh project (`rubocop`, `bun lint:js`, `bun lint:css`, `yamllint`)
26. [ ] Add all docs to .gitignore exclusion (should be committed)
