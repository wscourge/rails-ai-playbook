# Rails Playbook

> How I like my Rails apps set up. Reference this when working on existing projects.

**Starting a new project from scratch?** See [_PLAYBOOK_NEW_PROJECT.md](_PLAYBOOK_NEW_PROJECT.md) first.

**Upgrading an older project to the latest playbook?** See [UPGRADE_EXISTING_PROJECT.md](UPGRADE_EXISTING_PROJECT.md).

---

## Non-Negotiables

1. **Interview me first** - Ask about the project, brand, and requirements before writing code (new projects only)
2. **Create project docs** - Set up `docs/` folder with DESIGN.md, CODE_QUALITY.md, TESTING.md, etc.
3. **Keep CLAUDE.md clean** - Brief index that links to detailed docs
4. **Keep docs/ROADMAP.md current** - Mark items complete as you finish them, add new items as they emerge. This is the source of truth for project progress.
5. **Use .env files** - All secrets via `ENV["X"]`, never hardcode
6. **Stripe CLI only** - Create products/prices via CLI, not dashboard
7. **Use `./tmp/commands-output/` for scratch files** - When redirecting command output to a file (e.g. because the terminal doesn't show it), always write to the project's `./tmp/commands-output/` directory, never to `/tmp`
8. **Small tasks** - Prefer 30-90 minute chunks, suggest splits if scope creeps

---

## Stack

| Layer | Technology |
|-------|------------|
| **Server** | Rails + PostgreSQL |
| **Auth** | Rails sessions + Google OAuth (optional) |
| **Frontend** | Inertia.js + React + Vite |
| **Styling** | Tailwind + shadcn/ui |
| **Payments** | Stripe via Pay gem |
| **Jobs** | Solid Queue (separate DB) |
| **Cache** | Solid Cache (separate DB) |
| **WebSockets** | Solid Cable (separate DB) |
| **Email** | Brevo (prod) / letter_opener_web (dev) |
| **SMS** | Brevo Transactional SMS (prod) / Rails logger (dev) |
| **Testing (Ruby)** | RSpec + FactoryBot + FFaker + Shoulda Matchers + VCR + WebMock |
| **Testing (JS)** | Jest (logic only, no React) |
| **CSS Linting** | Stylelint |
| **JS Linting** | ESLint |
| **Formatting** | Prettier (JS/CSS/YAML) |
| **YAML Linting** | yamllint |
| **Ruby Linting** | RuboCop + extensions (rails, rspec, performance, capybara, factory_bot) |
| **Migrations** | strong_migrations gem (safe migration checks) |
| **Package Manager (JS)** | Bun |
| **Business Logic** | Interactor gem (small, composable steps) |
| **Params Validation** | Explicit validation in interactors (not model validations) |
| **Configuration** | Anyway Config (backend) + Zod schema (frontend) |
| **Error Tracking** | Sentry |
| **Search** | pg_search (PostgreSQL full-text) |
| **i18n** | Rails I18n + react-i18next |
| **CI/CD** | GitHub Actions (auto-deploy on push to main) |
| **Hosting** | Kamal on Hetzner Cloud |

---

## When Creating a New App

### Step 1: Interview Me

Before writing any code, ask me the questions below. **Ask one topic at a time** — don't bundle multiple topics into a single message. Wait for my answer before moving to the next topic.

**Project basics:**
- What's the app name? (if undecided, we'll use `myapp` as a placeholder everywhere — directory name, database names, `APP_NAME` env var — and you can find-and-replace it later)
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
- Need Stripe payments? If yes, what pricing model? (subscriptions, one-time payments, metered/usage-based, or a mix — see below)
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

### Git Workflow During Setup

1. **Initialize the repo first** — run `git init` and set the default branch to `main` before creating any files
2. **Commit after each step** — when you finish a step, commit all changes before moving to the next one
3. Follow the [Conventional Commits](#git) format for all commit messages (e.g. `chore: scaffold project structure`, `feat(auth): add Rails authentication`)

### Step 2: Create Project Structure

After the interview, initialize the repo and generate the project structure. Use the app name from the interview, or `myapp` if undecided:

```bash
mkdir myapp && cd myapp
git init
git branch -M main
```

Then create:

```
myapp/
├── CLAUDE.md                    # Brief index (see project-structure.md)
├── README.md                    # Dev + prod setup, third-party services, env vars
├── .env.example                 # Required ENV vars
├── .rubocop.yml                 # RuboCop config (from playbook)
├── .rubocop_todo.yml            # Auto-generated exclusions (ok to start empty)
├── .yamllint.yml                # YAML linting rules
├── .prettierrc                  # Prettier formatting rules
├── .prettierignore              # Files Prettier should skip
├── .stylelintrc.json            # Stylelint CSS rules
├── eslint.config.mjs            # ESLint config
├── jsconfig.json                # @ alias for IDE support (no TypeScript)
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

### Step 3.1: Set Up Local PostgreSQL

Ensure PostgreSQL is running locally on the default connection (`localhost:5432`), then create the app's databases automatically. The app name comes from `APP_NAME` in `.env` (defaults to `myapp`).

```bash
# Ensure Postgres is running (macOS / Homebrew)
brew services start postgresql@17

# Create development + test databases (primary + Solid stack)
bin/rails db:create
bin/rails db:prepare
```

This creates all 8 databases using the default local connection (no password, current OS user):
- `{app}_development`, `{app}_test` (primary)
- `{app}_queue_development`, `{app}_queue_test` (Solid Queue)
- `{app}_cache_development`, `{app}_cache_test` (Solid Cache)
- `{app}_cable_development`, `{app}_cable_test` (Solid Cable)

**If `db:create` fails** because your local Postgres requires a password or different user, add these to your `.env`:

```
DATABASE_USER=your_pg_user
DATABASE_PASSWORD=your_pg_password
```

And update `database.yml`'s default block:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch("DATABASE_USER", "") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "") %>
  host: localhost
  port: 5432
```

### Step 3.5: Configure Linting & Formatting

After `rails new` and frontend setup, create these config files from the playbook templates. They must exist before writing any application code so all code is clean from the start.

| File | Source | Purpose |
|------|--------|---------|
| `.rubocop.yml` | [code-quality.md](code-quality.md#rubocop) | Ruby linting base config |
| `.rubocop_todo.yml` | `touch .rubocop_todo.yml` | Empty initially, generated later with `--auto-gen-config` |
| `eslint.config.mjs` | [inertia-react.md](inertia-react.md#eslint--prettier) | JS/JSX linting with import sorting + unused import removal |
| `.prettierrc` | [inertia-react.md](inertia-react.md#eslint--prettier) | Formatting rules (single quotes, trailing commas, 80 width) |
| `.prettierignore` | [inertia-react.md](inertia-react.md#eslint--prettier) | Skip node_modules, public, vendor, tmp |
| `.stylelintrc.json` | [inertia-react.md](inertia-react.md#stylelint) | CSS linting with Tailwind-aware rules |
| `.yamllint.yml` | [code-quality.md](code-quality.md#yamllint) | YAML linting for locale files |
| `jsconfig.json` | [inertia-react.md](inertia-react.md#path-alias----appfrontend) | `@` → `app/frontend/` alias for IDE support |

Also add these scripts to `package.json`:

```json
{
  "scripts": {
    "lint:js": "prettier --check 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml' && eslint app/frontend/",
    "lint:js:fix": "prettier --write 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml' && eslint app/frontend/ --fix",
    "lint:css": "stylelint \"app/frontend/**/*.css\"",
    "lint:css:fix": "stylelint \"app/frontend/**/*.css\" --fix"
  }
}
```

Verify everything works:

```bash
bundle exec rubocop          # Ruby — should pass with zero offenses
bun lint:js                  # Prettier + ESLint — should pass
bun lint:css                 # CSS — should pass
yamllint config/locales/     # YAML — should pass
```

### Step 4: Add Common Features

After the core app is running, add these as needed:
- [settings-page.md](settings-page.md) - User settings (profile, billing, notifications)
- [email-verification.md](email-verification.md) - Password reset + email verification
- [contact-page.md](contact-page.md) - Contact form with DB storage + staff view
- [legal-pages.md](legal-pages.md) - Privacy Policy + Terms of Service
- [analytics-seo.md](analytics-seo.md) - GA4, Search Console, meta tags, sitemap
- [logo-generation.md](logo-generation.md) - Generate logo + favicons via AI
- [staff-admin.md](staff-admin.md) - Staff panel with admin operations

### Step 4.5: Development Seed Data

After features are built, create a **development seed data** rake task so you can run the app locally and click around with realistic, varied data. This is separate from production seeds (`db:seed`) — it uses FFaker and creates many records covering all data combinations.

```bash
bin/rails dev:seed
```

See [code-quality.md](code-quality.md#development-seed-data) for the full structure and conventions.

**Key rules:**
- Separate from production seeds — lives in `lib/tasks/dev_seeds.rake` loading files from `db/dev_seeds/`
- Uses FFaker for realistic data
- Creates diverse combinations: every user type, every plan, every status, edge cases (suspended users, comped users, expired subscriptions, etc.)
- **Truly idempotent** — uses `find_or_initialize_by` + `assign_attributes` + `save!` (via a `seed_record` helper), so you can change any value and re-run the whole task to apply it. No duplicates, no stale data.
- **Must be kept up to date.** When you add a new model or feature, add a corresponding dev seed file in the same task

### Step 5: Deploy & Go Live

When the app is ready for production, follow this checklist **in order**. Each sub-step links to the detailed doc. Skip items marked *(if applicable)* when the feature isn't used.

#### 5.1 — Infrastructure (Hetzner + Docker)

- [ ] Create Hetzner Cloud account → new project → add SSH key ([kamal-deploy.md](kamal-deploy.md#provision-hetzner-servers))
- [ ] Provision **web-1** server (CX22, Ubuntu LTS)
- [ ] Provision **db-1** server (CX22, Ubuntu LTS)
- [ ] Create a **Private Network** in Hetzner → attach both servers
- [ ] Configure **Firewall** rules: SSH (22), HTTP (80), HTTPS (443), Postgres (5432 private only) ([kamal-deploy.md](kamal-deploy.md#hetzner-firewall-rules))
- [ ] SSH into **db-1** → install PostgreSQL → create databases + user ([kamal-deploy.md](kamal-deploy.md#postgresql-on-db-1))
- [ ] Configure PostgreSQL to listen on private network IP (`postgresql.conf` + `pg_hba.conf`)
- [ ] Set up automated daily DB backups on db-1 ([kamal-deploy.md](kamal-deploy.md#database-backups))
- [ ] Create [Docker Hub](https://hub.docker.com/settings/security) account → generate access token

#### 5.2 — Domain & DNS

- [ ] Register domain (or use existing one)
- [ ] Point **A record** for `yourdomain.com` → web-1 public IP
- [ ] Point **A record** for `www.yourdomain.com` → web-1 public IP
- [ ] (Optional) Set up Hetzner rDNS for the web-1 IP to match your domain

#### 5.3 — Stripe *(if applicable)*

- [ ] Log into [Stripe Dashboard](https://dashboard.stripe.com) → switch to **live mode**
- [ ] Copy live-mode **Publishable key** (`pk_live_XXX`) and **Secret key** (`sk_live_XXX`)
- [ ] Create products and prices via Stripe CLI in live mode:
  ```bash
  stripe products create --name="Pro" --description="Pro plan" --live
  stripe prices create --product=prod_XXX --unit-amount=2000 --currency=usd --recurring[interval]=month --live
  ```
- [ ] Add webhook endpoint in [Stripe Dashboard → Webhooks](https://dashboard.stripe.com/webhooks):
  - URL: `https://yourdomain.com/webhooks/stripe`
  - Events: `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
- [ ] Copy the **Webhook Signing Secret** (`whsec_XXX`)
- [ ] Update `PlansService` with live price IDs
- [ ] Verify Stripe Tax settings (if collecting tax)

#### 5.4 — Google OAuth *(if applicable)*

- [ ] Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
- [ ] Open your OAuth 2.0 client (or create one for production)
- [ ] Add **Authorized redirect URI**: `https://yourdomain.com/auth/google_oauth2/callback`
- [ ] Copy **Client ID** and **Client Secret**
- [ ] Set OAuth consent screen to **Production** (submit for verification if needed)

#### 5.5 — Email & SMS (Brevo)

- [ ] Log into [Brevo](https://app.brevo.com)
- [ ] Add and **verify your sending domain** (add DNS records: DKIM, SPF, DMARC) ([brevo.md](brevo.md#email-setup))
- [ ] Copy **SMTP credentials** from Brevo dashboard
- [ ] Set `BREVO_SMTP_USERNAME`, `BREVO_SMTP_PASSWORD`, and `BREVO_FROM_ADDRESS`
- [ ] Send a test email to confirm delivery
- [ ] *(if SMS)* Register **sender name** (or phone number for US/Canada)
- [ ] *(if SMS)* Copy **API key** (v3) → set `BREVO_API_KEY` and `BREVO_SMS_SENDER`
- [ ] *(if SMS)* Send a test SMS to confirm delivery

#### 5.6 — Error Tracking (Sentry)

- [ ] Log into [Sentry](https://sentry.io) → create a new **Rails project**
- [ ] Copy the **DSN** (`https://xxx@xxx.ingest.sentry.io/xxx`)
- [ ] Verify the Sentry initializer is configured ([sentry.md](sentry.md))
- [ ] (Optional) Set up Sentry alerts (e.g. Slack/email on new error)

#### 5.7 — Analytics & SEO *(if applicable)*

- [ ] **Google Analytics 4:** Create property at [analytics.google.com](https://analytics.google.com) → copy Measurement ID (`G-XXXXXXXXXX`) ([analytics-seo.md](analytics-seo.md#google-analytics-4))
- [ ] **Google Search Console:** Verify domain at [search.google.com/search-console](https://search.google.com/search-console) → submit sitemap URL (`https://yourdomain.com/sitemap.xml`) ([analytics-seo.md](analytics-seo.md#google-search-console))
- [ ] **Ahrefs:** Add site → copy verification meta tag content ([analytics-seo.md](analytics-seo.md#ahrefs-verification))
- [ ] Verify `robots.txt` is in `public/` and allows crawling
- [ ] Generate sitemap: `rails sitemap:refresh`
- [ ] Verify OG image exists (`public/og-image.jpg`, 1200×630)
- [ ] Test social sharing previews ([opengraph.xyz](https://www.opengraph.xyz/) or Twitter Card Validator)

#### 5.8 — Legal Pages *(if applicable)*

- [ ] Review and finalize Privacy Policy content ([legal-pages.md](legal-pages.md))
- [ ] Review and finalize Terms of Service content
- [ ] Ensure pages are accessible from footer on all public pages
- [ ] Verify correct company name, jurisdiction, and data practices

#### 5.9 — Secrets & Configuration

Collect all values from steps above and set them in both places:

**`.kamal/secrets`** (local file, never committed):
```
KAMAL_REGISTRY_PASSWORD=dckr_pat_XXX
RAILS_MASTER_KEY=<from config/master.key>
DATABASE_URL=postgres://myapp:PASSWORD@<db-1-private-ip>:5432/myapp_production
QUEUE_DATABASE_URL=postgres://myapp:PASSWORD@<db-1-private-ip>:5432/myapp_queue_production
CACHE_DATABASE_URL=postgres://myapp:PASSWORD@<db-1-private-ip>:5432/myapp_cache_production
CABLE_DATABASE_URL=postgres://myapp:PASSWORD@<db-1-private-ip>:5432/myapp_cable_production
STRIPE_PUBLIC_KEY=pk_live_XXX
STRIPE_SECRET_KEY=sk_live_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX
GOOGLE_OAUTH_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-XXX
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX
BREVO_API_KEY=xkeysib-XXXXXXXX
BREVO_SMS_SENDER=MyApp
BREVO_FROM_ADDRESS=noreply@yourdomain.com
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
ANALYTICS_GA_MEASUREMENT_ID=G-XXXXXXXXXX
ANALYTICS_AHREFS_VERIFICATION=ahrefs-site-verification_XXX
```

**GitHub repository secrets** (for CI/CD auto-deploy):
```bash
gh secret set KAMAL_REGISTRY_PASSWORD
gh secret set RAILS_MASTER_KEY
gh secret set DATABASE_URL
gh secret set QUEUE_DATABASE_URL
gh secret set CACHE_DATABASE_URL
gh secret set CABLE_DATABASE_URL
gh secret set STRIPE_PUBLIC_KEY
gh secret set STRIPE_SECRET_KEY
gh secret set STRIPE_WEBHOOK_SECRET
gh secret set GOOGLE_OAUTH_CLIENT_ID
gh secret set GOOGLE_OAUTH_CLIENT_SECRET
gh secret set BREVO_SMTP_USERNAME
gh secret set BREVO_SMTP_PASSWORD
gh secret set BREVO_API_KEY
gh secret set BREVO_SMS_SENDER
gh secret set BREVO_FROM_ADDRESS
gh secret set SENTRY_DSN
```

> Only set the secrets relevant to your project. Skip Stripe / Google OAuth / Analytics vars if you don't use them.

#### 5.10 — First Deploy

- [ ] Verify `config/deploy.yml` has correct server IPs, domain, and image name ([kamal-deploy.md](kamal-deploy.md#kamal-configuration))
- [ ] Verify `Dockerfile` builds correctly: `docker build .`
- [ ] Run first deploy:
  ```bash
  kamal setup
  ```
- [ ] Verify deploy succeeded:
  ```bash
  kamal app details
  kamal traefik details
  ```
- [ ] Check logs for errors: `kamal app logs -f`

#### 5.11 — Post-Deploy Verification

- [ ] Visit `https://yourdomain.com` — site loads with HTTPS (Traefik auto-provisions Let's Encrypt)
- [ ] Visit `https://www.yourdomain.com` — redirects to non-www
- [ ] Health check passes: `https://yourdomain.com/up`
- [ ] Sign up for a new account → confirm email flow works
- [ ] *(if Stripe)* Complete a test purchase with [Stripe test card](https://docs.stripe.com/testing#cards) `4242 4242 4242 4242`
- [ ] *(if Google OAuth)* Sign in with Google → redirects back correctly
- [ ] *(if Sentry)* Trigger a test error → confirm it appears in Sentry dashboard
- [ ] *(if Analytics)* Check GA4 Real-Time report → confirm page views appear
- [ ] Run Rails console in production to spot-check: `kamal app exec -i "bin/rails console"`
- [ ] Verify database backups are running: `ssh root@<db-1> ls /opt/backups/postgresql/`

#### 5.12 — GitHub Actions CI/CD

- [ ] Verify `.github/workflows/ci.yml` exists ([kamal-deploy.md](kamal-deploy.md#automated-deployment-github-actions))
- [ ] All GitHub secrets set (step 5.9)
- [ ] Push a small commit to `main` → watch the Actions tab → confirm tests pass and deploy succeeds
- [ ] Verify the auto-deployed change is live on `https://yourdomain.com`

---

## Conventions

### Rails

- Controllers thin; business logic in interactors (`app/interactors/`)
- **Interactors, not services.** Use the [Interactor](https://github.com/collectiveidea/interactor) gem. Each interactor does one small thing. Use `Interactor::Organizer` to compose multi-step flows. See [interactors.md](interactors.md).
- **Validate params in interactors**, never on models. No `validates` in model files — ever. Validate right next to the write operation in a dedicated `Validate*` interactor step. The database enforces integrity (NOT NULL, unique indexes, CHECK constraints).
- **Standardized index params.** Every list endpoint uses the same query param names: `search`, `page`, `per_page`, `sort`, `sort_direction`, `filter[field]`. Use the `Indexable` concern. See [code-quality.md](code-quality.md#index--list-endpoints).
- **Validate on frontend first.** Before submitting to the backend, validate the form client-side. Show errors immediately without a round-trip. See [inertia-react.md](inertia-react.md#frontend-validation).
- **LLM integration:** Use `ruby_llm` gem (unified interface for OpenAI, Anthropic, Gemini, OpenRouter). Only use `ruby-openai` if explicitly requested.
- Strong params only; never `.permit!`
- **Reference data in YAML.** App-critical config (plans, roles, categories) lives in `db/reference_data/*.yml` and auto-loads on boot in all environments, including test. Survives database cleaner. Can be exported from production and committed. See [code-quality.md](code-quality.md#reference-data).
- **Seeds for one-time setup.** Use `db/seeds/` for data that runs via `bin/rails db:seed` but doesn't need to be in test. See [code-quality.md](code-quality.md#seeds).
- **Dev seed data is a first-class deliverable.** Every feature ships with a corresponding dev seed file. Run `bin/rails dev:seed` to populate realistic data for manual testing. See [code-quality.md](code-quality.md#development-seed-data).
- Jobs idempotent; use Solid Queue
- Public actions explicit: `allow_unauthenticated_access`
- **Never access ENV directly.** Use Anyway Config classes (`StripeConfig.secret_key`, not `ENV["STRIPE_SECRET_KEY"]`). Frontend config is validated via Zod schema. See [env-template.md](env-template.md#configuration-layer).
- **i18n everywhere.** No hardcoded English strings. Use `I18n.t()` in Ruby, `useTranslation()` in React. See [i18n.md](i18n.md).
- **Sentry for errors.** Configure `sentry-ruby` and `sentry-rails` gems. See [sentry.md](sentry.md).
- **Bullet gem** in development and test. Raises in test, logs in development. See [code-quality.md](code-quality.md#bullet).
- **RuboCop with extensions.** Always enabled. Use `.rubocop_todo.yml` for incremental cleanup. Inline Metrics disables are OK for big hashes/case statements. See [code-quality.md](code-quality.md#rubocop).
- **Class methods use `class << self`**, not `self.method_name`. Always keep class methods at the top of the class, before instance methods.
- **Migrations must be safe and reversible.** Use `strong_migrations` gem. Add indexes with `algorithm: :concurrently`. Always write reversible migrations — after creating one, run `bin/rails db:migrate` then `bin/rails db:rollback` to confirm it works both ways. See [code-quality.md](code-quality.md#database).
- **Pre-release: edit migrations directly.** Before first production deploy, edit existing migrations and reset (`db:drop db:create db:migrate`) to keep history clean. After production has data, never edit — only append new migrations.

### Git

- **Conventional Commits.** All commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.
- Format: `type(scope): description` — e.g. `feat(auth): add Google OAuth login`, `fix(billing): handle expired cards`, `refactor(interactors): extract validation step`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`, `build`
- Scope is optional but encouraged — use the feature area: `auth`, `billing`, `teams`, `staff`, etc.
- Breaking changes: add `!` after type — `feat(api)!: change response format`
- Keep the subject line under 72 characters. Add a body for context when the "why" isn't obvious.

### Inertia + React

- **All frontend files use kebab-case.** Pages, components, hooks, utils — every `.js`, `.jsx`, `.ts`, `.tsx` file. `dashboard.jsx`, `forgot-password.jsx`, `theme-provider.tsx`, `use-flash-toasts.js`. Never PascalCase or camelCase filenames.
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
- **One class per line in `cn()`.** When combining multiple classes, pass each as a separate string on its own line. This makes it easy to comment out individual classes for debugging:
  ```jsx
  className={cn(
    'flex',
    'items-center',
    'justify-between',
    'px-4',
    // 'bg-red-500', // debug
  )}
  ```

---

## Key Docs

| Doc | Purpose |
|-----|---------|
| [auth.md](auth.md) | Rails auth generator + OmniAuth patterns |
| [brand-interview.md](brand-interview.md) | Questions to ask about design/identity |
| [solid-stack.md](solid-stack.md) | Solid Queue/Cache/Cable with separate databases |
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
| [brevo.md](brevo.md) | Brevo transactional email + SMS setup |
| [staff-admin.md](staff-admin.md) | Staff/admin panel: table, rake task, frontend scaffold |
| [search.md](search.md) | pg_search: full-text search with tsvector + GIN indexes |

---

## Testing

See [testing-guidelines.md](testing-guidelines.md) for full principles. Quick reference:

- **Ruby:** `bundle exec rspec` — RSpec + FactoryBot + FFaker + Shoulda Matchers + VCR + WebMock
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
- [ ] Backend params validated in interactor (no `validates` on models)
- [ ] Inertia `<Link/>` for internal navigation
- [ ] Routes from `usePage().props.routes` — no hardcoded paths
- [ ] Imports use `@/` — no `../` parent imports
- [ ] shadcn/ui for controls & cards (checked [Blocks](https://www.shadcn.io/blocks/) first)
- [ ] Icons imported from `@/components/icons/` wrappers (not directly from lucide-react)
- [ ] shadcn/ui component text is i18n-ready (no hardcoded English in components)
- [ ] Mobile-first, works at 320px, tablet handled at `md` breakpoint
- [ ] Tailwind tokens (not hardcoded colors)
- [ ] No secrets in code (use ENV)
- [ ] Public endpoints have `allow_unauthenticated_access`
- [ ] Class methods use `class << self` block (not `self.method_name`)
- [ ] Bullet gem not flagging N+1 queries
- [ ] Dev seed data updated if new models/features added (`bin/rails dev:seed` still works)
- [ ] Stylelint passes on CSS files
- [ ] Prettier + ESLint pass (`bun lint:js`)
- [ ] yamllint passes on locale YAML files
- [ ] RuboCop passes (`bundle exec rubocop`)
- [ ] Commit messages follow Conventional Commits (`type(scope): description`)
