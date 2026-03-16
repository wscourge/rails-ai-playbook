# CI Workflow

> GitHub Actions CI configuration for Rails + Inertia + Vite projects.

---

## Overview

A complete CI pipeline should:
1. **Scan for security vulnerabilities** — Brakeman (Rails), bundler-audit (gems), importmap audit (JS)
2. **Lint code** — RuboCop (Ruby), ESLint + Prettier (JS), Stylelint (CSS)
3. **Run tests** — RSpec (Ruby), Jest (JS), E2E with Playwright

---

## GitHub Actions Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main, prd]

jobs:
  # ─────────────────────────────────────────────────────────
  # Security Scanning
  # ─────────────────────────────────────────────────────────
  scan_ruby:
    name: Security Scan (Ruby)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Scan for Rails security vulnerabilities
        run: bin/brakeman --no-pager

      - name: Scan for vulnerable gems
        run: bin/bundler-audit

  scan_js:
    name: Security Scan (JS)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Scan for JS vulnerabilities
        run: bin/importmap audit

  # ─────────────────────────────────────────────────────────
  # Linting
  # ─────────────────────────────────────────────────────────
  lint:
    name: Lint
    runs-on: ubuntu-latest
    env:
      RUBOCOP_CACHE_ROOT: tmp/rubocop
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Set up Bun
        uses: oven-sh/setup-bun@v1

      - name: Install JS dependencies
        run: bun install --frozen-lockfile

      - name: Cache RuboCop
        uses: actions/cache@v4
        env:
          DEPS_HASH: ${{ hashFiles('.ruby-version', '**/.rubocop.yml', '**/.rubocop_todo.yml', 'Gemfile.lock') }}
        with:
          path: ${{ env.RUBOCOP_CACHE_ROOT }}
          key: rubocop-${{ runner.os }}-${{ env.DEPS_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}
          restore-keys: |
            rubocop-${{ runner.os }}-${{ env.DEPS_HASH }}-

      - name: Lint Ruby (RuboCop)
        run: bin/rubocop -f github

      - name: Lint JS (Prettier + ESLint)
        run: bun lint:js

      - name: Lint CSS (Stylelint)
        run: bun lint:css

  # ─────────────────────────────────────────────────────────
  # Tests
  # ─────────────────────────────────────────────────────────
  test:
    name: Test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        ports:
          - 5432:5432
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        options: >-
          --health-cmd="pg_isready"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
      # Disable external services in test
      STRIPE_SECRET_KEY: sk_test_fake
      STRIPE_PUBLIC_KEY: pk_test_fake
      SENTRY_DSN: ""

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Set up Bun
        uses: oven-sh/setup-bun@v1

      - name: Install JS dependencies
        run: bun install --frozen-lockfile

      - name: Set up database
        run: |
          bin/rails db:create
          bin/rails db:schema:load

      - name: Build assets
        run: bin/rails assets:precompile

      - name: Run RSpec (unit + request specs)
        run: bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"

      - name: Run Jest
        run: bun test

  # ─────────────────────────────────────────────────────────
  # E2E Tests (Playwright)
  # ─────────────────────────────────────────────────────────
  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        ports:
          - 5432:5432
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        options: >-
          --health-cmd="pg_isready"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
      STRIPE_SECRET_KEY: sk_test_fake
      STRIPE_PUBLIC_KEY: pk_test_fake
      SENTRY_DSN: ""

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Set up Bun
        uses: oven-sh/setup-bun@v1

      - name: Install JS dependencies
        run: bun install --frozen-lockfile

      - name: Install Playwright browsers
        run: ./node_modules/.bin/playwright install chromium --with-deps

      - name: Set up database
        run: |
          bin/rails db:create
          bin/rails db:schema:load

      - name: Build assets
        run: bin/rails assets:precompile

      - name: Run E2E tests
        run: bundle exec rspec spec/system

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-screenshots
          path: tmp/screenshots/
          retention-days: 7
```

---

## Dependabot Configuration

Create `.github/dependabot.yml` to keep dependencies updated:

```yaml
version: 2
updates:
  # Ruby gems
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    groups:
      rails:
        patterns:
          - "rails*"
          - "actioncable"
          - "actionmailer"
          - "actionpack"
          - "activerecord"
          - "activestorage"
          - "activesupport"
      development:
        patterns:
          - "rspec*"
          - "rubocop*"
          - "factory_bot*"

  # GitHub Actions
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 5

  # npm/bun packages
  - package-ecosystem: npm
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    groups:
      vite:
        patterns:
          - "vite*"
          - "@vitejs/*"
      react:
        patterns:
          - "react*"
          - "@types/react*"
      tailwind:
        patterns:
          - "tailwindcss*"
          - "@tailwindcss/*"
```

---

## Required Gems

Ensure these are in your `Gemfile`:

```ruby
group :development do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end
```

Then generate the binstubs:

```bash
bundle binstub brakeman bundler-audit
```

---

## Branch Protection

After setting up CI, configure branch protection rules in GitHub:

1. Go to **Settings → Branches → Add rule**
2. Branch name pattern: `main` (or `prd`)
3. Enable:
   - **Require a pull request before merging**
   - **Require status checks to pass before merging**
   - Select: `scan_ruby`, `scan_js`, `lint`, `test`, `e2e`
   - **Require branches to be up to date before merging**

---

## Running CI Locally

Before pushing, run the same checks locally:

```bash
# Security scans
bin/brakeman --no-pager
bin/bundler-audit

# Linting
bundle exec rubocop
bun lint:js
bun lint:css

# Tests
bundle exec rspec
bun test

# E2E (headless)
bundle exec rspec spec/system
```

---

## Secrets

Add these secrets in **Settings → Secrets and variables → Actions** if needed for deployment:

| Secret | Purpose |
|--------|---------|
| `DOCKER_USERNAME` | Docker Hub registry auth |
| `DOCKER_PASSWORD` | Docker Hub registry auth |
| `KAMAL_REGISTRY_PASSWORD` | Same as DOCKER_PASSWORD (for Kamal) |
| `RAILS_MASTER_KEY` | For `credentials.yml.enc` in production deploys |

---

## Troubleshooting

### RuboCop cache issues
If RuboCop behaves differently in CI vs local, clear the cache:
```bash
rm -rf tmp/rubocop
bundle exec rubocop
```

### Playwright browser not found
Ensure browsers are installed in CI:
```bash
./node_modules/.bin/playwright install chromium --with-deps
```

### Database connection refused
Check the `services.postgres` health check is passing. The `--health-cmd` ensures the job waits for Postgres to be ready.

### Asset compilation fails
Make sure `bin/rails assets:precompile` runs before tests. Vite needs to build the JS bundle.
