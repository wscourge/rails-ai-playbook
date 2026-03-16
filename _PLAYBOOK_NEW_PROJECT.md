# Initialize a New Rails Project

> Step-by-step guide for creating a new Rails app from scratch.
> **Start here when creating a brand new project.**

For conventions when working on existing projects, see [_PLAYBOOK_EXISTING_PROJECT.md](_PLAYBOOK_EXISTING_PROJECT.md).

---

## Step 1: Interview Me

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

**Internationalization:**
- **i18n is always enabled** for both backend (Rails I18n) and frontend (react-i18next) — no hardcoded strings, even for English-only apps
- Multi-language support needed? If yes, which languages? (affects parallel locale files, language toggle UI)
- If multi-language: user-selectable or auto-detected from browser?

**Authentication & verification:**
- Login methods: password only, Google OAuth only, or both?
- Email verification required before accessing features?
- Phone number collection + SMS verification? (requires Brevo SMS setup)
- High-security email change flow? (dual-confirmation: both old and new email must confirm)

**Notifications & communication:**
- Need transactional SMS? (verification codes, alerts — requires Brevo SMS sender registration)
- User notification system? What channels? (in-app, email, sms)
- User-configurable notification preferences? (per-notification-type toggles)

**Staff/admin panel:**
- Need a staff panel? (almost always yes)
- What staff roles? (viewer, staff, admin, super_admin?)
- What can staff do? (view users, suspend, comp access, manage content, view contact requests?)
- Staff alerts via Telegram?

**User settings:**
- What settings do users manage? (profile, password, notifications, billing, preferences?)
- Simple page or multi-tab settings?

**Support & contact:**
- Public contact form with staff review?
- Support ticket system or simple contact requests?

**Compliance & data:**
- Need user activity logging / audit trail? (for compliance, debugging, or staff visibility)
- User data export feature? (GDPR "download my data")
- Account deletion? (GDPR "right to be forgotten")

**Pricing model** (if payments needed):
- What type? Subscriptions, one-time payments, metered/usage-based, or a mix?
- How many tiers/products?
- Free tier or trial period?
- Per-seat pricing or flat rate?
- Any credits/token system?
- Will staff need to grant free "comped" access to individual users? (beta testers, partners, support cases)

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

---

## Git Workflow During Setup

1. **Initialize the repo first** — run `git init` and set the default branch to `main` before creating any files
2. **Commit after each step** — when you finish a step, commit all changes before moving to the next one
3. Follow the [Conventional Commits](_PLAYBOOK_EXISTING_PROJECT.md#git) format for all commit messages (e.g. `chore: scaffold project structure`, `feat(auth): add Rails authentication`)

---

## Step 2: Create Project Structure

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
│   ├── CLAUDE.md                # Claude-specific project rules (from playbook)
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

### .claude/CLAUDE.md Content

Copy the Feature Development Workflow from [project-structure.md](project-structure.md#claudeclaudemd-template) into `.claude/CLAUDE.md`. This ensures consistent feature development process across the project.

---

## Step 3: Generate Rails App

Use my template or set up manually following these docs:
- [auth.md](auth.md) - Rails authentication + OmniAuth
- [solid-stack.md](solid-stack.md) - Database + Solid* config
- [anyway-config.md](anyway-config.md) - Backend configuration pattern (Anyway Config gem)
- [stripe-payments.md](stripe-payments.md) - Payments setup
- [inertia-react.md](inertia-react.md) - Frontend setup
- [kamal-deploy.md](kamal-deploy.md) - Deployment config
- [ci-workflow.md](ci-workflow.md) - GitHub Actions CI/CD
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

---

## Step 4: Add Common Features

After the core app is running, add these as needed:
- [interactors.md](interactors.md) - Business logic layer (interactors pattern)
- [testing-guidelines.md](testing-guidelines.md) - Testing patterns including E2E with Playwright
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

---

## Step 5: Deploy & Go Live

When the app is ready for production, follow this checklist **in order**. Each sub-step links to the detailed doc. Skip items marked *(if applicable)* when the feature isn't used.

### 5.1 — Infrastructure (Hetzner + Docker)

- [ ] Create Hetzner Cloud account → new project → add SSH key ([kamal-deploy.md](kamal-deploy.md#provision-hetzner-servers))
- [ ] Provision **web-1** server (CX22, Ubuntu LTS)
- [ ] Provision **db-1** server (CX22, Ubuntu LTS)
- [ ] Create a **Private Network** in Hetzner → attach both servers
- [ ] Configure **Firewall** rules: SSH (22), HTTP (80), HTTPS (443), Postgres (5432 private only) ([kamal-deploy.md](kamal-deploy.md#hetzner-firewall-rules))
- [ ] SSH into **db-1** → install PostgreSQL → create databases + user ([kamal-deploy.md](kamal-deploy.md#postgresql-on-db-1))
- [ ] Configure PostgreSQL to listen on private network IP (`postgresql.conf` + `pg_hba.conf`)
- [ ] Set up automated daily DB backups on db-1 ([kamal-deploy.md](kamal-deploy.md#database-backups))
- [ ] Create [Docker Hub](https://hub.docker.com/settings/security) account → generate access token

### 5.2 — Domain & DNS

- [ ] Register domain (or use existing one)
- [ ] Point **A record** for `yourdomain.com` → web-1 public IP
- [ ] Point **A record** for `www.yourdomain.com` → web-1 public IP
- [ ] (Optional) Set up Hetzner rDNS for the web-1 IP to match your domain

### 5.3 — Stripe *(if applicable)*

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

### 5.4 — Google OAuth *(if applicable)*

- [ ] Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
- [ ] Open your OAuth 2.0 client (or create one for production)
- [ ] Add **Authorized redirect URI**: `https://yourdomain.com/auth/google_oauth2/callback`
- [ ] Copy **Client ID** and **Client Secret**
- [ ] Set OAuth consent screen to **Production** (submit for verification if needed)

### 5.5 — Email & SMS (Brevo)

- [ ] Log into [Brevo](https://app.brevo.com)
- [ ] Add and **verify your sending domain** (add DNS records: DKIM, SPF, DMARC) ([brevo.md](brevo.md#email-setup))
- [ ] Copy **SMTP credentials** from Brevo dashboard
- [ ] Set `BREVO_SMTP_USERNAME`, `BREVO_SMTP_PASSWORD`, and `BREVO_FROM_ADDRESS`
- [ ] Send a test email to confirm delivery
- [ ] *(if SMS)* Register **sender name** (or phone number for US/Canada)
- [ ] *(if SMS)* Copy **API key** (v3) → set `BREVO_API_KEY` and `BREVO_SMS_SENDER`
- [ ] *(if SMS)* Send a test SMS to confirm delivery

### 5.6 — Error Tracking (Sentry)

- [ ] Log into [Sentry](https://sentry.io) → create a new **Rails project**
- [ ] Copy the **DSN** (`https://xxx@xxx.ingest.sentry.io/xxx`)
- [ ] Verify the Sentry initializer is configured ([sentry.md](sentry.md))
- [ ] (Optional) Set up Sentry alerts (e.g. Slack/email on new error)

### 5.7 — Analytics & SEO *(if applicable)*

- [ ] **Google Analytics 4:** Create property at [analytics.google.com](https://analytics.google.com) → copy Measurement ID (`G-XXXXXXXXXX`) ([analytics-seo.md](analytics-seo.md#google-analytics-4))
- [ ] **Google Search Console:** Verify domain at [search.google.com/search-console](https://search.google.com/search-console) → submit sitemap URL (`https://yourdomain.com/sitemap.xml`) ([analytics-seo.md](analytics-seo.md#google-search-console))
- [ ] **Ahrefs:** Add site → copy verification meta tag content ([analytics-seo.md](analytics-seo.md#ahrefs-verification))
- [ ] Verify `robots.txt` is in `public/` and allows crawling
- [ ] Generate sitemap: `rails sitemap:refresh`
- [ ] Verify OG image exists (`public/og-image.jpg`, 1200×630)
- [ ] Test social sharing previews ([opengraph.xyz](https://www.opengraph.xyz/) or Twitter Card Validator)

### 5.8 — Legal Pages *(if applicable)*

- [ ] Review and finalize Privacy Policy content ([legal-pages.md](legal-pages.md))
- [ ] Review and finalize Terms of Service content
- [ ] Ensure pages are accessible from footer on all public pages
- [ ] Verify correct company name, jurisdiction, and data practices

### 5.9 — Secrets & Configuration

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

### 5.10 — First Deploy

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

### 5.11 — Post-Deploy Verification

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

### 5.12 — GitHub Actions CI/CD

- [ ] Create `.github/workflows/ci.yml` and `.github/dependabot.yml` from templates ([ci-workflow.md](ci-workflow.md))
- [ ] Configure branch protection rules as documented ([ci-workflow.md](ci-workflow.md#branch-protection-recommended))
- [ ] All GitHub secrets set (step 5.9)
- [ ] Push a small commit to `main` → watch the Actions tab → confirm tests pass and deploy succeeds
- [ ] Verify the auto-deployed change is live on `https://yourdomain.com`
