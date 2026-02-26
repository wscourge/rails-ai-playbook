# Environment Variables Template

> All required ENV vars for Rails apps. Copy to `.env` and `.env.example`.

---

## .env.example

```bash
# ─────────────────────────────────────────────────────────────
# App Configuration
# ─────────────────────────────────────────────────────────────
APP_NAME="My App"
APP_HOST="localhost:3000"
APP_URL="http://localhost:3000"

# ─────────────────────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────────────────────
# Development uses database.yml defaults
# Production: set DATABASE_URL in .kamal/secrets
# DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_production

# ─────────────────────────────────────────────────────────────
# Rails
# ─────────────────────────────────────────────────────────────
RAILS_ENV=development
# RAILS_MASTER_KEY=  # Only needed in production
RAILS_MAX_THREADS=5
# RAILS_SERVE_STATIC_FILES=true  # Production only

# ─────────────────────────────────────────────────────────────
# Stripe
# ─────────────────────────────────────────────────────────────
STRIPE_PUBLIC_KEY=pk_test_XXX
STRIPE_SECRET_KEY=sk_test_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX

# Production price IDs (create via Stripe CLI)
# STRIPE_PRICE_PRO=price_XXX
# STRIPE_PRICE_MAX=price_XXX
# STRIPE_PRICE_LIFETIME=price_XXX  # One-time (if used)

# ─────────────────────────────────────────────────────────────
# Email
# ─────────────────────────────────────────────────────────────
# Development: uses letter_opener_web (no config needed)
# Production: Resend SMTP
RESEND_API_KEY=re_XXX

# ─────────────────────────────────────────────────────────────
# OAuth (Optional)
# ─────────────────────────────────────────────────────────────
GOOGLE_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-XXX

# ─────────────────────────────────────────────────────────────
# Analytics (Optional)
# ─────────────────────────────────────────────────────────────
GA_MEASUREMENT_ID=G-XXX
AHREFS_VERIFICATION=ahrefs-site-verification_xxxxxxxxxxxx

# ─────────────────────────────────────────────────────────────
# Error Tracking (Sentry)
# ─────────────────────────────────────────────────────────────
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
APP_VERSION=1.0.0

# ─────────────────────────────────────────────────────────────
# Telegram (Optional — staff notifications)
# ─────────────────────────────────────────────────────────────
# TELEGRAM_API_KEY=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11

# ─────────────────────────────────────────────────────────────
# External APIs (Add as needed)
# ─────────────────────────────────────────────────────────────
# OPENAI_API_KEY=sk-XXX
# ANTHROPIC_API_KEY=sk-ant-XXX

# ─────────────────────────────────────────────────────────────
# Mobile App (Capacitor — if shipping to stores)
# ─────────────────────────────────────────────────────────────
# iPhone & iPad (App Store)
# APP_STORE_URL=https://apps.apple.com/app/id123456789
# APP_STORE_ID=123456789
# Android (Play Store)
# ANDROID_PACKAGE=com.example.myapp
# ANDROID_APP_NAME=MyApp
# ANDROID_APP_URL=https://play.google.com/store/apps/details?id=com.example.myapp
```

---

## Usage in Rails

Always use `ENV["KEY"]` or `ENV.fetch("KEY")`:

```ruby
# Simple access (returns nil if missing)
api_key = ENV["STRIPE_SECRET_KEY"]

# With default value
app_name = ENV.fetch("APP_NAME", "My App")

# Required (raises if missing)
secret = ENV.fetch("STRIPE_SECRET_KEY")

# Boolean check
if ENV["GOOGLE_CLIENT_ID"].present?
  # Google OAuth enabled
end
```

---

## Setting Up

### Development

1. Copy template to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in development values

3. Add `dotenv-rails` gem:
   ```ruby
   # Gemfile
   gem 'dotenv-rails', groups: [:development, :test]
   ```

4. Add `.env` to `.gitignore`:
   ```
   # .gitignore
   .env
   .env.local
   ```

### Production (Kamal)

Production secrets are stored in `.kamal/secrets` (never committed):

```bash
# Edit secrets
vim .kamal/secrets

# Push env changes to servers without redeploying
kamal env push

# Clear env vars (redeploy needed)
kamal env clear
```

Clear (non-secret) env vars go in `config/deploy.yml` under `env.clear`.

### Production (GitHub Actions)

When using GitHub Actions for automated deployment, mirror all `.kamal/secrets` values as GitHub repository secrets:

```bash
# Add/update a secret
gh secret set SECRET_NAME

# List all secrets
gh secret list

# Delete a secret
gh secret delete SECRET_NAME
```

See [kamal-deploy.md](kamal-deploy.md#automated-deployment-github-actions) for the full CI/CD setup.

---

## Security Rules

1. **Never commit `.env` files** - add to `.gitignore`
2. **Always commit `.env.example`** - documents required vars
3. **Use different keys per environment** - dev/staging/prod
4. **Rotate secrets periodically** - especially after team changes
5. **Don't log ENV values** - mask in error reporters

---

## Common Patterns

### Feature Flags

```ruby
# .env
FEATURE_NEW_DASHBOARD=true

# config/initializers/features.rb
Rails.application.configure do
  config.x.features.new_dashboard = ENV["FEATURE_NEW_DASHBOARD"] == "true"
end

# Usage
if Rails.configuration.x.features.new_dashboard
  # Show new dashboard
end
```

### Per-Environment Config

```ruby
# Different behavior based on environment
case Rails.env
when "production"
  Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
when "development", "test"
  Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", "sk_test_default")
end
```

### Required vs Optional

```ruby
# Required - app won't start without it
config.x.stripe_key = ENV.fetch("STRIPE_SECRET_KEY")

# Optional - has sensible default
config.x.app_name = ENV.fetch("APP_NAME", "My App")

# Optional - feature disabled if missing
if ENV["GOOGLE_CLIENT_ID"].present?
  config.x.google_oauth_enabled = true
end
```

---

## Validation

Add to an initializer to catch missing vars early:

```ruby
# config/initializers/env_validation.rb

REQUIRED_ENV_VARS = %w[
  STRIPE_SECRET_KEY
  STRIPE_PUBLIC_KEY
]

REQUIRED_ENV_VARS_PRODUCTION = %w[
  STRIPE_WEBHOOK_SECRET
  RESEND_API_KEY
  DATABASE_URL
]

missing = REQUIRED_ENV_VARS.select { |var| ENV[var].blank? }

if Rails.env.production?
  missing += REQUIRED_ENV_VARS_PRODUCTION.select { |var| ENV[var].blank? }
end

if missing.any?
  raise "Missing required environment variables: #{missing.join(', ')}"
end
```
