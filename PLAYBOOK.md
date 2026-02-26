# Rails Playbook

> How I like my Rails apps set up. Reference this when creating new projects.

---

## Non-Negotiables

1. **Interview me first** - Ask about the project, brand, and requirements before writing code
2. **Create project docs** - Set up `docs/` folder with DESIGN.md, CODE_QUALITY.md, TESTING.md, etc.
3. **Keep CLAUDE.md clean** - Brief index that links to detailed docs
4. **Use .env files** - All secrets via `ENV["X"]`, never hardcode
5. **Stripe CLI only** - Create products/prices via CLI, not dashboard
6. **Single database** - Solid Queue/Cache/Cable all use primary DB
7. **Small tasks** - Prefer 30-90 minute chunks, suggest splits if scope creeps

---

## Stack

| Layer | Technology |
|-------|------------|
| **Server** | Rails + PostgreSQL |
| **Auth** | Rails sessions + Google OAuth (optional) |
| **Frontend** | Inertia.js + React + Vite |
| **Styling** | Tailwind + shadcn/ui |
| **Payments** | Stripe via Pay gem |
| **Jobs** | Solid Queue (single DB) |
| **Cache** | Solid Cache (single DB) |
| **WebSockets** | Solid Cable (single DB) |
| **Email** | Resend (prod) / letter_opener_web (dev) |
| **Testing (Ruby)** | RSpec + FactoryBot + FFaker + Shoulda Matchers |
| **Testing (JS)** | Jest (logic only, no React) |
| **CSS Linting** | Stylelint |
| **JS Linting** | ESLint |
| **Formatting** | Prettier (JS/TS/CSS/YAML) |
| **YAML Linting** | yamllint |
| **Package Manager (JS)** | Bun |
| **Business Logic** | Interactor gem (small, composable steps) |
| **Params Validation** | Explicit validation in interactors (not model validations) |
| **Error Tracking** | Sentry |
| **Search** | pg_search (PostgreSQL full-text) |
| **i18n** | Rails I18n + react-i18next |
| **CI/CD** | GitHub Actions (auto-deploy on push to main) |
| **Hosting** | Kamal on Hetzner Cloud |

---

## When Creating a New App

### Step 1: Interview Me

Before writing any code, ask me about:

**Project basics:**
- What does this app do? (one sentence)
- Who is the target user?
- What's the MVP scope?

**Domain model:**
- What are the core entities? How do they relate?
- Who are the user types? What can each one do?
- What are the key business rules and constraints?
- What are the important edge cases?
- Do users belong to an organization/team/workspace? (multitenancy — see below)

**Brand identity:** (see [brand-interview.md](brand-interview.md))
- Colors, typography, component style
- Tone of voice
- Reference sites I like

**Technical requirements:**
- Need Google OAuth?
- Need Stripe payments? If yes, what pricing model? (see below)
- Will this also be a mobile app? (iOS / Android via Capacitor — see below)
- Any specific integrations?

**Pricing model** (if payments needed):
- What type? Subscriptions, one-time payments, metered/usage-based, or a mix?
- How many tiers/products?
- Free tier or trial period?
- Per-seat pricing or flat rate?
- Any credits/token system?

**Multitenancy** (if users belong to an org/team/workspace):
- Can a user belong to multiple accounts?
- Who creates accounts? Who invites members?
- Are roles per-account (admin in one, member in another)?
- Is data strictly scoped to the account? (e.g., projects, billing, settings)
- Is billing per-account or per-user?

If multitenancy is needed, use the **Account + UserAccount** pattern by default:
- `accounts` table — the tenant (org/team/workspace)
- `user_accounts` table — join table with `user_id`, `account_id`, `role`
- `Current.account` set from subdomain, path prefix, or session
- All tenant-scoped queries go through `Current.account` — never leak data across accounts
- Unless told otherwise, name the tenant model `Account` and the join model `UserAccount`

**Mobile app** (if shipping to App Store / Play Store):
- iOS only, Android only, or both?
- What's the app name and bundle ID?
- Any native features needed? (push notifications, camera, biometrics, etc.)
- App Store / Play Store listing details?

If the app needs mobile distribution, wrap the web app with **Capacitor**:
- Same React codebase, packaged as a native shell
- Configure `capacitor.config.ts` with the app name, bundle ID, and server URL
- Add platform-specific env vars (see [env-template.md](env-template.md))
- Use Capacitor plugins for native features (push, haptics, status bar, etc.)

### Step 2: Create Project Structure

After the interview, generate:

```
my-app/
├── CLAUDE.md                    # Brief index (see project-structure.md)
├── README.md                    # Dev + prod setup, third-party services, env vars
├── .env.example                 # Required ENV vars
├── .claude/
│   └── hooks/
│       └── post-commit-audit.sh # Quality enforcement (from playbook)
└── docs/
    ├── SCHEMA.md                # Every table, column, relationship, index
    ├── BUSINESS_RULES.md        # Domain logic, permissions, edge cases
    ├── DESIGN.md                # Brand identity from interview
    ├── ARCHITECTURE.md          # Technical decisions
    ├── CODE_QUALITY.md          # Code quality rules (from playbook)
    ├── TESTING.md               # Testing principles (from playbook)
    ├── PROJECT_SETUP.md         # Local dev, testing, deploy
    └── ROADMAP.md               # Feature priorities
```

### Step 3: Generate Rails App

Use my template or set up manually following these docs:
- [auth.md](auth.md) - Rails authentication + OmniAuth
- [solid-stack.md](solid-stack.md) - Database + Solid* config
- [stripe-payments.md](stripe-payments.md) - Payments setup
- [inertia-react.md](inertia-react.md) - Frontend setup
- [kamal-deploy.md](kamal-deploy.md) - Deployment config
- [env-template.md](env-template.md) - Environment variables

### Step 4: Add Common Features

After the core app is running, add these as needed:
- [settings-page.md](settings-page.md) - User settings (profile, billing, notifications)
- [email-verification.md](email-verification.md) - Password reset + email verification
- [contact-page.md](contact-page.md) - Contact form with DB storage + staff view
- [legal-pages.md](legal-pages.md) - Privacy Policy + Terms of Service
- [analytics-seo.md](analytics-seo.md) - GA4, Search Console, meta tags, sitemap
- [logo-generation.md](logo-generation.md) - Generate logo + favicons via AI
- [staff-admin.md](staff-admin.md) - Staff panel with admin operations

---

## Conventions

### Rails

- Controllers thin; business logic in interactors (`app/interactors/`)
- **Interactors, not services.** Use the [Interactor](https://github.com/collectiveidea/interactor) gem. Each interactor does one small thing. Use `Interactor::Organizer` to compose multi-step flows. See [interactors.md](interactors.md).
- **Validate params in interactors**, not in models. Models only have DB-level constraints (`NOT NULL`, unique indexes). Business validation happens in a dedicated `Validate*` interactor step.
- **Validate on frontend first.** Before submitting to the backend, validate the form client-side. Show errors immediately without a round-trip. See [inertia-react.md](inertia-react.md#frontend-validation).
- **LLM integration:** Use `ruby_llm` gem (unified interface for OpenAI, Anthropic, Gemini, OpenRouter). Only use `ruby-openai` if explicitly requested.
- Strong params only; never `.permit!`
- Jobs idempotent; use Solid Queue
- Public actions explicit: `allow_unauthenticated_access`
- Use `ENV["X"]` for all configuration
- **i18n everywhere.** No hardcoded English strings. Use `I18n.t()` in Ruby, `useTranslation()` in React. See [i18n.md](i18n.md).
- **Sentry for errors.** Configure `sentry-ruby` and `sentry-rails` gems. See [sentry.md](sentry.md).
- **Bullet gem** in development and test. Raises in test, logs in development. See [code-quality.md](code-quality.md#bullet).
- **Class methods use `class << self`**, not `self.method_name`. Always keep class methods at the top of the class, before instance methods.

### Git

- **Conventional Commits.** All commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.
- Format: `type(scope): description` — e.g. `feat(auth): add Google OAuth login`, `fix(billing): handle expired cards`, `refactor(interactors): extract validation step`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`
- Scope is optional but encouraged — use the feature area: `auth`, `billing`, `teams`, `staff`, etc.
- Breaking changes: add `!` after type — `feat(api)!: change response format`
- Keep the subject line under 72 characters. Add a body for context when the "why" isn't obvious.

### Inertia + React

- Pages in `app/frontend/pages/`
- Components in `app/frontend/components/`
- Internal links use `<Link href="..." />` (Inertia)
- **Never hardcode routes** - use shared routes from `usePage().props.routes`
- Prefer shadcn/ui components — **install the full component set upfront**, make all components i18n-ready
- **Icons use wrapper components** in `components/icons/`. Import `IconClose` from `@/components/icons/close`, never directly from `lucide-react`.
- **Validate forms client-side before submitting.** Use Zod schemas to validate, show inline errors instantly. Only send the request once the form is locally valid.
- **i18n for all user-facing text.** Use `react-i18next` with `useTranslation()`. No hardcoded English strings in JSX — including shadcn/ui component text (placeholders, empty states, aria labels).

### Frontend Design

When building pages, components, or layouts, use the `/frontend-design` skill to generate distinctive, production-grade UI. This avoids generic AI aesthetics and produces polished code using the project's design system (Tailwind + shadcn/ui).

**Before building a custom component**, check [shadcn/ui Blocks](https://www.shadcn.io/blocks/) for a ready-made solution. Use it as-is or adapt it. Only build from scratch if nothing fits.

Use it for:
- New pages (landing, dashboard, settings, etc.)
- Complex components (data tables, forms, navigation)
- Layout shells (app layout, marketing layout)
- Any UI that should look polished and distinctive

### Responsive Design

- **Mobile first, always.** Write base styles for mobile (320px minimum), then layer on tablet and desktop with responsive breakpoints.
- **Minimum supported width: 320px.** Every page and component must look correct and be fully usable at 320px wide. No horizontal scrolling, no clipped content.
- **Tablet breakpoint matters.** Don't jump from mobile straight to desktop. Explicitly handle the `md` (768px) breakpoint — adjust grid columns, spacing, sidebar behavior, and form layouts for tablet-sized screens.
- **Breakpoint progression:** base (320px+) → `sm` (640px+) → `md` (768px+) → `lg` (1024px+) → `xl` (1280px+)

### Tailwind

- Theme tokens via CSS variables in `:root` / `.dark` blocks (application.css)
- `@theme` block maps CSS variables to Tailwind utilities
- **Always support light + dark + system themes.** System is the default.
- Use token utilities: `bg-background`, `text-foreground`, `border-border`
- Layout: `.container` for width, `.section-py` for vertical rhythm

---

## Key Docs

| Doc | Purpose |
|-----|---------|
| [auth.md](auth.md) | Rails auth generator + OmniAuth patterns |
| [brand-interview.md](brand-interview.md) | Questions to ask about design/identity |
| [solid-stack.md](solid-stack.md) | Single-database Solid Queue/Cache/Cable |
| [stripe-payments.md](stripe-payments.md) | Stripe CLI workflow + Pay gem |
| [inertia-react.md](inertia-react.md) | Vite + React + shadcn + inertia_share + frontend philosophy |
| [kamal-deploy.md](kamal-deploy.md) | Deployment, GitHub Actions CI/CD, secrets management |
| [env-template.md](env-template.md) | Required environment variables |
| [project-structure.md](project-structure.md) | Templates for project docs |
| [code-quality.md](code-quality.md) | General code quality rules (copy to project docs/) |
| [testing-guidelines.md](testing-guidelines.md) | General testing principles (copy to project docs/) |
| [hooks/](hooks/) | Post-commit quality hooks (copy to project .claude/hooks/) |
| [settings-page.md](settings-page.md) | User settings with profile, billing, notifications |
| [contact-page.md](contact-page.md) | Contact form: DB storage, staff panel view, spam prevention |
| [legal-pages.md](legal-pages.md) | Privacy Policy & Terms of Service templates |
| [logo-generation.md](logo-generation.md) | Logo + favicon generation via AI tools |
| [analytics-seo.md](analytics-seo.md) | GA4, Search Console, meta tags, sitemap |
| [email-verification.md](email-verification.md) | Password reset + email verification flows |
| [interactors.md](interactors.md) | Interactor gem patterns, organizers, validation |
| [i18n.md](i18n.md) | Rails I18n + react-i18next setup and conventions |
| [sentry.md](sentry.md) | Sentry error tracking setup (Ruby + JS) |
| [staff-admin.md](staff-admin.md) | Staff/admin panel: table, rake task, frontend scaffold |
| [search.md](search.md) | pg_search: full-text search with tsvector + GIN indexes |

---

## Testing

See [testing-guidelines.md](testing-guidelines.md) for full principles. Quick reference:

- **Ruby:** `bundle exec rspec` — RSpec + FactoryBot + FFaker + Shoulda Matchers
- **JavaScript:** `bun test` — Jest for utility functions, validators, hooks (no React component tests)
- **CSS:** `bun stylelint "app/frontend/**/*.css"` — Stylelint for all CSS files
- **E2E:** Capybara + Playwright for full user flows (this is where React gets tested)
- Add meaningful assertions (not just status codes)
- Happy path + edge case for each feature
- Stub external services (Stripe, APIs)
- Test at the lowest possible layer

---

## Review Checklist

Before completing any task:

- [ ] Tests added/updated, `bundle exec rspec` passes
- [ ] No hardcoded English — i18n keys used (both frontend and backend)
- [ ] Frontend form validation present (Zod schema)
- [ ] Backend params validated in interactor (not model)
- [ ] Inertia `<Link/>` for internal navigation
- [ ] shadcn/ui for controls & cards (checked [Blocks](https://www.shadcn.io/blocks/) first)
- [ ] Icons imported from `@/components/icons/` wrappers (not directly from lucide-react)
- [ ] shadcn/ui component text is i18n-ready (no hardcoded English in components)
- [ ] Mobile-first, works at 320px, tablet handled at `md` breakpoint
- [ ] Tailwind tokens (not hardcoded colors)
- [ ] No secrets in code (use ENV)
- [ ] Public endpoints have `allow_unauthenticated_access`
- [ ] Class methods use `class << self` block (not `self.method_name`)
- [ ] Bullet gem not flagging N+1 queries
- [ ] Stylelint passes on CSS files
- [ ] ESLint passes on JS/TS files
- [ ] Prettier formatting applied (`bun format:check`)
- [ ] yamllint passes on locale YAML files
- [ ] Commit messages follow Conventional Commits (`type(scope): description`)
